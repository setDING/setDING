// The web client in a real browser (make web-test, docs/development/web-tests.md):
// tool/web-test.sh builds this test as the web client, serves it from a
// local PocketBase like in production (same origin, isolation headers,
// ADR-0018) and runs it in a headless browser. The account comes with
// --dart-define.
//
// Sign-in gate, sign-in through the real UI, drift's WASM database in the
// browser's OPFS, the first sync, the session in sessionStorage, live mode
// with a PDF fetched from the server when it is opened, and signing out,
// which deletes the local data.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/bootstrap/platform_services_web.dart';
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/songs/song_screen.dart';

import '../support.dart';
import 'web_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in, syncs, plays a set with a PDF and signs out', (
    tester,
  ) async {
    await startApp();

    // Without a session the web client shows only the sign-in gate; its
    // server is the page's own origin.
    await signIn(tester);

    // drift runs SQLite in the browser's private file system: the server
    // sends the isolation headers (ADR-0018).
    expect(isOpfs(webDatabaseStorage), isTrue, reason: '$webDatabaseStorage');
    await waitForSync(tester);

    // The session lasts as long as the tab: sessionStorage only, without
    // "Stay signed in".
    expect(tabSession, contains(Uri.base.origin));
    expect(keptSession, isNull);

    // The synced song in the library and on the song screen.
    await tester.tap(find.byKey(const Key('nav-songs')));
    await pumpUntil(tester, find.text(itestSong));
    await tester.tap(find.text(itestSong).first);
    await pumpUntil(tester, find.byType(SongScreen));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));

    // A set of both songs in live mode; the PDF is fetched from the
    // server when it is shown (not preloaded on the web).
    final container = containerOf(tester);
    final songId = (await localSong(tester, itestSong))!.id;
    final sheetId = (await localSong(tester, itestSheet))!.id;
    final setId = await tester.runAsync(() async {
      final sets = container.read(setRepositoryProvider);
      final id = await sets.createSet(name: 'Web integration');
      await sets.addSongs(id, [songId, sheetId]);
      return id;
    });
    // openSet completes when live mode is closed: not awaited.
    unawaited(
      LiveScreen.openSet(tester.element(find.byType(HomeScreen)), setId!),
    );
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
    final db = container.read(databaseProvider);
    await signOut(tester);
    expect(tabSession, isNull);
    await waitForLocalDataDeleted(tester, db);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
