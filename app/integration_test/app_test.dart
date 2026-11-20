// The real app on Android (make android-test): start-up through main() with
// the platform's database, files, secure storage and wake lock; the demo
// song in the library and on the song screen; live mode with a PDF rendered
// by the platform's PDF engine and page turns by a page turner (keys).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const _demoTitle = 'Late Train Home';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts, shows the demo song and plays a set in live mode', (
    tester,
  ) async {
    // English UI, whatever the device's language.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', 'en');

    await app.main();
    await pumpUntil(tester, find.byType(HomeScreen));

    // The first start added the demo song to the local library.
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await pumpUntil(tester, find.text(_demoTitle));
    await tester.tap(find.text(_demoTitle).first);
    await pumpUntil(tester, find.byType(SongScreen));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));

    // A set of the demo song and a song with a two-page PDF, in the real
    // database.
    final context = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(context, listen: false);
    final setId = await tester.runAsync(() async {
      final songs = container.read(songRepositoryProvider);
      final library = await songs.watchSongs().first;
      final demo = library.firstWhere((s) => s.title == _demoTitle);
      final sheet = await songs.createSong(source: '{title: Sheet music}');
      await songs.addAttachment(sheet, name: 'sheet.pdf', bytes: pdfWith(2));
      final sets = container.read(setRepositoryProvider);
      final id = await sets.createSet(name: 'Integration');
      await sets.addSongs(id, [demo.id, sheet]);
      return id;
    });

    // openSet completes when live mode is closed: not awaited.
    unawaited(LiveScreen.openSet(context, setId!));
    await pumpUntil(tester, find.byType(LiveScreen));
    await pumpUntil(tester, find.text('1 / 2'));
    // The real wake lock keeps the screen on: no warning.
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(const Key('live-wakelock-notice')), findsNothing);

    // A page turner sends keys: to the PDF song, rendered by the platform.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await pumpUntil(tester, find.text('2 / 2'));
    await pumpUntil(tester, find.byType(PdfSpreadView));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    // And back to the demo song.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await pumpUntil(tester, find.text('1 / 2'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
