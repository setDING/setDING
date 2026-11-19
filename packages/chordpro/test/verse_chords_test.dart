import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

List<LyricLine> lyrics(Section s) => s.lines.whereType<LyricLine>().toList();

void main() {
  const source = '''
{title: X}
{start_of_verse: Verse 1}
[G]One [C]line
[D] [G]
{end_of_verse}
{start_of_chorus}
[C]Chorus [G]line
{end_of_chorus}
{start_of_verse: Verse 2}
[G]Two *[C]bold* line
[D] [G]
{c: Softer}
{end_of_verse}
{start_of_strophe: Strophe 3}
[G]Three
{end_of_strophe}
''';

  test('keeps the chords of the first verse and of other sections', () {
    final song = firstVerseChordsOnly(parseChordPro(source));
    final sections = song.sections.toList();
    expect(lyrics(sections[0]).every((l) => l.hasChords), isTrue);
    expect(lyrics(sections[0]), hasLength(2));
    expect(lyrics(sections[1]).single.hasChords, isTrue);
  });

  test('later verses keep their lyrics without chords', () {
    final song = firstVerseChordsOnly(parseChordPro(source));
    final verse2 = song.sections.elementAt(2);
    final line = lyrics(verse2).single;
    expect(line.hasChords, isFalse);
    expect(line.text, 'Two *bold* line');
    // The line of chords only is gone, the comment stays.
    expect(verse2.lines.whereType<CommentLine>().single.text, 'Softer');
    expect(verse2.label, 'Verse 2');
    // A section named like a verse counts too (ADR-0033).
    final verse3 = song.sections.elementAt(3);
    expect(lyrics(verse3).single.hasChords, isFalse);
    expect(lyrics(verse3).single.text, 'Three');
  });

  test('keeps the source lines of changed lines and sections', () {
    final parsed = parseChordPro(source);
    final song = firstVerseChordsOnly(parsed);
    final before = parsed.sections.elementAt(2);
    final after = song.sections.elementAt(2);
    expect(sourceLineOf(after), sourceLineOf(before));
    expect(sourceLineOf(after), isNotNull);
    expect(
      sourceLineOf(lyrics(after).single),
      sourceLineOf(lyrics(before).first),
    );
  });

  test('returns the song itself when nothing changes', () {
    final one = parseChordPro('{sov}\n[G]Only\n{eov}\n{soc}\n[C]C\n{eoc}');
    expect(firstVerseChordsOnly(one), same(one));
    final plain = parseChordPro('{sov}\n[G]A\n{eov}\n{sov}\nB\n{eov}');
    expect(firstVerseChordsOnly(plain), same(plain));
  });

  test('keeps metadata and chorus recalls', () {
    final parsed = parseChordPro('$source{chorus}\n');
    final song = firstVerseChordsOnly(parsed);
    expect(song.title, 'X');
    expect(song.elements.last, isA<ChorusRecall>());
    expect(song.elements, hasLength(parsed.elements.length));
  });
}
