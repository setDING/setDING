// The main screens in one app session: sets, set, song, song list, live
// mode, editor and sequence. Run per language by tour_de_screenshots_test.dart
// and tour_en_screenshots_test.dart, so the two run in parallel.

import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

/// Renders the main screens in [lang], in the dark theme if [dark].
void tourScreenshots(String lang, bool dark) {
  screenshotTest('main screens $lang', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
    );
    final ids = await tester.runAsync(() async {
      final a = await app.songs.createSong(source: demoSongSource);
      final b = await app.songs.createSong(
        source: '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n{tag: Blues}\n{x_sequence: I, V, PC, C, V, PC, C x2, B, O}\n[Bb7]Blues [Eb7]line\n',
      );
      await app.songs.saveOverlay(
        (await app.songs.getOverlay(a))
            .copyWith(notes: const Value('Count in 4, ritardando at the end')),
      );
      final setId = await app.sets.createSet(
        name: 'Summer Festival',
        venue: 'Bern',
        gigDate: DateTime(2027, 6, 21),
      );
      await app.sets.addSongs(setId, [a, b]);
      await app.sets.addMarker(
        setId,
        MarkerIcons.breakIcon,
        lang == 'de' ? 'Pause' : 'Break',
      );
      return [a, setId];
    });

    await tester.pumpWidget(
      RepaintBoundary(key: UniqueKey(), child: app.build()),
    );
    // Wide: the next gig is shown next to the list (#266).
    await shot(tester, '${lang}_1_sets');
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: SetScreen(setId: ids![1])),
      ),
    );
    await shot(tester, '${lang}_2_set');
    // The ⋮ menu of the set: print, share and export the set list.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await shot(tester, '${lang}_2b_set_menu');
    // The marker dialog with an icon and a text (ADR-0047).
    await tester.tap(
      find.text(lang == 'de' ? 'Hinweis hinzufügen' : 'Add marker'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('marker-icon-encore')));
    await tester.pumpAndSettle();
    await shot(tester, '${lang}_2c_marker_dialog');

    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: SongScreen(songId: ids[0])),
      ),
    );
    await shot(tester, '${lang}_3_song');
    // ? lists the keyboard shortcuts (#729).
    await tester.sendKeyEvent(
      LogicalKeyboardKey.slash,
      character: '?',
      physicalKey: PhysicalKeyboardKey.slash,
    );
    await shot(tester, '${lang}_30_shortcuts');

    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: const SongsScreen()),
      ),
    );
    await shot(tester, '${lang}_3_songs');
    // Selection mode: select all, copy to band and delete selected (#738).
    await tester.longPress(find.text('Blue Monday Groove'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is Checkbox && w.value == false).first,
    );
    await shot(tester, '${lang}_3c_songs_selected');

    final items = await tester.runAsync(
      () async => [
        for (final v in await app.sets.getItems(ids[1]))
          v.song == null
              ? LiveItem.marker(v.item.icon, v.item.note)
              : LiveItem.song(v.song!),
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items!)),
      ),
    );
    await shot(tester, '${lang}_4_live');
    // A tap in the middle shows the control bar.
    await tester.tapAt(tester.getRect(find.byType(PageView)).center);
    await shot(tester, '${lang}_4b_live_controls');
    // The page of a marker (ADR-0047): the break after the two songs.
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items, initialIndex: 2)),
      ),
    );
    await shot(tester, '${lang}_4c_live_marker');
    // Stage appearance independent of the app theme (#263): dark on the
    // light German app, true black on the dark English one.
    final stage = lang == 'de' ? 'dark' : 'black';
    await app.prefs.setString('liveAppearance', stage);
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items)),
      ),
    );
    await shot(tester, '${lang}_4_live_$stage');
    // The second song shows the sequence chips (chorus, pre-chorus,
    // bridge and other parts, #288) on the stage and in the app theme.
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items, initialIndex: 1)),
      ),
    );
    await shot(tester, '${lang}_4_live_${stage}_sequence');
    await app.prefs.setString('liveAppearance', 'app');
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items, initialIndex: 1)),
      ),
    );
    await shot(tester, '${lang}_4_live_sequence');
    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items)),
      ),
    );
    await shot(tester, '${lang}_5_live_portrait');

    // Showcase of ChordPro features (ADR-0012).
    tester.view.physicalSize = const Size(1280, 800);
    final showcase = await tester.runAsync(() async {
      final id = await app.songs.createSong(source: _showcase);
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: [LiveItem.song(showcase!)])),
      ),
    );
    await shot(tester, '${lang}_6_chordpro_showcase');

    // Chord diagrams below the song (guitar in English, ukulele in German).
    await app.prefs.setString('diagrams', 'bottom');
    await app.prefs.setString(
      'instrument',
      lang == 'de' ? 'ukulele' : 'guitar',
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: items)),
      ),
    );
    await shot(tester, '${lang}_7_diagrams');

    // Delegated environments: SVG, textblock, Lilypond source.
    await app.prefs.setString('diagrams', 'off');
    final media = await tester.runAsync(() async {
      final id = await app.songs.createSong(source: _media);
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: [LiveItem.song(media!)])),
      ),
    );
    await shot(tester, '${lang}_8_media');

    // Song editor with grouped insert menus; the preview starts at the top.
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: SongEditorScreen(initialSource: demoSongSource)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(lang == 'de' ? 'Abschnitte' : 'Sections'));
    await shot(tester, '${lang}_9_editor');

    // Syntax highlighting of every kind of ChordPro element.
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(
          home: const SongEditorScreen(initialSource: _highlightSource),
        ),
      ),
    );
    // The cursor after "[" of [*Riff] highlights the bracket pair.
    tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .selection = TextSelection.collapsed(
      offset: _highlightSource.indexOf('[*Riff]') + 1,
    );
    await shot(tester, '${lang}_9b_editor_highlighting');

    // Autocompletion of directives after "{".
    await tester.tap(find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      '{title: Autocomplete}\n{key: G}\n[G]la [Em]li\n{st',
    );
    await shot(tester, '${lang}_9c_editor_autocomplete');

    // Song sequence for a set item, built from the parts of the song.
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: SetScreen(setId: ids[1])),
      ),
    );
    await tester.pumpAndSettle();
    // The ⋮ menu of the first set item (the demo song).
    await tester.tap(
      find
          .byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-'))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-item-action-sequence')));
    await tester.pumpAndSettle();
    for (final code in ['V1', 'C', 'V2', 'C']) {
      await tester.tap(find.byKey(ValueKey('sequence-part-$code')));
      await tester.pump();
    }
    await shot(tester, '${lang}_10_set_sequence');
    await app.dispose(tester);
  });
}

