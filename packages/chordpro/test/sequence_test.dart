import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('parses the sequence directive', () {
    final song = parseChordPro('{title: X}\n{sequence: C, V, C, PC, B}');
    expect(song.sequence.map((i) => i.code), ['C', 'V', 'C', 'PC', 'B']);
    expect(song.sequence.map((i) => i.part), [
      SequencePart.chorus,
      SequencePart.verse,
      SequencePart.chorus,
      SequencePart.preChorus,
      SequencePart.bridge,
    ]);
  });

  test('numbers, repeats and long or German names', () {
    final items = parseSequence(
      'I, V1, C x2, 2x R, Ref (3x), Strophe 2, Zw, Solo, O; Coda',
    );
    expect(items.map((i) => (i.part, i.number, i.repeat)), [
      (SequencePart.intro, null, null),
      (SequencePart.verse, 1, null),
      (SequencePart.chorus, null, 2),
      (SequencePart.chorus, null, 2),
      (SequencePart.chorus, null, 3),
      (SequencePart.verse, 2, null),
      (SequencePart.interlude, null, null),
      (SequencePart.solo, null, null),
      (SequencePart.outro, null, null),
      (SequencePart.other, null, null),
    ]);
    expect(items.last.code, 'Coda');
  });

  test('portable form x_sequence and metadata substitution', () {
    final song = parseChordPro('{x_sequence: V, C}\n{c: Order: %{sequence}}');
    expect(song.sequence.map((i) => i.code), ['V', 'C']);
    final comment = song.sections.single.lines.single as CommentLine;
    expect(comment.text, 'Order: V, C');
  });

  test('no sequence', () {
    expect(parseChordPro('[C]x').sequence, isEmpty);
  });
}
