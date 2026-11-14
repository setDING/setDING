import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('parses the custom directive x_sequence', () {
    final song = parseChordPro('{title: X}\n{x_sequence: C, V, C, PC, B}');
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

  test('metadata substitution with %{x_sequence}', () {
    final song = parseChordPro('{x_sequence: V, C}\n{c: Order: %{x_sequence}}');
    expect(song.sequence.map((i) => i.code), ['V', 'C']);
    final comment = song.sections.single.lines.single as CommentLine;
    expect(comment.text, 'Order: V, C');
  });

  test('{sequence} without x_ is not a BandChords directive', () {
    expect(parseChordPro('{sequence: V, C}').sequence, isEmpty);
  });

  test('no sequence', () {
    expect(parseChordPro('[C]x').sequence, isEmpty);
  });
}
