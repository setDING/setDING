import 'dart:async';
import 'dart:io';

import 'package:setding/midi/midi_output.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/app.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/platform/stage_wake_lock.dart';
import 'package:setding/ui/live/page_turner.dart' show inputDevicesProvider;
import 'package:setding/providers.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/session_store.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/deep_links.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:setding/audio/metronome.dart' show clickOutputProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fake_backup_folder.dart';
import 'fake_click_output.dart';
import 'fake_input_devices.dart';
import 'fake_midi_output.dart';

/// App with an in-memory database for widget tests.
class TestApp {
  TestApp._(
    this.db,
    this.dir,
    this.prefs,
    this.backend,
    this.userSettings, {
    this.web = false,
    SessionStore? sessionStore,
  }) : sessionStore = sessionStore ?? MemorySessionStore();

  /// Runs as the web client (ADR-0018).
  final bool web;

  /// The folder of the automatic backup (ADR-0054).
  final backupFolder = FakeBackupFolder();

  final SessionStore sessionStore;

  final AppDatabase db;
  final Directory dir;
  final SharedPreferences prefs;

  /// Personal settings per owner (ADR-0027).
  final UserSettingsStore userSettings;

  /// The personal setting values of [owner] (default: signed out).
  Map<String, Object?> personal([String owner = localOwnerId]) =>
      userSettings.data(owner);

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
    final db = AppDatabase(NativeDatabase.memory());
    final preferences = await SharedPreferences.getInstance();
    return TestApp._(
      db,
      Directory.systemTemp.createTempSync('setding_widget'),
      preferences,
      FakeSyncBackend(user: user),
      await UserSettingsStore.open(db, preferences),
      web: web,
      sessionStore: sessionStore,
    );
  }

  /// Audio output of the click (ADR-0026), without audio.
  final clickOutput = FakeClickOutput();

  /// MIDI to a keyboard (ADR-0039), in memory.
  final midiOutput = FakeMidiOutput();

  /// The keyboards of the platform (ADR-0057), in memory.
  final inputDevices = FakeInputDevices();

  /// Provider overrides of the test app (also for a [ProviderContainer]).
  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    databaseProvider.overrideWithValue(db),
    userSettingsStoreProvider.overrideWithValue(userSettings),
    attachmentStorageProvider.overrideWithValue(storage),
    sessionStoreProvider.overrideWithValue(sessionStore),
    webClientProvider.overrideWithValue(web),
    backupFolderProvider.overrideWithValue(backupFolder),
    syncBackendProvider.overrideWithValue(backend),
    incomingLinksProvider.overrideWithValue(links.stream),
    autoSyncProvider.overrideWithValue(false),
    clickOutputProvider.overrideWithValue(clickOutput),
    midiOutputProvider.overrideWithValue(midiOutput),
    inputDevicesProvider.overrideWithValue(inputDevices),
    stageWakeLockProvider.overrideWith((ref) {
      final lock = StageWakeLock(wakeLock);
      ref.onDispose(lock.dispose);
      return lock;
    }),
  ];

  Widget build({Widget? home, List<Override> extra = const []}) =>
      ProviderScope(
        overrides: [...overrides, ...extra],
        child: SetdingApp(home: home),
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

/// Opens [category] in the settings on a wide screen: the first category is
/// shown when the settings open, the account comes last (#548).
Future<void> openSettingsCategory(
  WidgetTester tester,
  SettingsCategory category,
) async {
  final tile = find.byKey(Key('settings-category-${category.name}'));
  if (tile.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// Sets a tablet-sized test surface.
void useTabletSize(WidgetTester tester, {bool landscape = true}) {
  tester.view.physicalSize = landscape
      ? const Size(1280, 800)
      : const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Opens the settings category [name] (`SettingsCategory.name`): scrolls
/// the category list (the first list on the screen) until it is fully
/// visible, as not all categories fit on smaller screens, and taps it.
Future<void> tapSettingsCategory(WidgetTester tester, String name) async {
  final category = find.byKey(Key('settings-category-$name'));
  for (final delta in [100.0, -100.0]) {
    if (category.evaluate().isNotEmpty) break;
    await tester.scrollUntilVisible(
      category,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(category);
  await tester.pumpAndSettle();
  await tester.tap(category);
  await tester.pumpAndSettle();
}

/// Switches the main navigation to [tab]; the app starts on the overview
/// (ADR-0045).
Future<void> openTab(WidgetTester tester, HomeTab tab) async {
  await tester.tap(find.byKey(Key('nav-${tab.name}')));
  await tester.pumpAndSettle();
}
