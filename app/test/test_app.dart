import 'dart:async';
import 'dart:io';

import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/attachment_storage_io.dart';
import 'package:realchord/data/attachment_storage_memory.dart';
import 'package:realchord/app.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/platform/stage_wake_lock.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/settings/settings.dart';
import 'package:realchord/sync/auth_providers.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/sync/sync_controller.dart';
import 'package:realchord/ui/deep_links.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

/// App with an in-memory database for widget tests.
class TestApp {
  TestApp._(
    this.db,
    this.dir,
    this.prefs,
    this.backend, {
    this.web = false,
    SessionStore? sessionStore,
  }) : sessionStore = sessionStore ?? MemorySessionStore();

  /// Runs as the web client (ADR-0018).
  final bool web;

  final SessionStore sessionStore;

  final AppDatabase db;
  final Directory dir;
  final SharedPreferences prefs;

  /// Backend used instead of a real server.
  final FakeSyncBackend backend;

  /// Links "opened" from outside the app (deep links).
  final links = StreamController<Uri>.broadcast();

  /// Attachment files: in memory for the web client, as in the browser.
  late final AttachmentStorage storage = web
      ? MemoryAttachmentStorage()
      : FileAttachmentStorage(dir);
  late final songs = SongRepository(db, storage);

  /// The screen's "keep on" switch, instead of the platform's.
  final wakeLock = FakeWakeLockPlatform();
  late final sets = SetRepository(db, storage);

  /// Songs of another library, e.g. an organization (ADR-0017).
  /// Songs of [libraryId] as [userId] writes them (creator and last editor
  /// of organization songs, ADR-0023).
  static SongRepository songsIn(
    TestApp app,
    String libraryId, {
    String? userId,
  }) =>
      SongRepository(app.db, app.storage, libraryId: libraryId, userId: userId);

  static Future<TestApp> create({
    Map<String, Object> prefs = const {},
    AuthUser? user,
    bool web = false,
    SessionStore? sessionStore,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues(prefs);
    return TestApp._(
      AppDatabase(NativeDatabase.memory()),
      Directory.systemTemp.createTempSync('realchord_widget'),
      await SharedPreferences.getInstance(),
      FakeSyncBackend(user: user),
      web: web,
      sessionStore: sessionStore,
    );
  }

  /// Provider overrides of the test app (also for a [ProviderContainer]).
  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    databaseProvider.overrideWithValue(db),
    attachmentStorageProvider.overrideWithValue(storage),
    sessionStoreProvider.overrideWithValue(sessionStore),
    webClientProvider.overrideWithValue(web),
    syncBackendProvider.overrideWithValue(backend),
    incomingLinksProvider.overrideWithValue(links.stream),
    autoSyncProvider.overrideWithValue(false),
    stageWakeLockProvider.overrideWith((ref) {
      final lock = StageWakeLock(wakeLock);
      ref.onDispose(lock.dispose);
      return lock;
    }),
  ];

  Widget build({Widget? home}) => ProviderScope(
    overrides: overrides,
    child: RealChordApp(home: home),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Drift cancels stream queries with a zero-duration timer.
    await tester.pump(Duration.zero);
    final closing = db.close();
    await tester.pump(Duration.zero);
    await closing;
    await links.close();
    dir.deleteSync(recursive: true);
  }
}

/// Keeps the screen on in memory; [fail] makes it fail like a platform
/// without a wake lock.
class FakeWakeLockPlatform implements WakeLockPlatform {
  /// Whether the screen is kept on.
  bool on = false;

  /// Turning it on throws.
  bool fail = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled && fail) throw UnsupportedError('No wake lock');
    on = enabled;
  }

  @override
  Future<bool> get enabled async => on;
}

/// Sets a tablet-sized test surface.
void useTabletSize(WidgetTester tester, {bool landscape = true}) {
  tester.view.physicalSize = landscape
      ? const Size(1280, 800)
      : const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
