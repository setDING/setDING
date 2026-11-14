import 'package:bandchords/ui/live/live_screen.dart';
import 'package:bandchords/ui/render/song_grid.dart';
import 'package:bandchords/ui/render/song_header.dart';
import 'package:bandchords/ui/render/song_view.dart';
import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Renders [source] with [SongBody] inside the app (theme, localization).
Future<TestApp> pumpSong(
  WidgetTester tester,
  String source, {
  int transpose = 0,
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
              formatter: ChordFormatter.forSong(song, transpose: transpose),
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

  testWidgets('layout measurement stays exact with markup and grids', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final source = StringBuffer('{title: Mixed}\n{key: G}\n');
    for (var i = 0; i < 6; i++) {
      source.writeln('{start_of_verse: Verse $i}');
      source.writeln(
        '[G]<b>Bold</b> words [C]and <span size="150%">big</span> ones',
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
  });

  testWidgets('song sequence below the subtitle', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = parseChordPro(
      '{title: T}\n{subtitle: Sub}\n{sequence: C, V1, PC, C x2, B, Coda}',
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
