import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/outbox.dart';
import 'settings.dart';

/// The personal settings of one owner (layer 4a, ADR-0027).
@immutable
class PersonalSettings {
  const PersonalSettings({
    this.data = const {},
    this.dirty = const {},
    this.revision = 0,
    this.adopting = false,
  });

  /// Setting values by key; may contain keys this app version does not know.
  final Map<String, Object?> data;

  /// Keys changed here and not yet on the server.
  final Set<String> dirty;

  /// Server revision; 0 = not on the server.
  final int revision;

  /// Copied from the signed-out settings at the first sign-in on this
  /// device; the person's settings on the server replace it.
  final bool adopting;

  PersonalSettings copyWith({
    Map<String, Object?>? data,
    Set<String>? dirty,
    int? revision,
    bool? adopting,
  }) => PersonalSettings(
    data: data ?? this.data,
    dirty: dirty ?? this.dirty,
    revision: revision ?? this.revision,
    adopting: adopting ?? this.adopting,
  );

  static PersonalSettings fromRow(UserSettingsRow row) => PersonalSettings(
    data: switch (jsonDecode(row.data)) {
      final Map<String, Object?> m => m,
      _ => const {},
    },
    dirty: switch (jsonDecode(row.dirtyKeys)) {
      final List<Object?> l => l.whereType<String>().toSet(),
      _ => const {},
    },
    revision: row.revision,
    adopting: row.adopting,
  );

  UserSettingsCompanion toCompanion(String owner) =>
      UserSettingsCompanion.insert(
        ownerId: owner,
        data: Value(jsonEncode(data)),
        dirtyKeys: Value(jsonEncode(dirty.toList()..sort())),
        revision: Value(revision),
        adopting: Value(adopting),
      );
}

/// Personal settings per owner (ADR-0027): the signed-in user's ID, or
/// [localOwnerId] while signed out. Kept in memory, so that the settings
/// are available synchronously (language and theme at start), and written
/// through to the `user_settings` table (drift runs the statements in the
/// order they are issued).
class UserSettingsStore {
  UserSettingsStore._(this.db, this._owners);

  final AppDatabase db;
  final Map<String, PersonalSettings> _owners;
  final _changes = StreamController<String>.broadcast();

  /// Writes not finished yet. No chain of futures: a future kept across
  /// calls would tie later writes to the zone of the first one.
  final _pending = <Future<void>>{};

  /// Loads the stored settings. The first start after the upgrade to
  /// schema 15 moves the personal settings from the device settings in
  /// [prefs] to [localOwnerId].
  static Future<UserSettingsStore> open(
    AppDatabase db,
    SharedPreferences prefs,
  ) async {
    final store = UserSettingsStore._(db, {});
    await store._load();
    if (!store._owners.containsKey(localOwnerId)) {
      final keys = AppSettings.keysOf(SettingSyncScope.personal).toList();
      final legacy = AppSettings.readPrefs(prefs, keys);
      await store._put(localOwnerId, PersonalSettings(data: legacy));
      for (final key in keys) {
        await prefs.remove(key);
      }
    }
    return store;
  }

  Future<void> _load() async {
    _owners
      ..clear()
      ..addAll({
        for (final row in await db.select(db.userSettings).get())
          row.ownerId: PersonalSettings.fromRow(row),
      });
  }

  /// Owners whose settings changed from outside the settings screen (sync,
  /// [reload]).
  Stream<String> get changes => _changes.stream;

  /// The stored settings of [owner], or null.
  PersonalSettings? get(String owner) => _owners[owner];

  /// The setting values of [owner]; a signed-in person without own settings
  /// on this device yet sees the signed-out ones (they are taken over).
  Map<String, Object?> data(String owner) =>
      (_owners[owner] ?? _owners[localOwnerId])?.data ?? const {};

  /// Creates the settings of [owner] at their first sign-in on this device:
  /// a copy of the signed-out settings, marked as [PersonalSettings.adopting]
  /// until the sync has asked the server (ADR-0027).
  Future<void> ensure(String owner) async {
    if (_owners.containsKey(owner)) return;
    await _put(
      owner,
      owner == localOwnerId
          ? const PersonalSettings()
          : PersonalSettings(data: data(localOwnerId), adopting: true),
    );
  }

  /// Changes settings of [owner] in the settings screen; for a signed-in
  /// person the changed keys are synced (outbox).
  Future<void> change(String owner, Map<String, Object> values) async {
    await ensure(owner);
    final synced = owner != localOwnerId;
    final next = update(
      owner,
      (s) => s.copyWith(
        data: {...s.data, ...values},
        dirty: synced ? {...s.dirty, ...values.keys} : null,
      ),
      notify: false,
    );
    await next;
    if (synced) {
      await markDirty(db, SyncCollection.userSettings, owner, scope: owner);
    }
  }

  /// Applies [change] to the settings of [owner] right away (in memory) and
  /// stores the result. [notify] tells listeners
  /// of [changes].
  Future<void> update(
    String owner,
    PersonalSettings Function(PersonalSettings current) change, {
    bool notify = true,
  }) {
    final next = change(_owners[owner] ?? const PersonalSettings());
    final written = _put(owner, next);
    if (notify) _changes.add(owner);
    return written;
  }

  Future<void> _put(String owner, PersonalSettings settings) {
    _owners[owner] = settings;
    final write = db
        .into(db.userSettings)
        .insertOnConflictUpdate(settings.toCompanion(owner));
    _pending.add(write);
    return write.whenComplete(() => _pending.remove(write));
  }

  /// Loads the settings again, e.g. after the web client deleted its data
  /// on sign-out (ADR-0018).
  Future<void> reload() async {
    await flush();
    final before = _owners.keys.toSet();
    await _load();
    before.addAll(_owners.keys);
    before.forEach(_changes.add);
  }

  /// Waits until all changes are stored (tests).
  Future<void> flush() => Future.wait(_pending.toList());

  Future<void> dispose() => _changes.close();
}

/// The personal settings; overridden in main() with the loaded store.
final userSettingsStoreProvider = Provider<UserSettingsStore>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);
