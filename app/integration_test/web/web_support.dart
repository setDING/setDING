// Helpers of the web integration tests (make web-test,
// docs/development/web-tests.md).
//
// A test can span several page loads and tabs: every load of the page
// starts the test again, so a test reads its current [step] and tells the
// driver (test_driver/web_driver.dart) what to do after it with [then].
import 'package:drift/wasm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/storage_providers.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/platform/browser_storage_web.dart';
import 'package:setding/sync/browser_session_store.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../support.dart';

const itestEmail = String.fromEnvironment('SETDING_ITEST_EMAIL');
const itestPassword = String.fromEnvironment('SETDING_ITEST_PASSWORD');
const itestSong = String.fromEnvironment('SETDING_ITEST_SONG');
const itestSheet = String.fromEnvironment('SETDING_ITEST_SHEET');

/// Key in `sessionStorage` for the step of the next load of this tab.
const _stepKey = 'itest.step';

/// The step of this page load: set by the previous load of this tab
/// ([then] with `nextStep`), else the URL's `step` parameter, else `start`.
/// Read once per load.
final String step = () {
  final storage = web.window.sessionStorage;
  final stored = storage.getItem(_stepKey);
  storage.removeItem(_stepKey);
  return stored ?? Uri.base.queryParameters['step'] ?? 'start';
}();

/// Tells the driver what to do once this load's test has passed:
/// - `reload`: reload this tab;
/// - `open`: open a new tab with [tabStep] (the URL's `step`), this tab
///   stays open in the background;
/// - `replace`: like `open`, but close this tab first;
/// - `back`: close this tab and wait for the previous tab to load again
///   (it reloads by itself).
///
/// [nextStep] is the step of this tab's next load (after `reload`, or when
/// it reloads by itself).
void then(String action, {String? tabStep, String? nextStep}) {
  if (nextStep != null) {
    web.window.sessionStorage.setItem(_stepKey, nextStep);
  }
  IntegrationTestWidgetsFlutterBinding.instance.reportData = {
    'next': action,
    'step': ?tabStep,
  };
}

/// Whether drift keeps the database in the browser's private file system
/// (OPFS). Chrome needs the server's isolation headers for it (opfsLocks,
/// ADR-0018); Firefox uses OPFS through a shared worker (opfsShared) with or
/// without them.
bool isOpfs(WasmStorageImplementation? storage) =>
    storage == WasmStorageImplementation.opfsLocks ||
    storage == WasmStorageImplementation.opfsShared;

/// Whether drift uses a persistent storage that needs no cross-origin
/// isolation: IndexedDB (Chrome) or OPFS through a shared worker (Firefox).
bool isFallback(WasmStorageImplementation? storage) =>
    storage == WasmStorageImplementation.opfsShared ||
    storage == WasmStorageImplementation.sharedIndexedDb ||
    storage == WasmStorageImplementation.unsafeIndexedDb;

/// The session of this tab (`sessionStorage`).
String? get tabSession =>
    BrowserKeyValueStorage.session().read(BrowserSessionStore.key);

/// The session kept with "Stay signed in" (`localStorage`).
String? get keptSession =>
    BrowserKeyValueStorage.local().read(BrowserSessionStore.key);

/// Starts the app in English.
Future<void> startApp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', 'en');
  await app.main();
}

/// Signs in on the sign-in gate through the real UI and waits for the home
/// screen (the band arrives with the first sync). The account is the one of
/// web-test unless [email] and [password] are given (make e2e).
Future<void> signIn(
  WidgetTester tester, {
  bool keepSignedIn = false,
  String email = itestEmail,
  String password = itestPassword,
}) async {
  await pumpUntil(tester, find.byKey(const Key('web-sign-in')));
  expect(email, isNotEmpty, reason: 'the account comes from the runner');
  await fillIn(tester, find.byKey(const Key('account-email')), email);
  await fillIn(tester, find.byKey(const Key('account-password')), password);
  if (keepSignedIn) {
    await tester.tap(find.byKey(const Key('account-keep-signed-in')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('account-submit')));
  await pumpUntil(
    tester,
    find.byType(HomeScreen),
    timeout: const Duration(seconds: 60),
  );
  expect(find.byKey(const Key('account-error')), findsNothing);
}

/// The app's provider container (on any screen).
ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
  listen: false,
);

/// The song titled [title] in the local database, if any.
Future<SongEntry?> localSong(WidgetTester tester, String title) async {
  final db = containerOf(tester).read(databaseProvider);
  return tester.runAsync<SongEntry?>(
    () => (db.select(
      db.songs,
    )..where((s) => s.title.equals(title))).getSingleOrNull(),
  );
}

/// All songs in the local database.
Future<List<SongEntry>> localSongs(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.songs).get()))!;

/// Waits until signing out (here or in another tab) has deleted the local
/// data (ADR-0018). The database goes first; the settings, attachments and
/// selections follow, so the test keeps pumping a moment: otherwise the end
/// of the test tears the app down while it is still clearing.
Future<void> waitForLocalDataDeleted(
  WidgetTester tester,
  AppDatabase db,
) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while ((await localSongs(tester, db)).isNotEmpty) {
    if (DateTime.now().isAfter(end)) fail('the local data was not deleted');
    await pumpFor(tester, const Duration(milliseconds: 200));
  }
  await pumpFor(tester, const Duration(seconds: 2));
}

/// Waits until the songs of the test backend are in the local database.
Future<void> waitForSync(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (await localSong(tester, itestSong) == null ||
      await localSong(tester, itestSheet) == null) {
    if (DateTime.now().isAfter(end)) {
      fail('$itestSong and $itestSheet were not synced within 60 s');
    }
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}

/// Signs out through Settings → Account, confirms, and goes back to the
/// sign-in gate.
Future<void> signOut(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(HomeScreen)))
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  await pumpUntil(tester, find.byType(SettingsScreen));
  final account = find.byKey(
    Key('settings-category-${SettingsCategory.account.name}'),
  );
  await tester.scrollUntilVisible(
    account,
    200,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(account);
  await pumpUntil(tester, find.byKey(const Key('account-sign-out')));
  await tester.tap(find.byKey(const Key('account-sign-out')));
  await pumpUntil(tester, find.byType(AlertDialog));
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    ),
  );
  await pumpUntil(tester, find.byKey(const Key('account-open-sign-in')));
  Navigator.of(tester.element(find.byType(SettingsScreen)))
      .popUntil((route) => route.isFirst);
  await pumpUntil(tester, find.byKey(const Key('web-sign-in')));
}

/// Presses [key] (a `KeyboardEvent.key`, e.g. `PageDown`) like a keyboard
/// or a Bluetooth page turner in the browser: the events go through the
/// engine's keyboard handling. flutter_test's key simulation does not work
/// in a web build.
Future<void> pressKey(WidgetTester tester, String key) async {
  final target =
      web.document.activeElement ?? web.document.querySelector('flutter-view')!;
  for (final type in ['keydown', 'keyup']) {
    target.dispatchEvent(
      web.KeyboardEvent(
        type,
        web.KeyboardEventInit(
          key: key,
          code: key,
          bubbles: true,
          cancelable: true,
        ),
      ),
    );
  }
  await tester.pump();
}