/// Editor content for the highlighting screenshot: one line per token kind.
const _highlightSource = '''{title: Highlighting}
{key: G}
{x_sequence: V, C}
# A comment line
{start_of_verse: label="Verse 1"}
[G]Lyrics with <b>markup</b>, [*Riff] and [Xyz] [N.C.]
{comment-alto: Selector}
{comment: A long comment wraps onto a second row in the editor; the line number stays on the first row}
{textsize: 120%}
{end_of_verse}
{start_of_grid}
| G . . . | C . D . :|
{end_of_grid}
{start_of_tab}
e|--0--2--|
{end_of_tab}
{start_of_abc}
X:1
K:G
{end_of_abc}
[Am unclosed
''';

const _showcase = r'''{title: ChordPro Showcase}
{artist: setDING}
{key: D}
{tempo: 100}
{c: Key %{key}, %{tempo} BPM}

{start_of_verse: label="Verse 1\nAll voices"}
[D]Markup is <b>bold</b>, <i>italic</i> and [G]<span color="red">red</span>,
[Em]<u>underlined</u> and <span size="larger">larger</span> [A7]too.
{end_of_verse}

{textcolour: #1e88e5}
{start_of_chorus}
[G]A coloured [D]chorus [A]line,
[G]sung with [D]joy [A]all the [D]time.
{end_of_chorus}
{textcolour}

{column_break}
{start_of_grid shape="1+4x2+1" label="Interlude"}
A   || D . | G . | % . | A7 . |
    | Em~A7 . | / . | D . | . . || x2
{end_of_grid}

{transpose: 2}
{start_of_bridge: Bridge (+2)}
[D]Modulates up [G]two [A]semitones
{end_of_bridge}
''';

const _media = r'''{title: Media Showcase}
{start_of_verse}
[G]A verse before the [D]picture
{end_of_verse}
{start_of_svg label="Stage plan"}
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 120">
<rect x="5" y="5" width="290" height="110" rx="10" fill="none" stroke="#7986cb" stroke-width="3"/>
<circle cx="70" cy="60" r="22" fill="#3f51b5"/><text x="70" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Guitar</text>
<circle cx="150" cy="45" r="22" fill="#e53935"/><text x="150" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Vocals</text>
<circle cx="230" cy="60" r="22" fill="#43a047"/><text x="230" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Bass</text>
</svg>
{end_of_svg}
{start_of_textblock flush=center align=center label="Spoken intro"}
Ladies and gentlemen,
<i>please welcome</i> the <b>band</b>!
{end_of_textblock}
{start_of_abc}
X:1
T:Speed the Plough
M:4/4
L:1/8
K:G
|:"G"GABG DGBG|"D"A2 AB c2 Bc|"G"d^cdB "C"c2 =cB|1 "D7"A3 G A4:|2 "D7"A2 F2 G4||
w:one two three four
{end_of_abc}
{start_of_ly label="Melody"}
\relative c' { c4 d e f | g2 g }
{end_of_ly}
''';
