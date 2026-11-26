import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/song_grid.dart';
import 'package:setding/ui/render/song_header.dart';
import 'package:setding/ui/render/song_view.dart';
import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Renders [source] with [SongBody] inside the app (theme, localization).
Future<TestApp> pumpSong(
  WidgetTester tester,
  String source, {
  int transpose = 0,
  ChordStyle style = ChordStyle.asWritten,
  bool superscript = false,
}) async {
  useTabletSize(tester);
  final app = await TestApp.create(prefs: {'language': 'en'});
  final song = parseChordPro(source);
  await tester.pumpWidget(
    app.build(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SongBody(
            song: song,
            options: SongRenderOptions(
              formatter: ChordFormatter.forSong(
                song,
                transpose: transpose,
                style: style,
                superscript: superscript,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

/// The style of the span that contains [text].
TextStyle? styleOf(WidgetTester tester, String text) {
  TextStyle? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}

void main() {
  testWidgets('markup in lyrics, chords and comments', (tester) async {
    final app = await pumpSong(
      tester,
      '[<b>C</b>]Plain <b>bold</b> <span color="red">red</span>\n'
      '{c: <i>soft</i> ending}',
    );
    expect(find.text('C'), findsOneWidget);
    expect(styleOf(tester, 'bold')!.fontWeight, FontWeight.w700);
    expect(
      styleOf(tester, 'red ')?.color ?? styleOf(tester, 'red')!.color,
      parseColour('red'),
    );
    expect(styleOf(tester, 'soft')!.fontStyle, FontStyle.italic);
    // No markup characters are shown.
    expect(find.textContaining('<b>'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('font, size and colour directives apply to following lines', (
    tester,
  ) async {
    final app = await pumpSong(
      tester,
      'Normal line\n{textcolour: blue}\n{textsize: 200%}\nBig blue line\n'
      '{textcolour}\n{textsize}\nNormal again\n{chordcolour: #00ff00}\n[G]x',
    );
    final normal = styleOf(tester, 'Normal line')!;
    final big = styleOf(tester, 'Big blue line')!;
    expect(big.color, parseColour('blue'));
    expect(big.fontSize, normal.fontSize! * 2);
    expect(styleOf(tester, 'Normal again')!.fontSize, normal.fontSize);
    final chord = tester.widget<Text>(find.text('G'));
    expect(chord.style!.color, const Color(0xFF00FF00));
    await app.dispose(tester);
  });

  testWidgets('multi-line labels', (tester) async {
    final app = await pumpSong(
      tester,
      "{start_of_verse: label='Verse 1\\nAll'}\n[C]x\n{end_of_verse}",
    );
    expect(find.text('VERSE 1\nALL'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('grids are laid out in cells and transposed', (tester) async {
    final app = await pumpSong(
      tester,
      '{start_of_grid shape="1+4x2+1"}\n'
      'A || G7 . | % . | C~F . | / . || x2\n'
      '{end_of_grid}',
      transpose: 2,
    );
    expect(find.byType(GridRowView), findsOneWidget);
    expect(find.text('A7'), findsOneWidget);
    expect(find.text('D G'), findsOneWidget); // two chords in one cell
    expect(find.text('%'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('||'), findsNWidgets(2));
    await app.dispose(tester);
  });

  testWidgets('held beats in a grid show as dots (#1090)', (tester) async {
    final app = await pumpSong(
      tester,
      '{start_of_grid}\n'
      '| B . B . | E F# B . | E . F# . | G#m . G#m . |\n'
      '{end_of_grid}',
    );
    expect(find.text('.'), findsNWidgets(7));
    expect(find.text('B'), findsNWidgets(3));
    await app.dispose(tester);
  });

  test('grid columns are as wide as their content (#484)', () {
    final song = parseChordPro(
      '{start_of_grid}\n'
      '| G C . . | D Em . . |\n'
      '| Am7(4) . . . | D . . . |\n'
      '{end_of_grid}',
    );
    // One unit per character.
    double width(String text, {bool chord = false}) => text.length.toDouble();
    final formatter = ChordFormatter.forSong(song);
    final geometry = GridGeometry.of(
      song.sections.single.lines,
      formatter,
      width,
    );
    final c = geometry.columns;
    expect(c.length, 11);
    expect(c[1], 6 + GridGeometry.cellPadding); // "Am7(4)" over "G"
    expect(c[2], 1 + GridGeometry.cellPadding); // "C" over an empty cell
    expect(c[3], GridGeometry.emptyCell); // empty in both rows
    expect(c[4], GridGeometry.emptyCell);
    // Both rows are equally wide, so their bars line up.
    final rows = [
      for (final line in song.sections.single.lines)
        if (line is GridLine) line.row,
    ];
    expect(
      geometry.rowWidth(rows.first, formatter, width),
      geometry.rowWidth(rows.last, formatter, width),
    );
  });

  testWidgets('a grid wider than the page is scaled down as a whole', (
    tester,
  ) async {
    final row = List.filled(8, '| Am7(4) . . . ').join();
    final app = await pumpSong(
      tester,
      '{start_of_grid}\n$row|\n| C . . . |\n{end_of_grid}',
    );
    // No overflow, and both rows share one scale so the cells line up.
    expect(tester.takeException(), isNull);
    final rows = find.byType(GridRowView);
    expect(rows, findsNWidgets(2));
    final width = tester.getSize(find.byType(SongBody)).width;
    expect(tester.getSize(rows.first).width, lessThanOrEqualTo(width));
    final boxes = find.descendant(of: rows, matching: find.byType(FittedBox));
    expect(boxes, findsNWidgets(2));
    final firstBar = find.descendant(of: rows.first, matching: find.text('|'));
    final secondBar = find.descendant(of: rows.last, matching: find.text('|'));
    expect(
      tester.getRect(firstBar.at(1)).left,
      moreOrLessEquals(tester.getRect(secondBar.at(1)).left, epsilon: 0.5),
    );
    await app.dispose(tester);
  });

  testWidgets('chord style with raised extensions', (tester) async {
    final app = await pumpSong(
      tester,
      '[Ami7]Hello [Cmaj7]world\n'
      '{start_of_grid}\n|| Dm7b5 . | G7 . ||\n{end_of_grid}',
      style: ChordStyle.jazz,
      superscript: true,
    );
    // Root and quality as text, extension raised in its own smaller text.
    expect(styleOf(tester, 'A−'), isNotNull);
    expect(styleOf(tester, 'C'), isNotNull);
    expect(styleOf(tester, 'Dø'), isNotNull); // grid cell
    expect(find.text('Δ7'), findsOneWidget);
    expect(find.text('7'), findsNWidgets(3)); // A−7, Dø7, G7
    final raised = find.text('Δ7');
    final chord = tester.getRect(
      find.ancestor(of: raised, matching: find.byType(ChordText)),
    );
    expect(tester.getCenter(raised).dy, lessThan(chord.center.dy));
    expect(
      tester.widget<Text>(raised).style!.fontSize,
      lessThan(styleOf(tester, 'C')!.fontSize!),
    );
    await app.dispose(tester);
  });

  testWidgets('chord style without superscript is plain text', (tester) async {
    final app = await pumpSong(
      tester,
      '[Ami7]Hello [Cmaj7]world',
      style: ChordStyle.standard,
    );
    expect(find.text('Am7'), findsOneWidget);
    expect(find.text('Cmaj7'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('column breaks start new columns in live mode', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source:
            '{title: Breaks}\n[C]First column\n{column_break}\n[G]Second column\n'
            '{column_break}\n[F]Third column',
      );
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(find.text('First ').first);
    final second = tester.getRect(find.text('Second ').first);
    final third = tester.getRect(find.text('Third ').first);
    expect(second.left, greaterThan(first.right));
    expect(third.left, greaterThan(second.right));
    expect((second.top - first.top).abs(), lessThan(1));
    await app.dispose(tester);
  });

  for (final superscript in [false, true]) {
    testWidgets('layout measurement stays exact with markup and grids'
        '${superscript ? ' and raised chords' : ''}', (tester) async {
      await _checkMeasurement(tester, superscript: superscript);
    });
  }

  testWidgets('song sequence below the subtitle', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = parseChordPro(
      '{title: T}\n{subtitle: Sub}\n{x_sequence: C, V1, PC, C x2, B, Coda}',
    );
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: SongHeader(
            title: 'T',
            song: song,
            formatter: ChordFormatter.forSong(song),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sequence-chip')), findsNWidgets(6));
    for (final code in ['C', 'V1', 'PC', 'C x2', 'B', 'Coda']) {
      expect(find.text(code), findsWidgets);
    }
    // Below the subtitle.
    expect(
      tester.getTopLeft(find.text('V1')).dy,
      greaterThan(tester.getBottomLeft(find.text('Sub')).dy),
    );
    // Full names as tooltips.
    expect(find.byTooltip('Pre-chorus'), findsOneWidget);
    expect(find.byTooltip('Verse 1'), findsOneWidget);
    expect(find.byTooltip('Chorus ×2'), findsOneWidget);
    await app.dispose(tester);
  });
}

Future<void> _checkMeasurement(
  WidgetTester tester, {
  required bool superscript,
}) async {
  useTabletSize(tester);
  final app = await TestApp.create(
    prefs: {
      'language': 'en',
      'chordStyle': 'jazz',
      'chordSuperscript': superscript,
    },
  );
  final source = StringBuffer('{title: Mixed}\n{key: G}\n');
  for (var i = 0; i < 6; i++) {
    source.writeln('{start_of_verse: Verse $i}');
    source.writeln(
      '[Gmaj7]<b>Bold</b> words [Cm7b5]and <span size="150%">big</span> ones',
    );
    source.writeln('[D]more <i>lyrics</i> here [G]today');
    source.writeln('{end_of_verse}');
  }
  source.writeln(
    '{start_of_grid}\n|| G . . . | C . . . | D . . . | G . . . ||\n{end_of_grid}',
  );
  final song = await tester.runAsync(() async {
    final id = await app.songs.createSong(source: source.toString());
    return app.songs.getSong(id);
  });
  await tester.pumpWidget(
    app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
  );
  await tester.pumpAndSettle();

  expect(find.byType(SingleChildScrollView), findsNothing);
  final body = tester.getSize(find.byType(SongBody));
  final box = tester.getSize(find.byType(FittedBox));
  expect(body.height, lessThanOrEqualTo(box.height));
  expect(body.width, lessThanOrEqualTo(box.width + 0.5));
  await app.dispose(tester);
}
