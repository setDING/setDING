import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

const _instrumental = '''{comment: Instrumental}
[||:][G/B]  [C2]  [.]  [.][|][D(4)]  [Em7]  [.]  [.][|][G/B]  [C2]  [.]  [.][|][D(4)]  [Em7]  [.]  [.][|]
[|]   [G/B]  [C2]  [.]  [.][|][D(4)]  [Em7]  [.]  [.][|][Am7(4)]          [|][D7sus]               [:||]''';

void main() {
  test('converts a CCLI instrumental to a grid section', () {
    expect(
      convertCcliGrids(_instrumental),
      '''{start_of_grid shape="4x4" label="Instrumental"}
|: G/B C2 . . | D(4) Em7 . . | G/B C2 . . | D(4) Em7 . . |
| G/B C2 . . | D(4) Em7 . . | Am7(4) . . . | D7sus . . . :|
{end_of_grid}''',
    );
  });

  test('converts a single line with plain bars', () {
    const source = '''{comment: Turnaround}
[|][G/B]  [C2]  [.]  [.][|][D(4)]  [Em7]  [.]  [.][|]

{comment: Verse 1}
[G]Words''';
    expect(
      convertCcliGrids(source),
      '''{start_of_grid shape="2x4" label="Turnaround"}
| G/B C2 . . | D(4) Em7 . . |
{end_of_grid}

{comment: Verse 1}
[G]Words''',
    );
  });

  test('the grid parses with its label, bars and chords', () {
    final song = parseChordPro(convertCcliGrids(_instrumental));
    final section = song.sections.single;
    expect(section.kind, SectionKind.grid);
    expect(section.label, 'Instrumental');
    final row = (section.lines.first as GridLine).row;
    expect((row.tokens.first as GridBar).symbol, '|:');
    expect((row.tokens[1] as GridChords).chords.single.raw, 'G/B');
  });

  test('spreads chords that divide the measure, pads others', () {
    expect(
      convertCcliGrids('[|][C] [G] [|][Am] [F] [G] [Em][|][D][|]'),
      '''{start_of_grid shape="3x4"}
| C . G . | Am F G Em | D . . . |
{end_of_grid}''',
    );
    expect(
      convertCcliGrids('[|][C] [D] [E] [F] [G] [A][|][C] [D] [E] [F][|]'),
      '''{start_of_grid shape="2x6"}
| C D E F G A | C D E F . . |
{end_of_grid}''',
    );
  });

  test('keeps the comment when lyrics follow in the same part', () {
    const source = '''{comment: Intro}
[|][Eb] [.] [.] [Gm] [|] [Fsus] [|]
[Eb]Lyrics here''';
    expect(convertCcliGrids(source), '''{comment: Intro}
{start_of_grid shape="2x4"}
| Eb . . Gm | Fsus . . . |
{end_of_grid}
[Eb]Lyrics here''');
  });

  test('adds missing bars at the start and end of a line', () {
    expect(
      convertCcliGrids('[C] [G][|][F]'),
      '{start_of_grid shape="2x2"}\n| C G | F . |\n{end_of_grid}',
    );
  });

  test('maps CCLI repeat and double bars', () {
    expect(
      convertCcliGrids('[||][C][:||:][G][||.]'),
      '{start_of_grid shape="2x1"}\n|| C :|: G |.\n{end_of_grid}',
    );
  });

  test('ignores lyrics, chord-only lines and environments', () {
    const source = '''[C]Hello [|] world
[C]  [G]  [Am]
{start_of_verse}
[|][C][|]
{end_of_verse}
{start_of_grid}
| C . |
{end_of_grid}''';
    expect(findCcliGrids(source), isEmpty);
    expect(convertCcliGrids(source), source);
  });

  test('finds blocks with line numbers and keeps CRLF line breaks', () {
    const source = '{c: Intro}\r\n[|][C][|]\r\n\r\n[|][G][|]';
    final grids = findCcliGrids(source);
    expect([for (final g in grids) g.line], [2, 4]);
    expect(grids.first.start, 0);
    expect(grids.first.linesStart, 12);
    expect(
      convertCcliGrids(source),
      '{start_of_grid shape="1x1" label="Intro"}\r\n| C |\r\n{end_of_grid}'
      '\r\n\r\n{start_of_grid shape="1x1"}\r\n| G |\r\n{end_of_grid}',
    );
  });

  group('convertCcliGridsIn', () {
    const source = '{c: A}\n[|][C][|]\n\n{c: B}\n[|][G][|]';

    test('converts all blocks without a selection', () {
      final edit = convertCcliGridsIn(source, 0, 0)!;
      expect(findCcliGrids(edit.text), isEmpty);
      expect(edit.text, contains('label="A"'));
      expect(edit.text, contains('label="B"'));
    });

    test('converts only the selected block and selects it', () {
      final at = source.indexOf('[G]');
      final edit = convertCcliGridsIn(source, at, at + 3)!;
      expect(edit.text, startsWith('{c: A}\n[|][C][|]\n\n{start_of_grid'));
      expect(
        edit.text.substring(edit.base, edit.extent),
        '{start_of_grid shape="1x1" label="B"}\n| G |\n{end_of_grid}',
      );
    });

    test('returns null when there is nothing to convert', () {
      expect(convertCcliGridsIn('[C]Hello', 0, 0), isNull);
    });
  });
}
