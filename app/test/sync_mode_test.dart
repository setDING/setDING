import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/outbox.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/settings/settings.dart';
import 'package:realchord/sync/auth_providers.dart';
import 'package:realchord/sync/band_service.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/sync/sync_controller.dart';
import 'package:realchord/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Counts sync runs instead of syncing.
class _CountingEngine extends SyncEngine {
  _CountingEngine(AppDatabase db, SyncBackend backend)
    : super(db, backend, BandService(db, backend));

  int runs = 0;

  @override
  Future<SyncReport> sync() async {
    runs++;
    return const SyncReport();
  }
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend backend;
  late _CountingEngine engine;
  late ProviderContainer container;

  Future<void> start(SyncMode? mode) async {
    SharedPreferences.setMockInitialValues({
      if (mode != null) 'syncMode': mode.name,
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        attachmentStorageProvider.overrideWithValue(AttachmentStorage(dir)),
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
    dir = Directory.systemTemp.createTempSync('realchord_mode');
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
}
