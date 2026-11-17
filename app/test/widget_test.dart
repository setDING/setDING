import 'package:realchord/data/database.dart';
import 'package:realchord/data/demo_song.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/render/song_view.dart';
import 'package:realchord/ui/sets/set_screen.dart';
import 'package:realchord/ui/widgets/key_picker.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';
import 'package:realchord/ui/songs/song_screen.dart';
import 'package:material_ui/material_ui.dart';
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
    await tester.tap(find.byKey(const Key('settings-category-display')));
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
    await tester.tap(find.byKey(const Key('settings-category-general')));
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
    expect(find.textContaining('Key: G'), findsOneWidget);
    expect(find.text('VERSE 1'), findsOneWidget);
    // Chord above lyrics.
    expect(find.text('D/F#'), findsWidgets);

    // The adjustments are in a side panel, marked as personal, not as
    // changes to the song.
    expect(find.byKey(const Key('personal-adjustments')), findsNothing);
    await tester.tap(find.byTooltip('Personal adjustments'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-adjustments')), findsOneWidget);
    expect(find.text('Personal adjustments'), findsOneWidget);
    expect(find.text('My notes'), findsOneWidget);
    expect(find.byTooltip('My key – just for me'), findsOneWidget);
    // The scope is behind a (?) icon; tapping it shows for whom it applies.
    final scope = find.byKey(const ValueKey('scope-info-personal'));
    expect(scope, findsOneWidget);
    expect(
      find.text('Just for you – the song stays unchanged for everyone else.'),
      findsNothing,
    );
    await tester.tap(scope);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Just for you – the song stays unchanged for everyone else.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Choose key A in the dropdown → D/F# becomes E/G#.
    await tester.tap(find.byType(KeyPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Key: A'), findsOneWidget);
    expect(find.text('E/G#'), findsWidgets);
    // A plain query: a new stream query does not run inside runAsync.
    final id = (await tester.runAsync(() => app.db.select(app.db.songs).get()))!
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

    await tester.tap(find.byTooltip('Personal adjustments'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const Key('settings-category-musician')));
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
    await tester.tap(find.byTooltip('Personal adjustments'));
    await tester.pumpAndSettle();
    expect(find.text('Capo: 2 (D), as in song'), findsOneWidget);
    expect(find.text('G'), findsOneWidget); // shapes as written
    // Key of the shapes, the sounding key next to the capo.
    expect(find.text('Key: C, Capo: 2 (D)'), findsOneWidget);

    await tester.tap(find.text('Capo: 2 (D), as in song'));
    await tester.pumpAndSettle();
    // Each entry shows the header it leads to; the sounding key stays.
    expect(
      find.text('Capo 2 (as in song) – Key: C, Capo: 2 (D)'),
      findsOneWidget,
    );
    expect(find.text('Key: D, Capo: 5 (A)'), findsOneWidget);
    await tester.tap(find.text('No capo – Key: D'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget); // sounding chords without capo
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Key: D'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a personal capo keeps the sounding key as the key', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(
      () => app.songs.createSong(source: '{title: Capo}\n{key: A}\n[A]x [D]y'),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('Key: A'), findsOneWidget);

    await tester.tap(find.byTooltip('Personal adjustments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No capo'));
    await tester.pumpAndSettle();
    expect(find.text('No capo – Key: A'), findsOneWidget);
    await tester.tap(find.text('Key: A, Capo: 2 (G)'));
    await tester.pumpAndSettle();
    // The header keeps A; the chords are the shapes for capo 2.
    expect(find.text('Key: A, Capo: 2 (G)'), findsOneWidget);
    // The capo button shows the capo as the header does.
    expect(find.text('Capo: 2 (G)'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
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

  testWidgets('live mode turns to the next song with taps', (tester) async {
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

    // Keys no longer turn pages (pedal support removed, #149).
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    final size = tester.getSize(find.byType(PageView));
    final topLeft = tester.getTopLeft(find.byType(PageView));
    final right = topLeft + Offset(size.width * 0.9, size.height / 2);
    final left = topLeft + Offset(size.width * 0.1, size.height / 2);

    await tester.tapAt(right);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tapAt(right);
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('End of set'), findsOneWidget);

    await tester.tapAt(left);
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
    // Counted over all pages of the song (ADR-0007).
    final page = tester.getRect(find.byType(PageView));
    final indicator = find.byKey(const Key('live-song-page'));
    bool lastPage() {
      if (indicator.evaluate().isEmpty) return true;
      final pages = tester.widget<Text>(indicator).data!.split(' ').last;
      final [current, count] = pages.split('/');
      return current == count;
    }

    var labels = find.byIcon(Icons.repeat).evaluate().length;
    while (!lastPage()) {
      await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
      await tester.pumpAndSettle();
      labels += find.byIcon(Icons.repeat).evaluate().length;
    }
    expect(labels, 2);
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

  testWidgets('song sequence can be changed per set item', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    const source =
        '{title: Seq}\n{x_sequence: V, C}\n'
        '{sov}\n[C]a\n{eov}\n{soc}\n[F]b\n{eoc}\n{sob}\n[G]c\n{eob}';
    final ids = await tester.runAsync(() async {
      final songId = await app.songs.createSong(source: source);
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [songId]);
      return (songId, setId);
    });
    final (songId, setId) = ids!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    final chips = find.byKey(const ValueKey('sequence-chip'));
    expect(chips, findsNWidgets(2)); // the song's sequence

    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song sequence for this set'));
    await tester.pumpAndSettle();
    expect(find.text('In the song: V, C'), findsOneWidget);
    // Only the parts of the song can be added, by tapping them.
    for (final code in ['V', 'C', 'B']) {
      expect(find.byKey(ValueKey('sequence-part-$code')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('sequence-part-PC')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sequence-part-C')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sequence-part-B')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sequence-part-V')));
    await tester.pump();
    // V, C x2, B, V → remove the first V.
    final entries = find.byKey(const ValueKey('sequence-entry'));
    expect(entries, findsNWidgets(4));
    await tester.tap(
      find.descendant(of: entries.first, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(
      () async => (
        (await app.sets.getItems(setId)).single.item.sequence,
        (await app.songs.getSong(songId))!.chordproSource,
      ),
    );
    expect(stored!.$1, 'C x2, B, V');
    expect(stored.$2, source); // the song itself is unchanged
    expect(chips, findsNWidgets(3));
    expect(find.byKey(const ValueKey('sequence-from-set')), findsOneWidget);

    // Live mode from the set shows the set's sequence.
    final items = await tester.runAsync(
      () async => [
        for (final v in await app.sets.getItems(setId))
          LiveItem.song(v.song!, setSequence: v.item.sequence),
      ],
    );
    await tester.pumpWidget(app.build(home: LiveScreen(items: items!)));
    await tester.pumpAndSettle();
    expect(find.text('C x2'), findsOneWidget);
    expect(find.byKey(const ValueKey('sequence-from-set')), findsOneWidget);

    // Back to the song's sequence.
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song sequence for this set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Use the song's sequence"));
    await tester.pumpAndSettle();
    final reset = await tester.runAsync(
      () async => (await app.sets.getItems(setId)).single.item.sequence,
    );
    expect(reset, isNull);
    expect(chips, findsNWidgets(2));
    expect(find.byKey(const ValueKey('sequence-from-set')), findsNothing);
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

  group('song screen side panels', () {
    bool badge(WidgetTester tester, String key) => tester
        .widget<Badge>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Badge),
          ),
        )
        .isLabelVisible;

    Future<void> addPdf(TestApp app, String id) => app.songs.addAttachment(
      id,
      name: 'Lead sheet',
      bytes: Uint8List.fromList([1, 2, 3]),
      pages: 1,
      extension: 'pdf',
    );

    testWidgets('the personal icon shows a dot while the song is adjusted', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: '{title: X}\n{key: G}\n[G]One'),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(badge(tester, 'open-personal-adjustments'), isFalse);
      // Nothing of the adjustments is above the song any more.
      expect(find.byTooltip('Larger text'), findsNothing);

      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Larger text'));
      await tester.pumpAndSettle();
      expect(badge(tester, 'open-personal-adjustments'), isTrue);

      await tester.tap(find.text('Reset personal adjustments'));
      await tester.pumpAndSettle();
      expect(badge(tester, 'open-personal-adjustments'), isFalse);
      // The panel closes with its close button.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('personal-adjustments')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('attachments are in their own panel with a count', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: '{title: X}\n[G]One');
        await addPdf(app, id);
        return id;
      });
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.text('Lead sheet'), findsNothing);
      final icon = find.byKey(const Key('open-attachments'));
      expect(
        find.descendant(of: icon, matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-attachments')), findsOneWidget);
      expect(find.text('Lead sheet'), findsOneWidget);
      expect(find.text('Attach file'), findsOneWidget);
      // The live view is chosen there, too.
      expect(find.text('Show in live mode'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a song without ChordPro keeps its attachments in view', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: '{title: Sheet only}');
        await addPdf(app, id);
        return id;
      });
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-attachments')), findsNothing);
      expect(find.text('Lead sheet'), findsOneWidget);
      expect(find.text('This song has no ChordPro text yet.'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('the ChordPro editor opens from the overflow menu', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: '{title: X}\n[G]One'),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit ChordPro'), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit ChordPro'));
      await tester.pumpAndSettle();
      expect(find.byType(SongEditorScreen), findsOneWidget);
      await app.dispose(tester);
    });
  });

  group('the song screen fits the song to the screen', () {
    /// [verses] verses of short chord lines.
    String versesSong(int verses) =>
        '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

    var scrolls = false;

    /// The render options of the song; [scrolls] tells whether it scrolls.
    Future<SongRenderOptions> open(
      WidgetTester tester,
      String source, {
      Map<String, Object> prefs = const {},
    }) async {
      final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: source),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      final options = tester.widget<SongBody>(find.byType(SongBody)).options;
      scrolls =
          tester.getRect(find.byType(SongBody)).bottom >
          tester.getRect(find.byType(ListView)).bottom;
      await app.dispose(tester);
      return options;
    }

    testWidgets('a short song is enlarged', (tester) async {
      useTabletSize(tester);
      final options = await open(tester, '{title: Short}\n[C]One [G]two');
      expect(options.fontSize, greaterThan(20));
      expect(options.columns, 1);
    });

    testWidgets('a long song gets columns and scrolls', (tester) async {
      useTabletSize(tester);
      final options = await open(tester, versesSong(40));
      expect(options.fontSize, 20);
      expect(options.columns, greaterThan(1));
      expect(scrolls, isTrue);
    });

    testWidgets('a song that fits with smaller text gets columns', (
      tester,
    ) async {
      useTabletSize(tester);
      final options = await open(tester, versesSong(12));
      expect(options.columns, greaterThan(1));
      expect(options.layout, isNotNull);
    });

    testWidgets('a narrow screen keeps one column', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final options = await open(tester, versesSong(40));
      expect(options.columns, 1);
      expect(options.fontSize, 20);
    });

    testWidgets('without automatic fitting only the columns change', (
      tester,
    ) async {
      useTabletSize(tester);
      final short = await open(
        tester,
        '{title: Short}\n[C]One [G]two',
        prefs: {'autoFit': false},
      );
      expect(short.fontSize, 20);
      expect(short.columns, 1);
      final long = await open(
        tester,
        versesSong(40),
        prefs: {'autoFit': false},
      );
      expect(long.fontSize, 20);
      expect(long.columns, greaterThan(1));
    });

    testWidgets('the personal font scale applies on top', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: versesSong(40)),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Larger text'));
      await tester.pumpAndSettle();
      final options = tester.widget<SongBody>(find.byType(SongBody)).options;
      expect(options.fontSize, closeTo(22, 0.01));
      await app.dispose(tester);
    });
  });
}
