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

  test('{sequence} without x_ is not a setDING directive', () {
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

  group('filterBySequence', () {
    const source =
        '{c: Capo 2}\n'
        '{start_of_verse: Intro}\na\n{end_of_verse}\n'
        '{sov}\nv1\n{eov}\n'
        '{soc}\nc\n{eoc}\n'
        '{sov}\nv2\n{eov}\n'
        '{chorus}\n'
        '{sov}\nv3\n{eov}\n'
        '{sob}\nb\n{eob}\n'
        '{start_of_verse: Coda}\nx\n{end_of_verse}\n'
        '{sot}\ne|--|\n{eot}';

    List<String> shown(SequenceSelection s) => [
      for (final e in s.song.elements)
        switch (e) {
          Section(lines: [LyricLine l, ...]) => l.text,
          Section(lines: [CommentLine c, ...]) => c.text,
          Section(lines: [RawLine r, ...]) => r.text,
          ChorusRecall() => 'recall',
          _ => '?',
        },
    ];

    test('keeps only the parts of the sequence, in document order', () {
      final s = filterBySequence(
        parseChordPro(source),
        parseSequence('V1, C x2, V2, C, Coda'),
      );
      expect(shown(s), ['Capo 2', 'v1', 'c', 'v2', 'recall', 'x', 'e|--|']);
      expect(s.hidden, ['I', 'V3', 'B']);
    });

    test('a part without number matches all its numbers', () {
      final s = filterBySequence(parseChordPro(source), parseSequence('V'));
      expect(shown(s), ['Capo 2', 'v1', 'v2', 'v3', 'e|--|']);
      expect(s.hidden, ['I', 'C', 'B', 'Coda']);
    });

    test('unchanged without sequence or without any matching part', () {
      final song = parseChordPro(source);
      for (final sequence in ['', 'Foo, Bar', 'V1, V2, C, I, V3, B, Coda']) {
        final s = filterBySequence(song, parseSequence(sequence));
        expect(s.song, same(song), reason: sequence);
        expect(s.hidden, isEmpty, reason: sequence);
      }
    });

    test('keeps the meta data', () {
      final song = parseChordPro('{title: T}\n{key: G}\n$source');
      final s = filterBySequence(song, parseSequence('C'));
      expect(s.song.title, 'T');
      expect(s.song.keyName, 'G');
    });

    group('keepOutside', () {
      List<String> outsideTexts(SequenceSelection s) => [
        for (final e in s.song.elements)
          if (e is Section && s.isOutside(e))
            switch (e.lines) {
              [LyricLine l, ...] => l.text,
              _ => '?',
            },
      ];

      test('keeps the whole song and marks the parts outside', () {
        final song = parseChordPro(source);
        final s = filterBySequence(
          song,
          parseSequence('V1, C x2, V2, C, Coda'),
          keepOutside: true,
        );
        expect(s.song, same(song));
        expect(s.hidden, isEmpty);
        expect(s.outside, ['I', 'V3', 'B']);
        expect(outsideTexts(s), ['a', 'v3', 'b']);
      });

      test('marks copies of a section outside, too', () {
        final song = parseChordPro(
          '{sov}\n[G]v1\n{eov}\n{sov}\n[G]v2\n{eov}\n{sov}\n[G]v3\n{eov}',
        );
        final s = filterBySequence(
          song,
          parseSequence('V1, V2'),
          keepOutside: true,
        );
        // Later verses become copies without chords (#518).
        final copied = firstVerseChordsOnly(s.song);
        expect(copied.sections.last, isNot(same(song.sections.last)));
        expect(
          [for (final e in copied.sections) s.isOutside(e)],
          [false, false, true],
        );
      });

      test('nothing outside without sequence or matching part', () {
        final song = parseChordPro(source);
        for (final sequence in ['', 'Foo', 'V1, V2, C, I, V3, B, Coda']) {
          final s = filterBySequence(
            song,
            parseSequence(sequence),
            keepOutside: true,
          );
          expect(s.song, same(song), reason: sequence);
          expect(s.outside, isEmpty, reason: sequence);
          expect(song.sections.any(s.isOutside), isFalse, reason: sequence);
        }
      });
    });
  });
}
