// The web client in a real browser (make web-test, docs/development/web-tests.md):
// tool/web-test.sh builds this test as the web client, serves it from a
// local PocketBase like in production (same origin, isolation headers,
// ADR-0018) and runs it in headless Chrome. The account comes with
// --dart-define.
//
// Sign-in gate, sign-in through the real UI, drift's WASM database in the
// browser's OPFS, the first sync, the session in sessionStorage, live mode
// with a PDF fetched from the server when it is opened, and signing out,
// which deletes the local data.
import 'dart:async';

import 'package:drift/wasm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/bootstrap/platform_services_web.dart';
import 'package:setding/data/database.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/platform/browser_storage_web.dart';
import 'package:setding/providers.dart';
import 'package:setding/sync/browser_session_store.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../support.dart';

const _email = String.fromEnvironment('SETDING_ITEST_EMAIL');
const _password = String.fromEnvironment('SETDING_ITEST_PASSWORD');
const _song = String.fromEnvironment('SETDING_ITEST_SONG');
const _sheet = String.fromEnvironment('SETDING_ITEST_SHEET');

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in, syncs, plays a set with a PDF and signs out', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', 'en');

    await app.main();

    // Without a session the web client shows only the sign-in gate; its
    // server is the page's own origin.
    await pumpUntil(tester, find.byKey(const Key('web-sign-in')));
    expect(_email, isNotEmpty, reason: 'the account comes from make web-test');
    await fillIn(tester, find.byKey(const Key('account-email')), _email);
    await fillIn(tester, find.byKey(const Key('account-password')), _password);
    await tester.tap(find.byKey(const Key('account-submit')));
    // The band arrives with the first sync.
    await pumpUntil(
      tester,
      find.byType(HomeScreen),
      timeout: const Duration(seconds: 60),
    );
    expect(find.byKey(const Key('account-error')), findsNothing);

    // drift runs SQLite in the browser's private file system: the server
    // sends the isolation headers (ADR-0018).
    expect(webDatabaseStorage, WasmStorageImplementation.opfsLocks);

    final context = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(context, listen: false);
    final db = container.read(databaseProvider);
    Future<SongEntry?> song(String title) => tester
        .runAsync(
          () => (db.select(
            db.songs,
          )..where((s) => s.title.equals(title))).getSingleOrNull(),
        )
        .then((r) => r);
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (await song(_song) == null || await song(_sheet) == null) {
      if (DateTime.now().isAfter(end)) {
        fail('$_song and $_sheet were not synced within 60 s');
      }
      await pumpFor(tester, const Duration(milliseconds: 500));
    }

    // The session lasts as long as the tab: sessionStorage only, without
    // "Stay signed in".
    final session = BrowserKeyValueStorage.session().read(
      BrowserSessionStore.key,
    );
    expect(session, contains(Uri.base.origin));
    expect(
      BrowserKeyValueStorage.local().read(BrowserSessionStore.key),
      isNull,
    );

    // The synced song in the library and on the song screen.
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await pumpUntil(tester, find.text(_song));
    await tester.tap(find.text(_song).first);
    await pumpUntil(tester, find.byType(SongScreen));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));

    // A set of both songs in live mode; the PDF is fetched from the
    // server when it is shown (not preloaded on the web).
    final songId = (await song(_song))!.id;
    final sheetId = (await song(_sheet))!.id;
    final setId = await tester.runAsync(() async {
      final sets = container.read(setRepositoryProvider);
      final id = await sets.createSet(name: 'Web integration');
      await sets.addSongs(id, [songId, sheetId]);
      return id;
    });
    // openSet completes when live mode is closed: not awaited.
    unawaited(LiveScreen.openSet(context, setId!));
    await pumpUntil(tester, find.byType(LiveScreen));
    await pumpUntil(tester, find.text('1 / 2'));
    expect(find.byKey(const Key('live-web-notice')), findsOneWidget);
    await pressKey(tester, 'PageDown');
    await pumpUntil(tester, find.text('2 / 2'));
    await pumpUntil(
      tester,
      find.byType(PdfSpreadView),
      timeout: const Duration(seconds: 60),
    );
    await pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(LiveScreen))).pop();
    await pumpUntil(tester, find.byType(HomeScreen));

    // Signing out through the real UI deletes the local data and the
    // session, and shows the sign-in gate again.
    Navigator.of(context)
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
    expect(
      BrowserKeyValueStorage.session().read(BrowserSessionStore.key),
      isNull,
    );
    final left = await tester.runAsync(() => db.select(db.songs).get());
    expect(left, isEmpty);
    Navigator.of(tester.element(find.byType(SettingsScreen)))
        .popUntil((route) => route.isFirst);
    await pumpUntil(tester, find.byKey(const Key('web-sign-in')));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
