import 'package:bandchords/data/database.dart';
import 'package:bandchords/data/demo_song.dart';
import 'package:bandchords/ui/live/live_screen.dart';
import 'package:bandchords/ui/songs/song_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('shows German UI with Swiss spelling when selected', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsWidgets);
    expect(find.text('Neues Set'), findsOneWidget);

    await tester.tap(find.text('Einstellungen').first);
    await tester.pumpAndSettle();
    expect(find.text('Schriftgrösse'), findsOneWidget);
    expect(find.textContaining('ß'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('switches language in settings', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Einstellungen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(app.prefs.getString('language'), 'en');
    await app.dispose(tester);
  });

  testWidgets('song library lists and opens a song', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() => app.songs.createSong(source: demoSongSource));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Late Train Home'), findsOneWidget);

    await tester.tap(find.text('Late Train Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Key G'), findsOneWidget);
    expect(find.text('VERSE 1'), findsOneWidget);
    // Chord above lyrics.
    expect(find.text('D/F#'), findsWidgets);

    // Transpose up by two semitones → key A, D/F# becomes E/G#.
    await tester.tap(find.byTooltip('One semitone up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One semitone up'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Key A'), findsOneWidget);
    expect(find.text('E/G#'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('Nashville can be switched on and off per song', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(
      () => app.songs.createSong(source: '{title: X}\n{key: G}\n[G]One [C]two'),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('Nashville numbers'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('C'), findsNothing);

    await tester.tap(find.text('Nashville numbers'));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('German notation shows H', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'de', 'notation': 'german'},
    );
    final id = await tester.runAsync(
      () => app.songs.createSong(
        source: '{title: X}\n{key: G}\n[G]Hallo [B]Welt [Bb]du',
      ),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('H'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('live mode turns to the next song with pedal keys', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await tester.runAsync(() async {
      final a = await app.songs.createSong(
        source: '{title: First}\n{key: C}\n[C]One',
      );
      final b = await app.songs.createSong(
        source: '{title: Second}\n{key: D}\n[D]Two',
      );
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [a, b]);
      await app.sets.addMarker(setId, SetItemType.pause, 'Coffee');
      return [
        for (final v in await app.sets.getItems(setId))
          v.song == null
              ? LiveItem.marker(v.item.type, v.item.note)
              : LiveItem.song(v.song!),
      ];
    });
    await tester.pumpWidget(app.build(home: LiveScreen(items: items!)));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Next: Second (D)'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('End of set'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('creates a set and adds songs', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() => app.songs.createSong(source: demoSongSource));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New set'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Summer Gig');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Summer Gig'), findsOneWidget);
    expect(find.text('This set is empty. Add some songs.'), findsOneWidget);

    await tester.tap(find.text('Add songs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Late Train Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Late Train Home'), findsOneWidget);
    expect(find.text('Offline ready'), findsOneWidget);
    await app.dispose(tester);
  });
}
