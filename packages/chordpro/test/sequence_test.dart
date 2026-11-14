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

  test('findSequence reads the raw value from the source', () {
    expect(
      findSequence('{title: X}\n  {x_sequence: V, C x2 }\n[C]la'),
      'V, C x2',
    );
    expect(findSequence('{title: X}'), isNull);
    expect(findSequence('{x_sequence: }'), isNull);
  });

  group('songParts', () {
    List<String> codes(String source) =>
        songParts(parseChordPro(source)).map((i) => i.code).toList();

    test('from section types, numbering repeated verses', () {
      expect(
        codes(
          '{sov}\na\n{eov}\n{soc}\nb\n{eoc}\n{sov}\nc\n{eov}\n'
          '{chorus}\n{sob}\nd\n{eob}',
        ),
        ['V1', 'C', 'V2', 'B'],
      );
    });

    test('from labels, custom sections and comment headings', () {
      expect(
        codes(
          '{start_of_verse: Intro}\na\n{end_of_verse}\n'
          '{start_of_verse: Verse 1\\nAll}\na\n{end_of_verse}\n'
          '{start_of_verse: Pre-Chorus}\na\n{end_of_verse}\n'
          '{start_of_chorus: Refrain}\na\n{end_of_chorus}\n'
          '{start_of_verse: Verse 1}\na\n{end_of_verse}\n'
          '{start_of_outro}\na\n{end_of_outro}\n'
          '{start_of_verse: Coda}\na\n{end_of_verse}\n'
          '{comment: Chorus 2}\n[C]x',
        ),
        ['I', 'V1', 'PC', 'C', 'O', 'Coda', 'C2'],
      );
    });

    test('tab and grid without label are no parts', () {
      expect(codes('{sot}\ne|--|\n{eot}\n{sog}\n| C |\n{eog}'), isEmpty);
    });
  });
}
