import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/data/storage_providers.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/session_store.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Counts sync runs instead of syncing.
class _CountingEngine extends SyncEngine {
  _CountingEngine(AppDatabase db, SyncBackend backend)
    : super(db, backend, BandService(db, backend));

  int runs = 0;

  /// `refreshBands` of each run.
  final refreshes = <bool>[];

  @override
  Future<SyncReport> sync({bool refreshBands = true}) async {
    runs++;
    refreshes.add(refreshBands);
    return const SyncReport();
  }
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend backend;
  late _CountingEngine engine;
  late ProviderContainer container;

  late SharedPreferences preferences;

  Future<void> start(
    SyncMode? mode, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      if (mode != null) 'syncMode': mode.name,
      ...prefs,
    });
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        userSettingsStoreProvider.overrideWithValue(
          await UserSettingsStore.open(db, preferences),
        ),
        attachmentStorageProvider.overrideWithValue(FileAttachmentStorage(dir)),
        sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        syncBackendProvider.overrideWithValue(backend),
        syncEngineProvider.overrideWithValue(engine),
      ],
    );
    container.listen(syncControllerProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> change() =>
      markDirty(db, SyncCollection.songs, 's${engine.runs}', scope: 'o1');

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_mode');
    backend = FakeSyncBackend(user: _ann);
    engine = _CountingEngine(db, backend);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  const afterLocal = Duration(milliseconds: 3300);

  test('default: syncs once at start, not after changes', () async {
    await start(null);
    expect(container.read(settingsProvider).syncMode, SyncMode.onStart);
    expect(engine.runs, 1);
    // The sync refreshes the bands; signing in does not load them again.
    expect(backend.fetchOrganizationsCalls, 0);
    await change();
    backend.changes.add('songs');
    await Future<void>.delayed(afterLocal);
    expect(engine.runs, 1);
  });

  test('manual: only "Sync now" syncs', () async {
    await start(SyncMode.manual);
    expect(engine.runs, 0);
    // Without a sync at start, the bands are refreshed after signing in.
    expect(backend.fetchOrganizationsCalls, 1);
    await change();
    await Future<void>.delayed(afterLocal);
    expect(engine.runs, 0);
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(engine.runs, 1);
  });

  test('the last sync survives a restart (#744)', () async {
    await start(
      SyncMode.manual,
      prefs: {'lastSync.ann': DateTime(2026, 1, 2, 3, 4).toIso8601String()},
    );
    expect(
      container.read(syncControllerProvider).lastSync,
      DateTime(2026, 1, 2, 3, 4),
    );
    await container.read(syncControllerProvider.notifier).syncNow();
    final stored = DateTime.parse(preferences.getString('lastSync.ann')!);
    expect(stored.isAfter(DateTime(2026, 1, 2, 3, 4)), isTrue);
    expect(container.read(syncControllerProvider).lastSync, stored);
  });

  test('automatic: changes start a sync, its own cleanup does not', () async {
    await start(SyncMode.automatic);
    expect(engine.runs, 1);

    backend.changes.add('songs');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(engine.runs, 2);

    await change();
    await Future<void>.delayed(afterLocal);
    expect(engine.runs, 3);

    // Pushed entries are removed by the sync itself.
    await db.delete(db.syncOutbox).go();
    await Future<void>.delayed(afterLocal);
    expect(engine.runs, 3);

    // Switching to manual stops the automatic syncs right away.
    await container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(syncMode: SyncMode.manual));
    await change();
    backend.changes.add('songs');
    await Future<void>.delayed(afterLocal);
    expect(engine.runs, 3);
  });

  test('automatic: only band events load the bands again', () async {
    await start(SyncMode.automatic);
    expect(engine.refreshes, [true]); // at start

    backend.changes.add('songs');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    backend.changes.add('memberships');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    await change();
    await Future<void>.delayed(afterLocal);
    expect(engine.refreshes, [true, false, true, false]);

    // Within one delay, a band event wins over a song event.
    backend.changes
      ..add('setlists')
      ..add('bands')
      ..add('overlays');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(engine.refreshes.last, isTrue);
    expect(engine.runs, 5);
  });
}
