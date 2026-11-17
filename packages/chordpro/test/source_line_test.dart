import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Source lines of parsed elements, for jumping from the preview (#372).
void main() {
  test('lines and sections know their source line', () {
    final song = parseChordPro('''{title: T}
[C]First line

{start_of_chorus: Refrain}
{comment: Loud}
[G]Sing
{end_of_chorus}
{start_of_abc}
X:1
{end_of_abc}''');
    final first = song.elements[0] as Section;
    expect(sourceLineOf(first.lines.first), 1);
    final chorus = song.elements[1] as Section;
    expect(sourceLineOf(chorus), 3);
    expect(chorus.lines.map(sourceLineOf), [4, 5]);
    final abc = song.elements[2] as DelegateSection;
    expect(sourceLineOf(abc), 7);
  });

  test('lines are counted over all songs of the source', () {
    final songs = parseChordProSongs(
      '{title: A}\na\n{new_song}\n{title: B}\nb',
    );
    final b = (songs[1].elements.first as Section).lines.first;
    expect(sourceLineOf(b), 4);
  });

  test('an empty line ends an implicit section', () {
    final song = parseChordPro('a\n\nb');
    final lines = [for (final e in song.elements) ...(e as Section).lines];
    expect(lines.map(sourceLineOf), [0, 2]);
  });
}
