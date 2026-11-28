import 'package:uuid/uuid.dart';

import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../settings/user_settings_store.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'refused_changes.dart';
import 'sync_store.dart';

const _log = Log('sync');
const _uuid = Uuid();

/// Sync of the personal settings with the account (ADR-0027): one server
/// record per user, last writer wins per key (the server merges the sent
/// keys into the stored ones).
class SettingsSync {
  SettingsSync(
    this.db,
    this.backend,
    this.store,
    this.settings, {
    RefusedChanges? undone,
  }) : undone = undone ?? RefusedChanges(store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;
  final UserSettingsStore settings;

  /// Settings the server refused for good (#1264).
  final RefusedChanges undone;

  /// Server record ID of the settings of [userId]: the same on every
  /// device, so two devices never create two records.
  static String serverId(String userId) =>
      _uuid.v5(Namespace.url.value, 'setding:user_settings:$userId');

  /// Pulls the settings of [userId]. Returns (records pulled, whether the
  /// settings on this device were replaced by the person's settings at the
  /// first sign-in here).
  ///
  /// At the first sign-in on a device the settings are a copy of the
  /// signed-out ones: if the server has the person's settings, they win;
  /// otherwise this device brings its settings along.
  Future<(int, bool)> pull(String userId) async {
    await settings.ensure(userId);
    final since = settings.get(userId)!.revision;
    final remote = await backend.pullUserSettings(since);
    if (remote != null) {
      var adopted = false;
      await settings.update(userId, (s) {
        adopted = s.adopting;
        return s.copyWith(
          data: _merge(s.data, remote.data, keep: s.dirty),
          revision: remote.revision > s.revision ? remote.revision : null,
          adopting: false,
        );
      });
      if (adopted) _log.info('Took over the settings of the account');
      return (1, adopted);
    }
    if (settings.get(userId)!.adopting) {
      await settings.update(
        userId,
        (s) => s.copyWith(adopting: false, dirty: {...s.dirty, ...s.data.keys}),
        notify: false,
      );
      await markDirty(db, SyncCollection.userSettings, userId, scope: userId);
    }
    return (0, false);
  }

  /// [local] with the values of [remote], except for the keys in [keep]
  /// (changed here and not pushed yet).
  static Map<String, Object?> _merge(
    Map<String, Object?> local,
    Map<String, dynamic> remote, {
    required Set<String> keep,
  }) => {
    ...local,
    for (final e in remote.entries)
      if (!keep.contains(e.key)) e.key: e.value,
  };

  Future<PushResult> push(OutboxEntry entry, String userId) async {
    // Another person's change on a shared device: pushed when they sync.
    if (entry.recordId != userId) return PushResult.skipped;
    final current = settings.get(userId);
    if (current == null || current.dirty.isEmpty) {
      await store.done(entry);
      return PushResult.skipped;
    }
    // Not decided yet whether the server's settings win (see [pull]).
    if (current.adopting) return PushResult.skipped;
    final create = current.revision == 0;
    final sent = create
        ? Map<String, Object?>.of(current.data)
        : {for (final k in current.dirty) k: current.data[k]};
    Future<RemoteUserSettings> send(Map<String, Object?> data, bool create) =>
        backend.pushUserSettings(
          RemoteUserSettings(id: serverId(userId), userId: userId, data: data),
          create: create,
        );
    try {
      RemoteUserSettings stored;
      try {
        stored = await send(sent, create);
      } on BackendException catch (e) {
        // Created by another device of the same person (same record ID):
        // send the changed keys only. An error that may go away is sent
        // again as it is (#1264).
        if (!create || !e.retryCreateAsUpdate) rethrow;
        sent
          ..clear()
          ..addAll({for (final k in current.dirty) k: current.data[k]});
        stored = await send(sent, false);
      }
      await settings.update(userId, (s) {
        // Changed again while pushing: stays for the next push.
        final dirty = {
          for (final k in s.dirty)
            if (!sent.containsKey(k) || sent[k] != s.data[k]) k,
        };
        return s.copyWith(
          data: _merge(s.data, stored.data, keep: dirty),
          dirty: dirty,
          revision: stored.revision > s.revision ? stored.revision : null,
        );
      });
      await store.done(entry);
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.refused) {
        // No (longer) permission, or a validation error: sending it again
        // gets the same answer (#1264). The settings are personal: this
        // device keeps them as they are (ADR-0006), but the refused keys
        // are not sent again, so that later changes still sync.
        _log.warning('Settings of $userId refused, kept on this device', e);
        await settings.update(
          userId,
          (s) => s.copyWith(
            dirty: {
              for (final k in s.dirty)
                if (!sent.containsKey(k) || sent[k] != s.data[k]) k,
            },
          ),
          notify: false,
        );
        await undone.keepLocal(entry, (
          kind: RefusedRecord.keptSettings,
          id: userId,
          name: '',
          songTitle: null,
        ));
        return PushResult.skipped;
      }
      rethrow;
    }
  }
}
