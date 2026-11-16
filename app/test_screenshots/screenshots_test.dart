// Renders screenshots with real fonts for visual review.
// Run: flutter test test_screenshots   (output in build/screenshots/)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:realchord/data/database.dart';
import 'package:realchord/data/demo_song.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/sets/set_screen.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';
import 'package:realchord/ui/songs/song_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Italic.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  // A system monospace font for tabs and sources, if available.
  const mono = '/usr/share/fonts/TTF/DejaVuSansMono.ttf';
  if (File(mono).existsSync()) {
    final loader = FontLoader('monospace')
      ..addFont(
        Future.value(ByteData.sublistView(File(mono).readAsBytesSync())),
      );
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
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

void main() {
  setUpAll(() async => _loadFonts());

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    testWidgets('screenshots $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final ids = await tester.runAsync(() async {
        final a = await app.songs.createSong(source: demoSongSource);
        final b = await app.songs.createSong(
          source: '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n[Bb7]Blues [Eb7]line\n',
        );
        await app.songs.saveOverlay(
          (await app.songs.getOverlay(
            a,
          )).copyWith(notes: const Value('Count in 4, ritardando at the end')),
        );
        final setId = await app.sets.createSet(
          name: 'Summer Festival',
          venue: 'Bern',
          gigDate: DateTime(2027, 6, 21),
        );
        await app.sets.addSongs(setId, [a, b]);
        await app.sets.addMarker(
          setId,
          SetItemType.pause,
          lang == 'de' ? 'Pause' : 'Break',
        );
        return [a, setId];
      });

      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await _shot(tester, '${lang}_1_sets');
      await tester.tap(find.text('Summer Festival'));
      await _shot(tester, '${lang}_2_set');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: ids![0])),
        ),
      );
      await _shot(tester, '${lang}_3_song');

      final items = await tester.runAsync(
        () async => [
          for (final v in await app.sets.getItems(ids[1]))
            v.song == null
                ? LiveItem.marker(v.item.type, v.item.note)
                : LiveItem.song(v.song!),
        ],
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await _shot(tester, '${lang}_4_live');
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items)),
        ),
      );
      await _shot(tester, '${lang}_5_live_portrait');

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
      await _shot(tester, '${lang}_6_chordpro_showcase');

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
      await _shot(tester, '${lang}_7_diagrams');

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
      await _shot(tester, '${lang}_8_media');

      // Song editor with grouped insert menus; the preview starts at the top.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(initialSource: demoSongSource),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'de' ? 'Abschnitte' : 'Sections'));
      await _shot(tester, '${lang}_9_editor');

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
      await _shot(tester, '${lang}_9b_editor_highlighting');

      // Autocompletion of directives after "{".
      await tester.tap(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        '{title: Autocomplete}\n{key: G}\n[G]la [Em]li\n{st',
      );
      await _shot(tester, '${lang}_9c_editor_autocomplete');

      // Song sequence for a set item, built from the parts of the song.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SetScreen(setId: ids[1])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.format_list_numbered).first);
      await tester.pumpAndSettle();
      for (final code in ['V1', 'C', 'V2', 'C']) {
        await tester.tap(find.byKey(ValueKey('sequence-part-$code')));
        await tester.pump();
      }
      await _shot(tester, '${lang}_10_set_sequence');
      await app.dispose(tester);
    });
  }
}

const _showcase = r'''{title: ChordPro Showcase}
{artist: RealChord}
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
