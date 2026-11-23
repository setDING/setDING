import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

List<String?> labels(Song song) => [
  for (final e in song.elements)
    if (e is Section) e.label else if (e is ChorusRecall) '{chorus}',
];

void main() {
  test('leaves out a chorus written out again later (SongSelect headings)', () {
    // Shaped like "10.000 Gründ": chorus, verses, the same chorus again.
    const source = '''
{title: X}

{comment: Chorus}
Lob de [C]Herr, mini [G]Seel!
Ich [C]bätte din [D]Name aa.

{comment: Vers 1}
De [C]Tag bricht [G]aa

{comment: Vers 2}
Du [C]bisch ge[G]duldig

{comment: Chorus}
Lob de [C]Herr, mini [G]Seel!
Ich [C]bätte din [D]Name aa.

{comment: Verse 3}
Und [C]wenn e[G]mal
''';
    final parsed = parseChordPro(source);
    expect(labels(parsed), ['Chorus', 'Vers 1', 'Vers 2', 'Chorus', 'Verse 3']);
    final song = withoutRepeatedChoruses(parsed);
    expect(labels(song), ['Chorus', 'Vers 1', 'Vers 2', 'Verse 3']);
    expect(song.meta['title'], ['X']);
  });

  test('leaves out directly repeated choruses with other labels', () {
    final song = withoutRepeatedChoruses(
      parseChordPro('''
{start_of_chorus: Chorus 1}
[C]Same [G]line
{end_of_chorus}
{start_of_chorus: Chorus 2}
[C]Same [G]line
{end_of_chorus}
'''),
    );
    expect(labels(song), ['Chorus 1']);
  });

  test('keeps choruses that differ in lyrics or chords', () {
    final parsed = parseChordPro('''
{start_of_chorus}
[C]Same [G]line
{end_of_chorus}
{start_of_chorus}
[C]Same [D]line
{end_of_chorus}
{start_of_chorus}
[C]Other [G]line
{end_of_chorus}
''');
    expect(identical(withoutRepeatedChoruses(parsed), parsed), isTrue);
  });

  test('keeps repeated verses and chorus recalls', () {
    final parsed = parseChordPro('''
{start_of_verse}
[C]Verse
{end_of_verse}
{start_of_chorus: Chorus}
[C]Chorus
{end_of_chorus}
{start_of_verse}
[C]Verse
{end_of_verse}
{chorus}
''');
    final song = withoutRepeatedChoruses(parsed);
    expect(identical(song, parsed), isTrue);
    expect(song.elements.whereType<ChorusRecall>(), hasLength(1));
  });

  test('compares only the choruses left by a sequence', () {
    final parsed = parseChordPro('''
{start_of_chorus: Chorus 1}
[C]Chorus
{end_of_chorus}
{start_of_verse: Verse 1}
[C]Verse
{end_of_verse}
{start_of_chorus: Chorus 2}
[C]Chorus
{end_of_chorus}
''');
    final selected = filterBySequence(parsed, parseSequence('V1, C2')).song;
    expect(labels(withoutRepeatedChoruses(selected)), ['Verse 1', 'Chorus 2']);
  });
}
