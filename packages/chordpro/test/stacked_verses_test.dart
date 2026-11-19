import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

List<StackedLine> stackedLines(Section s) =>
    s.lines.whereType<StackedLine>().toList();

void main() {
  const source = '''
{title: X}
{start_of_verse: Verse 1}
[A]First [B]line of [C]one
[D]Second [E]line of [F]one
{end_of_verse}
{start_of_chorus}
[G]Chorus
{end_of_chorus}
{start_of_verse: Verse 2}
[A]First [B]line of [C]two, longer
[D]Second [E]line of [F]two
{end_of_verse}
''';

  test('stacks verses with the same chords line by line', () {
    final song = stackVerses(parseChordPro(source));
    final sections = song.sections.toList();
    expect(sections, hasLength(2));
    final block = sections[0];
    expect(block.label, 'Verse 1–2');
    final lines = stackedLines(block);
    expect(lines, hasLength(2));
    final first = lines[0];
    expect([for (final c in first.chords) c?.raw], [null, 'A', 'B', 'C']);
    expect([for (final r in first.rows) r.verse], [1, 2]);
    expect(first.rows[0].cells, ['', 'First ', 'line of ', 'one']);
    expect(first.rows[1].cells, ['', 'First ', 'line of ', 'two, longer']);
    expect(lines[1].rows[1].cells, ['', 'Second ', 'line of ', 'two']);
    // The chorus stays where it was.
    expect(sections[1].kind, SectionKind.chorus);
  });

  test('a verse without chords joins with its text in one piece', () {
    final song = stackVerses(
      parseChordPro('''
{start_of_verse: Verse 1}
[A]One [B]a
[C] [D]
[E]One b
{end_of_verse}
{start_of_verse: Verse 2}
Two a
Two b
{end_of_verse}
{start_of_verse: Verse 3}
Three a
Three b
{end_of_verse}
'''),
    );
    final block = song.sections.single;
    expect(block.label, 'Verse 1–3');
    // The line of chords only stays a single line.
    expect(block.lines[1], isA<LyricLine>());
    final lines = stackedLines(block);
    expect(lines, hasLength(2));
    expect(
      [for (final r in lines[1].rows) r.line.text],
      ['One b', 'Two b', 'Three b'],
    );
    expect(lines[1].rows[1].cells, isNull);
  });

  test('verses with other chords or lines stay on their own', () {
    final song = stackVerses(
      parseChordPro('''
{start_of_verse: Verse 1}
[A]One
{end_of_verse}
{start_of_verse: Verse 2}
[B]Two
{end_of_verse}
{start_of_verse: Verse 3}
[B]Three
{end_of_verse}
{start_of_verse: Verse 4}
[B]Four
{c: softer}
{end_of_verse}
'''),
    );
    final sections = song.sections.toList();
    expect(sections, hasLength(3));
    expect(stackedLines(sections[0]), isEmpty);
    expect(sections[1].label, 'Verse 2–3');
    expect(stackedLines(sections[1]).single.rows, hasLength(2));
    expect(sections[2].label, 'Verse 4');
  });

  test('keeps the source lines of the stacked lines and rows', () {
    final parsed = parseChordPro(source);
    final song = stackVerses(parsed);
    final before = parsed.sections.toList();
    final block = song.sections.first;
    expect(sourceLineOf(block), sourceLineOf(before[0]));
    final line = stackedLines(block).first;
    expect(sourceLineOf(line), isNull);
    expect(
      sourceLineOf(line.rows[0].line),
      sourceLineOf(before[0].lines.first),
    );
    expect(
      sourceLineOf(line.rows[1].line),
      sourceLineOf(before[2].lines.first),
    );
    expect(sourceLineOf(line.rows[1].line), isNotNull);
  });

  test('returns the song itself when nothing can be stacked', () {
    final one = parseChordPro('{sov}\n[G]Only\n{eov}\n{soc}\n[C]C\n{eoc}');
    expect(stackVerses(one), same(one));
    final plain = parseChordPro('{sov}\nA\n{eov}\n{sov}\nB\n{eov}');
    expect(stackVerses(plain), same(plain));
    final different = parseChordPro('{sov}\n[G]A\n{eov}\n{sov}\n[C]B\n{eov}');
    expect(stackVerses(different), same(different));
  });

  test('numbers rows by position when verses have no numbered labels', () {
    final song = stackVerses(
      parseChordPro('{sov}\n[G]A\n{eov}\n{sov}\n[G]B\n{eov}'),
    );
    final line = stackedLines(song.sections.single).single;
    expect([for (final r in line.rows) r.verse], [1, 2]);
    expect(song.sections.single.label, isNull);
  });
}
