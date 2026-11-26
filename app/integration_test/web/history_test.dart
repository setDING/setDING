// The browser's history in the web client (make web-test,
// docs/development/web-tests.md, ADR-0065, #1113). One test in two page
// loads:
//
// 1. start: sign in, open a song: its URL is /songs/<id>; the browser's back
//    button goes back to the song list instead of leaving setDING (the bug
//    of #1113), forward opens the song again; then reload the tab;
// 2. reloaded: the reload served the web client at the song's path and
//    opened the song again, with a back button to the song list.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:web/web.dart' as web;

import '../support.dart';
import 'web_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String path() => web.window.location.pathname;

  testWidgets('back, forward and reload follow the screens ($step)', (
    tester,
  ) async {
    await startApp();
    switch (step) {
      case 'start':
        await signIn(tester);
        await waitForSync(tester);
        await tester.tap(find.byKey(const Key('nav-songs')));
        await pumpUntil(tester, find.text(itestSong));
        expect(path(), '/songs');
        await tester.tap(find.text(itestSong).first);
        await pumpUntil(tester, find.byType(SongScreen));
        expect(path(), startsWith('/songs/'));
        final songPath = path();

        // Back: the song list, still in setDING.
        web.window.history.back();
        await pumpUntil(tester, find.byType(SongsScreen));
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(find.byType(SongScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(path(), '/songs');

        // Forward: the song again.
        web.window.history.forward();
        await pumpUntil(tester, find.byType(SongScreen));
        expect(path(), songPath);
        then('reload', nextStep: 'reloaded');

      case 'reloaded':
        // The server served the web client at /songs/<id>; still signed in
        // (sessionStorage), the song opens again.
        await pumpUntil(
          tester,
          find.byType(SongScreen),
          timeout: const Duration(seconds: 60),
        );
        expect(path(), startsWith('/songs/'));
        await tester.tap(find.byType(BackButton));
        await pumpUntil(tester, find.byType(SongsScreen));
        expect(path(), '/songs');
        expect(tester.takeException(), isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
