import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

String styled(String chord, ChordStyle style) =>
    Chord.tryParse(chord)!.format(ChordNotation.international, style: style);

void main() {
  group('ChordSuffix.tryParse', () {
    test('normalises minor spellings', () {
      const minor7 = ChordSuffix(quality: ChordQuality.minor, extension: '7');
      for (final s in ['m7', 'min7', 'mi7', '-7', '−7']) {
        expect(ChordSuffix.tryParse(s), minor7, reason: s);
      }
    });

    test('normalises major seventh spellings', () {
      const maj7 = ChordSuffix(extension: '7', majorSeventh: true);
      for (final s in ['maj7', 'Maj7', 'M7', 'Ma7', 'Δ7', 'Δ', '△', '^7']) {
        expect(ChordSuffix.tryParse(s), maj7, reason: s);
      }
      expect(
        ChordSuffix.tryParse('maj9'),
        const ChordSuffix(extension: '9', majorSeventh: true),
      );
    });

    test('reads qualities', () {
      expect(ChordSuffix.tryParse('')!.quality, ChordQuality.major);
      expect(ChordSuffix.tryParse('M')!.quality, ChordQuality.major);
      expect(ChordSuffix.tryParse('dim')!.quality, ChordQuality.diminished);
      expect(ChordSuffix.tryParse('°7')!.extension, '7');
      expect(ChordSuffix.tryParse('aug')!.quality, ChordQuality.augmented);
      expect(ChordSuffix.tryParse('+')!.quality, ChordQuality.augmented);
      expect(ChordSuffix.tryParse('+5'), ChordSuffix.tryParse('aug'));
    });

    test('m7b5 and ø are half-diminished', () {
      const half = ChordSuffix(quality: ChordQuality.halfDiminished);
      for (final s in ['m7b5', 'm7-5', 'm7(b5)', '-7b5', 'ø', 'ø7', 'Ø7']) {
        expect(ChordSuffix.tryParse(s), half, reason: s);
      }
    });

    test('minor with major seventh', () {
      const minMaj = ChordSuffix(
        quality: ChordQuality.minor,
        extension: '7',
        majorSeventh: true,
      );
      for (final s in ['mMaj7', 'm(maj7)', 'mM7', '-Δ7', 'minmaj7']) {
        expect(ChordSuffix.tryParse(s), minMaj, reason: s);
      }
    });

    test('reads modifiers in order', () {
      expect(ChordSuffix.tryParse('7(#9,b13)')!.modifiers, ['#9', 'b13']);
      expect(ChordSuffix.tryParse('7-9+5')!.modifiers, ['b9', '#5']);
      expect(ChordSuffix.tryParse('7♭9')!.modifiers, ['b9']);
      expect(ChordSuffix.tryParse('sus')!.modifiers, ['sus4']);
      expect(ChordSuffix.tryParse('7sus2')!.modifiers, ['sus2']);
      expect(ChordSuffix.tryParse('add9')!.modifiers, ['add9']);
      expect(ChordSuffix.tryParse('(add9)')!.modifiers, ['add9']);
      expect(ChordSuffix.tryParse('7alt')!.modifiers, ['alt']);
      expect(ChordSuffix.tryParse('maj7#11')!.modifiers, ['#11']);
      expect(ChordSuffix.tryParse('69')!.extension, '6/9');
      expect(ChordSuffix.tryParse('6/9')!.extension, '6/9');
      expect(ChordSuffix.tryParse('5')!.extension, '5');
    });

    test('a major seventh after the extension', () {
      const minMaj9 = ChordSuffix(
        quality: ChordQuality.minor,
        extension: '9',
        majorSeventh: true,
      );
      for (final s in ['m9maj7', 'm9^7', 'min9maj7', '-9maj7', 'm(maj9)']) {
        expect(ChordSuffix.tryParse(s), minMaj9, reason: s);
      }
      expect(
        ChordSuffix.tryParse('m#7'),
        const ChordSuffix(
          quality: ChordQuality.minor,
          extension: '7',
          majorSeventh: true,
        ),
      );
    });

    test('ChordPro reference suffixes', () {
      expect(ChordSuffix.tryParse('711')!.modifiers, ['add11']);
      expect(ChordSuffix.tryParse('911')!.modifiers, ['add11']);
      expect(ChordSuffix.tryParse('maj911')!.modifiers, ['add11']);
      expect(ChordSuffix.tryParse('7+')!.modifiers, ['#5']);
      expect(ChordSuffix.tryParse('9+')!.modifiers, ['#5']);
      expect(ChordSuffix.tryParse('7susadd3')!.modifiers, ['sus4', 'add3']);
      expect(ChordSuffix.tryParse('no3')!.modifiers, ['no3']);
      expect(ChordSuffix.tryParse('sus9')!.modifiers, ['sus9']);
      expect(ChordSuffix.tryParse('0')!.quality, ChordQuality.diminished);
      expect(
        ChordSuffix.tryParse('h7'),
        const ChordSuffix(quality: ChordQuality.halfDiminished),
      );
      expect(ChordSuffix.tryParse('h9')!.extension, '9');
    });

    test('unknown suffixes are not parsed', () {
      for (final s in [
        'x',
        'm7(',
        'm7)',
        'maj7maj7',
        'add',
        'b3',
        'Msus',
        // `Ah`, `Eh` are words, not chords.
        'h',
        '7maj7',
        '97',
        '7maj9',
      ]) {
        expect(ChordSuffix.tryParse(s), isNull, reason: s);
      }
    });
  });

  group('Chord styles', () {
    test('Cm9maj7 is raised like Cm(maj9)', () {
      final parts = Chord.tryParse(
        'Cm9maj7',
      )!.formatParts(ChordNotation.international, style: ChordStyle.standard);
      expect(mergeChordParts(parts), const [
        ChordPart('Cm'),
        ChordPart('(maj9)', raised: true),
      ]);
      expect(styled('Cm9maj7', ChordStyle.jazz), 'C−Δ9');
    });

    test('as written keeps the suffix', () {
      expect(styled('Ami7', ChordStyle.asWritten), 'Ami7');
      expect(styled('C-7b5', ChordStyle.asWritten), 'C-7b5');
    });

    test('standard spelling', () {
      const s = ChordStyle.standard;
      expect(styled('Ami7', s), 'Am7');
      expect(styled('A-7', s), 'Am7');
      expect(styled('CΔ7', s), 'Cmaj7');
      expect(styled('CM7', s), 'Cmaj7');
      expect(styled('C°', s), 'Cdim');
      expect(styled('C°7', s), 'Cdim7');
      expect(styled('C+', s), 'Caug');
      expect(styled('Cø', s), 'Cm7b5');
      expect(styled('Cm(maj7)', s), 'Cm(maj7)');
      expect(styled('C7(#9)', s), 'C7#9');
      expect(styled('Csus', s), 'Csus4');
      expect(styled('C', s), 'C');
      expect(styled('G7/B', s), 'G7/B');
      expect(styled('Cxyz', s), 'Cxyz');
    });

    test('jazz spelling', () {
      const j = ChordStyle.jazz;
      expect(styled('Am7', j), 'A−7');
      expect(styled('Cmaj7', j), 'CΔ7');
      expect(styled('Cmaj9', j), 'CΔ9');
      expect(styled('Cdim', j), 'C°');
      expect(styled('Cdim7', j), 'C°7');
      expect(styled('Caug', j), 'C+');
      expect(styled('Cm7b5', j), 'Cø7');
      expect(styled('CmMaj7', j), 'C−Δ7');
      expect(styled('C7b9#11', j), 'C7♭9♯11');
      expect(styled('Cadd9', j), 'Cadd9');
      expect(styled('Am/G', j), 'A−/G');
    });

    test('raised parts', () {
      expect(
        Chord.tryParse(
          'Am7b5/G',
        )!.formatParts(ChordNotation.international, style: ChordStyle.jazz),
        const [
          ChordPart('A'),
          ChordPart('ø'),
          ChordPart('7', raised: true),
          ChordPart('/G'),
        ],
      );
      expect(
        Chord.tryParse('Am7')!.formatParts(ChordNotation.international),
        const [ChordPart('A'), ChordPart('m7')],
      );
    });

    test('Nashville numbers use the style', () {
      final key = Key.tryParse('C')!;
      expect(
        Chord.tryParse('Ami7')!.toNashville(key, style: ChordStyle.jazz),
        '6−7',
      );
      expect(Chord.tryParse('Dm7b5')!.toNashville(key), '2m7b5');
      expect(
        Chord.tryParse('Dm7b5')!.toNashville(key, style: ChordStyle.jazz),
        '2ø7',
      );
    });

    test('jazz spellings are recognised as chords', () {
      expect(Chord.tryParse('CΔ7'), isNotNull);
      expect(Chord.tryParse('C−7'), isNotNull);
      expect(Chord.tryParse('CØ7'), isNotNull);
      expect(Chord.tryParse('C−7')!.isMinor, isTrue);
      expect(Chord.tryParse('Cø')!.isMinor, isTrue);
      expect(Chord.tryParse('Cmaj7')!.isMinor, isFalse);
    });
  });

  test('mergeChordParts', () {
    const parts = [
      ChordPart('C'),
      ChordPart('m'),
      ChordPart('7', raised: true),
      ChordPart('b5', raised: true),
      ChordPart('/G'),
    ];
    expect(mergeChordParts(parts), const [
      ChordPart('Cm'),
      ChordPart('7b5', raised: true),
      ChordPart('/G'),
    ]);
    expect(mergeChordParts(parts, superscript: false), const [
      ChordPart('Cm7b5/G'),
    ]);
  });
}
