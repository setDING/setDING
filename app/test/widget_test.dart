import 'dart:io';

import 'package:chordpro/chordpro.dart'
    show ChordView, SequencePart, Subdivision;
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/song_header.dart';
import 'package:setding/ui/render/song_view.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/widgets/dialogs.dart';
import 'package:setding/ui/widgets/key_picker.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:setding/ui/home_tab.dart';

import 'test_app.dart';

import 'package:setding/ui/widgets/section_header.dart';

void main() {
  testWidgets('shows German UI with Swiss spelling when selected', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsWidgets);
    expect(find.text('Übersicht'), findsWidgets);
    await openTab(tester, HomeTab.sets);
    expect(find.text('Neues Set'), findsOneWidget);

    await tester.tap(find.text('Einstellungen').first);
    await tester.pumpAndSettle();
    // Font size is a device setting (ADR-0027).
    await tapSettingsCategory(tester, 'live');
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
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(app.personal()['language'], 'en');

    // The drop-down offers the other languages too (#983).
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italiano').last);
    await tester.pumpAndSettle();

    expect(find.text('Impostazioni'), findsWidgets);
    expect(app.personal()['language'], 'it');
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

  testWidgets('the tag menu selects several tags, songs with any of them', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    for (final source in [
      '{title: Carol}\n{tag: Advent}',
      '{title: Hymn}\n{tag: Communion}',
      '{title: Plain}',
    ]) {
      await tester.runAsync(() => app.songs.createSong(source: source));
    }
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    // One chip for all tags (#816) instead of one per tag.
    expect(find.byType(ChoiceChip), findsNothing);
    final chip = find.byKey(const Key('songs-tags'));
    expect(find.descendant(of: chip, matching: find.text('Tags')), findsOne);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('songs-tag-Advent')).first);
    await tester.pumpAndSettle();
    // The menu stays open for the next tag.
    await tester.tap(find.byKey(const ValueKey('songs-tag-Communion')).first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chip, matching: find.text('Advent +1')),
      findsOne,
    );
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Carol'), findsOne);
    expect(find.text('Hymn'), findsOne);
    expect(find.text('Plain'), findsNothing);

    // Unticking one leaves the other.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('songs-tag-Advent')).first);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chip, matching: find.text('Communion')),
      findsOne,
    );
    expect(find.text('Carol'), findsNothing);
    expect(find.text('Hymn'), findsOne);

    // "All" clears the selection and closes the menu.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-tags-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('songs-tags-all')), findsNothing);
    expect(find.text('Carol'), findsOne);
    expect(find.text('Plain'), findsOne);
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

    final chip = find.byKey(const Key('songs-tags'));
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('songs-tag-Gig')).first);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsNothing);

    await tester.runAsync(() => app.songs.deleteSong(tagged!));
    await tester.pumpAndSettle();
    expect(find.text('Tagged'), findsNothing);
    // The filter is still there and "All" shows the other songs again.
    expect(find.descendant(of: chip, matching: find.text('Gig')), findsOne);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-tags-all')));
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsOneWidget);
    // Without a selection the unused tag disappears, and with it the chip.
    expect(chip, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the chord view can be chosen per song (ADR-0055)', (
    tester,
  ) async {
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
    final button = find.byKey(const Key('chord-view-button'));
    expect(
      find.descendant(of: button, matching: find.text('Chord view: Chords')),
      findsOneWidget,
    );
    Future<void> choose(String view) async {
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('chord-view-$view')));
      await tester.pumpAndSettle();
    }

    await choose('nashville');
    expect(find.text('4'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(id)))!.chordView,
      ChordView.nashville,
    );

    await choose('numerals');
    expect(find.text('IV'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('Chord view: Numerals'), findsOneWidget);

    await choose('chords');
    expect(find.text('C'), findsOneWidget);
    expect(find.text('IV'), findsNothing);
    // Back to the device setting.
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(id)))!.chordView,
      isNull,
    );
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
    expect(app.personal()['instrument'], 'ukulele');
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

  testWidgets('song list shows the key as a badge and the sequence', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'notation': 'german'},
    );
    await tester.runAsync(() async {
      await app.songs.createSong(
        source: '{title: Alpha}\n{key: Bb}\n{x_sequence: I, V, C x2}',
      );
      await app.songs.createSong(source: '{title: Beta}');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();

    // Key in the chosen notation (German: Bb is B), in its own badge.
    final badge = find.byKey(const ValueKey('song-key-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('B')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Key: B')), findsOneWidget);
    // The sequence as chips; songs without one show none.
    expect(find.byType(SongSequenceView), findsOneWidget);
    expect(find.text('C x2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('song list sorts by key with section headers', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}\n{key: G}');
      await app.songs.createSong(source: '{title: Ännchen}\n{key: G}');
      await app.songs.createSong(source: '{title: 99 Luftballons}');
      await app.songs.createSong(source: '{title: Bravo}\n{key: D}');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();

    List<String> headers() => [
      for (final e
          in find.byKey(const ValueKey('song-section-header')).evaluate())
        (e.widget as SectionHeader).label,
    ];
    // By title: first letters without accents, others under #.
    expect(headers(), ['#', 'A', 'B']);

    await tester.tap(find.byKey(const Key('songs-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Key'));
    await tester.pumpAndSettle();
    expect(headers(), ['D', 'G', 'No key']);
    expect(app.prefs.getString('songSort'), 'key');

    await tester.tap(find.byKey(const Key('songs-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Recently edited'));
    await tester.pumpAndSettle();
    expect(headers(), isEmpty);
    await app.dispose(tester);
  });

  testWidgets('song list shows conflict, gig and PDF-only status', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: '{title: Alpha}\n[G]x');
      await app.songs.createSong(title: 'Sheet');
      await app.songs.createSong(source: '{title: Plain}\n[G]x');
      await app.db
          .into(app.db.songConflicts)
          .insert(
            SongConflictsCompanion.insert(
              songId: a,
              title: 'Alpha',
              chordproSource: '{title: Alpha}',
              revision: 2,
              detectedAt: DateTime.now(),
            ),
          );
      final set = await app.sets.createSet(
        name: 'Summer Festival',
        gigDate: DateTime.now().add(const Duration(days: 3)),
      );
      await app.sets.addSongs(set, [a]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();

    Finder status(String name) => find.byKey(ValueKey('song-status-$name'));
    expect(status('conflict'), findsOneWidget);
    expect(status('gig'), findsOneWidget);
    expect(status('pdf-only'), findsOneWidget);
    expect(
      tester.widget<Tooltip>(status('gig')).message,
      startsWith('In “Summer Festival” on '),
    );
    // Same row as their song.
    final alpha = tester.getCenter(find.text('Alpha')).dy;
    expect(
      (tester.getCenter(status('conflict')).dy - alpha).abs(),
      lessThan(30),
    );
    expect(
      (tester.getCenter(status('pdf-only')).dy -
              tester.getCenter(find.text('Sheet')).dy)
          .abs(),
      lessThan(30),
    );
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

  testWidgets('the song screen shows the title once, in the app bar', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(
      () => app.songs.createSong(
        source: '{title: Only Once}\n{artist: Someone}\n{key: G}\n[G]x',
      ),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    expect(find.text('Only Once'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Only Once'),
      ),
      findsOneWidget,
    );
    // The header keeps the artist.
    expect(
      find.descendant(
        of: find.byType(SongHeader),
        matching: find.text('Someone'),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('a break without a note of its own shows its label once', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = await tester.runAsync(() async {
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Coffee');
      await app.sets.addMarker(setId, MarkerIcons.announcement, '');
      return setId;
    });
    await tester.pumpWidget(app.build(home: SetScreen(setId: setId!)));
    await tester.pumpAndSettle();
    // "Break" as the title only; "Coffee" without the icon's name.
    expect(find.text('Break'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    final breakTile = tiles.firstWhere(
      (t) => (t.title as Text?)?.data == 'Break',
    );
    expect(breakTile.subtitle, isNull);
    final coffee = tiles.firstWhere(
      (t) => (t.title as Text?)?.data == 'Coffee',
    );
    expect(coffee.subtitle, isNull);
    // A marker without text shows its icon's name once (ADR-0047).
    expect(find.text('Announcement'), findsOneWidget);
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
      await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Coffee');
      return [
        for (final v in await app.sets.getItems(setId))
          v.song == null
              ? LiveItem.marker(v.item.icon, v.item.note)
              : LiveItem.song(v.song!),
      ];
    });
    await tester.pumpWidget(app.build(home: LiveScreen(items: items!)));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Next: Second (D)'), findsOneWidget);
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

  testWidgets('live mode of a set hides the parts outside the sequence', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'showOutsideSequence': false},
    );
    const source =
        '{title: Seq}\n{x_sequence: V1, C, V2}\n'
        '{sov}\nfirst verse\n{eov}\n{soc}\nthe chorus\n{eoc}\n'
        '{sov}\nsecond verse\n{eov}\n{sob}\nthe bridge\n{eob}\n'
        '{start_of_verse: Coda}\nthe coda\n{end_of_verse}';
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(source: source);
      return app.songs.getSong(id);
    });

    // In a set: the song's own sequence applies, the set item's replaces it.
    for (final (setSequence, hidden, shown) in [
      (
        null,
        ['the bridge', 'the coda'],
        'Hidden (not in the sequence): B, Coda',
      ),
      (
        'C, B',
        ['first verse', 'the coda'],
        'Hidden (not in the sequence): V1, V2, Coda',
      ),
    ]) {
      await tester.pumpWidget(
        app.build(
          home: LiveScreen(
            key: UniqueKey(),
            items: [
              LiveItem.song(song!, setItemId: 'i1', setSequence: setSequence),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in hidden) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
      expect(find.byKey(const Key('hidden-parts')), findsOneWidget);
      expect(find.text(shown), findsOneWidget);
    }
    expect(find.textContaining('the bridge'), findsWidgets);

    // A single song applies its own sequence, too (#552).
    await tester.pumpWidget(
      app.build(
        home: LiveScreen(key: UniqueKey(), items: [LiveItem.song(song!)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('the bridge'), findsNothing);
    expect(find.text('Hidden (not in the sequence): B, Coda'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets(
    'live mode of a set shows the parts outside the sequence dimmed',
    (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      const source =
          '{title: Seq}\n{x_sequence: V1, C, V2}\n'
          '{sov}\nfirst verse\n{eov}\n{soc}\nthe chorus\n{eoc}\n'
          '{sov}\nsecond verse\n{eov}\n{sob}\nthe bridge\n{eob}\n'
          '{start_of_verse: Coda}\nthe coda\n{end_of_verse}';
      final song = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: source);
        return app.songs.getSong(id);
      });

      Future<void> showInSet() async {
        await tester.pumpWidget(
          app.build(
            home: LiveScreen(
              key: UniqueKey(),
              items: [LiveItem.song(song!, setItemId: 'i1')],
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      bool dimmed(String text) => find
          .ancestor(
            of: find.textContaining(text),
            matching: find.byKey(const ValueKey('dimmed-section')),
          )
          .evaluate()
          .isNotEmpty;

      // By default all parts are shown, in the order of the song; those
      // outside the sequence dimmed.
      await showInSet();
      expect(find.byKey(const Key('hidden-parts')), findsNothing);
      final tops = [
        for (final text in [
          'first verse',
          'the chorus',
          'second verse',
          'the bridge',
          'the coda',
        ])
          tester.getTopLeft(find.textContaining(text).first).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      for (final text in ['first verse', 'the chorus', 'second verse']) {
        expect(dimmed(text), isFalse, reason: text);
      }
      for (final text in ['the bridge', 'the coda']) {
        expect(dimmed(text), isTrue, reason: text);
      }
      final opacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('dimmed-section')).first,
      );
      expect(opacity.opacity, dimmedSectionOpacity);

      // A single song is dimmed by its own sequence, too (#552).
      await tester.pumpWidget(
        app.build(
          home: LiveScreen(key: UniqueKey(), items: [LiveItem.song(song!)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(dimmed('the bridge'), isTrue);
      expect(dimmed('the chorus'), isFalse);

      // Switched off in the settings, they are hidden again.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveScreen)),
      );
      await tester.runAsync(
        () => container
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(showOutsideSequence: false)),
      );
      await tester.pumpAndSettle();
      await showInSet();
      expect(find.textContaining('the bridge'), findsNothing);
      expect(find.byKey(const ValueKey('dimmed-section')), findsNothing);
      expect(find.byKey(const Key('hidden-parts')), findsOneWidget);
      await app.dispose(tester);
    },
  );

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
    // The add icon takes the text colour of the part (#288): the chorus
    // chip is filled with the primary colour, the default icon colour.
    final scheme = Theme.of(
      tester.element(find.byKey(const ValueKey('sequence-part-C'))),
    ).colorScheme;
    final addIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('sequence-part-C')),
        matching: find.byIcon(Icons.add),
      ),
    );
    expect(
      addIcon.color,
      SongSequenceView.foreground(scheme, SequencePart.chorus),
    );
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
    await openTab(tester, HomeTab.sets);

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
    // Everything is on the device: no offline mark (#744).
    expect(find.byType(OfflineMissingBadge), findsNothing);
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

    testWidgets('chords in verse 1 only hides the chords of later verses', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source:
              '{title: X}\n{start_of_verse: Verse 1}\n[G]First line\n'
              '{end_of_verse}\n{start_of_chorus}\n[C]Chorus line\n'
              '{end_of_chorus}\n{start_of_verse: Verse 2}\n'
              '[Em]Second line\n{end_of_verse}',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.text('Em'), findsOneWidget);

      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-first')));
      await tester.pumpAndSettle();
      // Verse 2 keeps its lyrics; verse 1 and the chorus keep their chords.
      expect(find.text('Em'), findsNothing);
      expect(find.textContaining('Second line'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isTrue);
      final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
      expect(overlay!.verseChords, VerseChords.first);

      await tester.tap(find.text('Reset personal adjustments'));
      await tester.pumpAndSettle();
      expect(find.text('Em'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isFalse);
      await app.dispose(tester);
    });

    testWidgets('grouping and subdivisions of the click for drummers (#698)', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'instrument': 'drums'},
      );
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source: '{title: X}\n{tempo: 120}\n{time: 7/8}\n[G]One',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      expect(find.text('Grouping: No groups'), findsOneWidget);
      expect(find.text('Subdivisions: Off'), findsOneWidget);

      await tester.tap(find.byKey(const Key('click-grouping-button')));
      await tester.pumpAndSettle();
      expect(find.text('As in the song (No groups)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('click-grouping-2+3+2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('click-subdivision-button')));
      await tester.pumpAndSettle();
      expect(find.text('As in the settings (Off)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('click-subdivision-triplets')));
      await tester.pumpAndSettle();
      expect(find.text('Grouping: 2+3+2'), findsOneWidget);
      expect(find.text('Subdivisions: Triplets'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isTrue);
      final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
      expect(overlay!.clickGrouping, '2+3+2');
      expect(overlay.clickSubdivision, Subdivision.triplets);

      await tester.tap(find.text('Reset personal adjustments'));
      await tester.pumpAndSettle();
      expect(find.text('Grouping: No groups'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isFalse);
      await app.dispose(tester);
    });

    testWidgets('no click choices for a guitarist without the beat', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source: '{title: X}\n{tempo: 120}\n{time: 7/8}\n[G]One',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('click-grouping-button')), findsNothing);
      expect(find.byKey(const Key('click-subdivision-button')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('chords in verse 1 only needs later verses with chords', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: '{title: X}\n{sov}\n[G]One\n{eov}'),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ActionChip>(
        find.byKey(const Key('verse-chords-button')),
      );
      expect(chip.onPressed, isNull);
      expect(
        find.byTooltip('The song has no further verses with chords.'),
        findsOneWidget,
      );
      await app.dispose(tester);
    });

    testWidgets('stacked verses show the chords once over every verse', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source:
              '{title: X}\n{start_of_verse: Verse 1}\n[G]First [D]alpha\n'
              '{end_of_verse}\n{start_of_chorus}\n[C]Chorus line\n'
              '{end_of_chorus}\n{start_of_verse: Verse 2}\n'
              '[G]Second [D]beta\n{end_of_verse}\n'
              '{start_of_verse: Verse 3}\nThird three\n{end_of_verse}',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.text('G'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-stacked')));
      await tester.pumpAndSettle();
      // The chords once, the verses numbered under them.
      expect(find.text('G'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      for (final number in ['1.', '2.', '3.']) {
        expect(find.text(number), findsOneWidget);
      }
      expect(find.text('VERSE 1–3'), findsOneWidget);
      // The words under the same chord are left-aligned in one column.
      final second = tester.getTopLeft(find.text('beta'));
      final first = tester.getTopLeft(find.text('alpha'));
      expect(second.dx, first.dx);
      expect(second.dy, greaterThan(first.dy));
      // Verse 3 has no chords: its line is in one piece.
      expect(find.textContaining('Third three'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isTrue);
      final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
      expect(overlay!.verseChords, VerseChords.stacked);
      await app.dispose(tester);
    });

    testWidgets('stacked choruses show the chords once over the changed '
        'words (#953)', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source:
              '{title: X}\n{sov}\n[A]Verse one\n{eov}\n'
              '{soc}\n[G]Sing it [D]loud\n{eoc}\n'
              '{sov}\n[A]Verse two\n{eov}\n'
              '{soc}\n[G]Sing it [D]soft\n{eoc}',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      expect(find.text('G'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      // The chorus chords once, the verses as written.
      expect(find.text('G'), findsOneWidget);
      expect(find.text('A'), findsNWidgets(2));
      expect(find.text('Choruses stacked'), findsOneWidget);
      expect(badge(tester, 'open-personal-adjustments'), isTrue);
      final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
      expect(overlay!.stackedChoruses, isTrue);
      expect(overlay.verseChords, VerseChords.all);
      await app.dispose(tester);
    });

    testWidgets('choruses that only repeat cannot be stacked (#953)', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(
          source:
              '{title: X}\n{sov}\n[A]One\n{eov}\n{sov}\n[A]Two\n{eov}\n'
              '{soc}\n[G]Same\n{eoc}\n{chorus}',
        ),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personal adjustments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-button')));
      await tester.pumpAndSettle();
      final item = tester.widget<CheckboxMenuButton>(
        find.byType(CheckboxMenuButton),
      );
      expect(item.onChanged, isNull);
      await app.dispose(tester);
    });

    testWidgets('stacked verses join the syllables of a split word', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(() async {
        final id = await app.songs.createSong(
          source:
              '{title: X}\n{sov}\nA[G]mazing [D]grace\n{eov}\n'
              '{sov}\nThrough many [G]dangers [D]here\n{eov}',
        );
        final overlay = await app.songs.getOverlay(id);
        await app.songs.saveOverlay(
          overlay.copyWith(verseChords: VerseChords.stacked),
        );
        return id;
      });
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      // One hyphen, in the gap between the syllables of verse 1 only.
      final hyphen = find.text('-');
      expect(hyphen, findsOneWidget);
      final a = tester.getRect(find.text('A'));
      final rest = tester.getRect(find.text('mazing '));
      final dash = tester.getRect(hyphen);
      expect(dash.left, greaterThan(a.right));
      expect(dash.right, lessThan(rest.left));
      expect(dash.center.dy, closeTo(a.center.dy, 1));
      // The second syllable stays under its chord.
      expect(rest.left, tester.getRect(find.text('dangers ')).left);
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

    testWidgets('a PDF opens without changing the live view choice', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final (id, pdfId) = (await tester.runAsync(() async {
        final id = await app.songs.createSong(source: '{title: X}\n[G]One');
        final pdfId = await app.songs.addAttachment(
          id,
          name: 'Lead sheet',
          bytes: Uint8List.fromList([1, 2, 3]),
          pages: 1,
          extension: 'pdf',
        );
        return (id, pdfId);
      }))!;
      await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('open-attachment-$pdfId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final live = tester.widget<LiveScreen>(find.byType(LiveScreen));
      expect(live.items.single.attachmentId, pdfId);
      // The personal live view stays on ChordPro.
      final overlay = await tester.runAsync(() => app.songs.getOverlay(id));
      expect(overlay!.liveView, isNull);
      await app.dispose(tester);
    });

    testWidgets('an image attachment opens full screen', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: '{title: X}\n[G]One');
        await app.songs.addAttachment(
          id,
          name: 'photo.svg',
          bytes: Uint8List.fromList(
            '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>'
                .codeUnits,
          ),
          extension: 'svg',
        );
        return id;
      });
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('photo.svg'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('image-attachment')), findsOneWidget);
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

    testWidgets('the ChordPro editor opens from its app bar button', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: '{title: X}\n[G]One'),
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();
      // The pencil comes first, a divider sets it apart from the panel
      // buttons (#600).
      final actions = tester.widget<AppBar>(find.byType(AppBar)).actions!;
      expect(actions[0].key, const Key('edit-song'));
      expect(actions[1].key, const Key('edit-song-divider'));
      expect(find.byKey(const Key('song-problems')), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit ChordPro'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit ChordPro'));
      await tester.pumpAndSettle();
      expect(find.byType(SongEditorScreen), findsOneWidget);
      await app.dispose(tester);
    });
  });

  group('undo of deletions (#267)', () {
    Finder appBarMenu() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(PopupMenuButton<String>),
    );

    testWidgets('a deleted song comes back with Undo', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(
        () => app.songs.createSong(source: '{title: Gone Soon}\n[C]la'),
      );
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Songs').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gone Soon'));
      await tester.pumpAndSettle();

      await tester.tap(appBarMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Songs are still confirmed first: shared with the whole organization.
      expect(find.text('Delete song?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(SongScreen), findsNothing);
      expect(find.text('Gone Soon'), findsNothing);
      expect(find.text('“Gone Soon” deleted'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Gone Soon'), findsOneWidget);
      expect(
        (await tester.runAsync(() => app.songs.getSong(id!)))!.deleted,
        isFalse,
      );
      await app.dispose(tester);
    });

    testWidgets('a removed set item comes back with Undo', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final setId = await tester.runAsync(() async {
        final a = await app.songs.createSong(source: '{title: First}');
        final b = await app.songs.createSong(source: '{title: Second}');
        final setId = await app.sets.createSet(name: 'Gig');
        await app.sets.addSongs(setId, [a, b]);
        return setId;
      });
      await tester.pumpWidget(app.build(home: SetScreen(setId: setId!)));
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-'))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from set'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('“First” removed from the set'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      final items = (await tester.runAsync(() => app.sets.getItems(setId)))!;
      expect(items.map((i) => i.song?.title), ['First', 'Second']);
      expect(find.text('First'), findsOneWidget);
      await app.dispose(tester);
    });

    for (final wide in [false, true]) {
      testWidgets('a deleted set comes back with Undo '
          '(${wide ? 'next to the list' : 'own page'})', (tester) async {
        useTabletSize(tester, landscape: wide);
        final app = await TestApp.create(prefs: {'language': 'en'});
        await tester.runAsync(() async {
          final a = await app.songs.createSong(source: '{title: Opener}');
          final setId = await app.sets.createSet(name: 'Summer Gig');
          await app.sets.addSongs(setId, [a]);
        });
        await tester.pumpWidget(app.build());
        await tester.pumpAndSettle();
        await openTab(tester, HomeTab.sets);
        // Wide screens show the set next to the list already.
        if (!wide) {
          await tester.tap(find.text('Summer Gig'));
          await tester.pumpAndSettle();
        }

        await tester.tap(
          find.descendant(of: find.byType(SetScreen), matching: appBarMenu()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.byType(SetScreen), findsNothing);
        expect(find.text('Summer Gig'), findsNothing);
        expect(find.text('Set “Summer Gig” deleted'), findsOneWidget);

        await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
        await tester.pumpAndSettle();
        expect(find.text('Summer Gig'), findsWidgets);
        expect(find.byType(SetScreen), wide ? findsOneWidget : findsNothing);
        await app.dispose(tester);
      });
    }

    testWidgets('attachments are deleted without asking, with Undo', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await tester.runAsync(() async {
        final id = await app.songs.createSong(title: 'Sheet only');
        await app.songs.addAttachment(
          id,
          name: 'Lead sheet',
          bytes: Uint8List.fromList([1, 2, 3]),
          pages: 1,
        );
        await app.songs.addAttachment(
          id,
          name: 'Horns',
          bytes: Uint8List.fromList([4]),
          pages: 1,
        );
        return id;
      });
      final files = {
        for (final a in (await tester.runAsync(
          () => app.songs.getAttachments(id!),
        ))!)
          a.name: a.fileName,
      };
      await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
      await tester.pumpAndSettle();

      Future<void> delete(String name) async {
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, name),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
      }

      await delete('Lead sheet');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Lead sheet'), findsNothing);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Lead sheet'), findsOneWidget);

      // Without Undo the file goes once the message is gone.
      await delete('Horns');
      expect(find.text('Horns'), findsNothing);
      expect(find.text('Attachment “Horns” deleted'), findsOneWidget);
      await tester.pump(undoDuration);
      await tester.pumpAndSettle();
      expect(find.text('Attachment “Horns” deleted'), findsNothing);
      bool exists(String name) =>
          File('${app.dir.path}/${files[name]}').existsSync();
      // The files are purged with real database and file IO outside the
      // fake clock, which takes a while on a busy machine (#353): wait for
      // it in real time, for at most five seconds.
      for (var i = 0; i < 250 && exists('Horns'); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(exists('Horns'), isFalse);
      expect(exists('Lead sheet'), isTrue);
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
