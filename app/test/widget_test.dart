import 'package:bandchords/data/database.dart';
import 'package:bandchords/data/demo_song.dart';
import 'package:bandchords/ui/live/live_screen.dart';
import 'package:bandchords/ui/render/song_view.dart';
import 'package:bandchords/ui/sets/set_screen.dart';
import 'package:bandchords/ui/widgets/key_picker.dart';
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
    await tester.scrollUntilVisible(
      find.text('Schriftgrösse'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
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

    // Choose key A in the dropdown → D/F# becomes E/G#.
    await tester.tap(find.byType(KeyPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Key A'), findsOneWidget);
    expect(find.text('E/G#'), findsWidgets);
    final id = (await tester.runAsync(() => app.songs.watchSongs().first))!
        .single
        .id;
    final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
    expect(overlay!.transpose, 2);
    await app.dispose(tester);
  });

  testWidgets('tag filter stays after deleting the last song with the tag', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final tagged = await tester.runAsync(
      () => app.songs.createSong(source: '{title: Tagged}\n{tag: Gig}'),
    );
    await tester.runAsync(() => app.songs.createSong(source: '{title: Plain}'));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gig'));
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsNothing);

    await tester.runAsync(() => app.songs.deleteSong(tagged!));
    await tester.pumpAndSettle();
    expect(find.text('Tagged'), findsNothing);
    // The filter bar is still there and "All" shows the other songs again.
    expect(find.widgetWithText(ChoiceChip, 'Gig'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsOneWidget);
    // Without a selection the unused tag disappears.
    expect(find.byType(ChoiceChip), findsNothing);
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

  testWidgets('conditional directives follow the instrument setting', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'ukulele', 'userName': 'alto'},
    );
    final id = await tester.runAsync(
      () => app.songs.createSong(
        source:
            '{title: Cond}\n{c-guitar: For guitar}\n{c-ukulele: For ukulele}\n'
            '{c-alto: For alto}\n[C]x',
      ),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('For ukulele'), findsOneWidget);
    expect(find.text('For alto'), findsOneWidget);
    expect(find.text('For guitar'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('instrument can be chosen in the settings', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ukulele'));
    await tester.pumpAndSettle();
    expect(app.prefs.getString('instrument'), 'ukulele');
    await app.dispose(tester);
  });

  testWidgets('song capo can be overridden with no capo', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(
      () => app.songs.createSong(
        source: '{title: Capo}\n{key: C}\n{capo: 2}\n[C]x [G]y',
      ),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('Capo 2 (as in song)'), findsOneWidget);
    expect(find.text('G'), findsOneWidget); // shapes as written

    await tester.tap(find.text('Capo 2 (as in song)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No capo').last);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget); // sounding chords without capo
    expect(find.text('D'), findsOneWidget);
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

  for (final landscape in [true, false]) {
    testWidgets(
      'live mode fits a long song without scrolling (landscape: $landscape)',
      (tester) async {
        useTabletSize(tester, landscape: landscape);
        final app = await TestApp.create(prefs: {'language': 'en'});
        final song = await tester.runAsync(() async {
          final id = await app.songs.createSong(source: demoSongSource);
          return app.songs.getSong(id);
        });
        await tester.pumpWidget(
          app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsNothing);
        final page = tester.getRect(find.byType(PageView));
        final lastLine = tester.getRect(find.text('long.').last);
        expect(lastLine.bottom, lessThanOrEqualTo(page.bottom));
        expect(lastLine.right, lessThanOrEqualTo(page.right));
        // The measured layout is accurate: the safety FittedBox does not
        // need to shrink the content.
        final body = tester.getSize(find.byType(SongBody));
        final box = tester.getSize(find.byType(FittedBox));
        expect(body.height, lessThanOrEqualTo(box.height));
        await app.dispose(tester);
      },
    );
  }

  testWidgets('live mode scrolls when fitting is switched off', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(source: demoSongSource);
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('repeated chorus can be shown as a label only', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'chorusRepeat': 'label'},
    );
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(source: demoSongSource);
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.repeat), findsNWidgets(2));
    await app.dispose(tester);
  });

  testWidgets('chooses the key of a song in the set list', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source: '{title: In F}\n{key: F}\n[F]x',
      );
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [id]);
      return setId;
    });
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId!)));
    await tester.pumpAndSettle();

    // Dropdown shows the original key; choose D (three semitones down).
    expect(find.text('F'), findsOneWidget);
    await tester.tap(find.byType(KeyPicker));
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsOneWidget);
    await tester.tap(find.text('D').last);
    await tester.pumpAndSettle();

    final item = (await tester.runAsync(() => app.sets.getItems(setId)))!
        .single;
    expect(item.item.transpose, -3);
    expect(find.text('D'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('key chosen in live mode is stored on the set item', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    const source = '{title: Live Key}\n{key: G}\n[G]Hello [C]there';
    final data = await tester.runAsync(() async {
      final songId = await app.songs.createSong(source: source);
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [songId]);
      final views = await app.sets.getItems(setId);
      return (
        songId,
        setId,
        [
          for (final v in views)
            LiveItem.song(
              v.song!,
              setTranspose: v.item.transpose,
              setItemId: v.item.id,
            ),
        ],
      );
    });
    final (songId, setId, items) = data!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    // Open the control bar (tap in the middle) and choose key A.
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(page.center);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(KeyPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();

    expect(find.text('D'), findsWidgets); // C → D
    final stored = await tester.runAsync(
      () async => (
        (await app.sets.getItems(setId)).single.item.transpose,
        (await app.songs.getSong(songId))!.chordproSource,
        (await app.songs.getOverlay(songId)).transpose,
      ),
    );
    expect(stored!.$1, 2);
    expect(stored.$2, source); // the song itself is unchanged
    expect(stored.$3, 0); // no personal transposition
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
