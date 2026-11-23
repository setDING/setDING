import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Roman numerals relative to a key (ADR-0055).
void main() {
  String numeral(String chord, String key) =>
      Chord.tryParse(chord)!.toNumeral(Key.tryParse(key)!);

  group('Roman numerals', () {
    test('case shows the quality, the minor sign is dropped', () {
      const examples = {
        'C': 'I',
        'Dm': 'ii',
        'Dm7': 'ii7',
        'Dmi7': 'ii7',
        'D-7': 'ii7',
        'Em': 'iii',
        'F': 'IV',
        'G': 'V',
        'G7': 'V7',
        'Am': 'vi',
        'Am7': 'vi7',
        'Bdim': 'vii°',
        'Bo': 'vii°',
        'Bdim7': 'vii°7',
        'Bm7b5': 'viiø7',
        'Bø': 'viiø7',
        'Bh7': 'viiø7',
        'Caug': 'I+',
        'C+': 'I+',
        'Cmaj7': 'IΔ7',
        'CM9': 'IΔ9',
        'Am(maj7)': 'viΔ7',
        'Csus4': 'Isus4',
        'C6': 'I6',
        'Cadd9': 'Iadd9',
        'G7b9': 'V7♭9',
        'G7#11': 'V7♯11',
        'G13': 'V13',
      };
      for (final MapEntry(:key, :value) in examples.entries) {
        expect(numeral(key, 'C'), value, reason: key);
      }
    });

    test('accidentals stand before the numeral', () {
      expect(numeral('Db', 'C'), '♭II');
      expect(numeral('Eb', 'C'), '♭III');
      expect(numeral('F#m7b5', 'C'), '♭vø7');
      expect(numeral('Ab', 'C'), '♭VI');
      expect(numeral('Bb', 'C'), '♭VII');
      expect(numeral('Bbm', 'C'), '♭vii');
    });

    test('secondary dominants are shown by their degree', () {
      expect(numeral('D7', 'C'), 'II7');
      expect(numeral('E7', 'C'), 'III7');
    });

    test('minor keys count from the parallel major (jazz style)', () {
      expect(numeral('Am', 'Am'), 'i');
      expect(numeral('Bm7b5', 'Am'), 'iiø7');
      expect(numeral('C', 'Am'), '♭III');
      expect(numeral('Dm7', 'Am'), 'iv7');
      expect(numeral('E7', 'Am'), 'V7');
      expect(numeral('F', 'Am'), '♭VI');
      expect(numeral('G', 'Am'), '♭VII');
    });

    test('other keys and enharmonic spellings', () {
      expect(numeral('A', 'D'), 'V');
      expect(numeral('Bm', 'D'), 'vi');
      expect(numeral('C', 'D'), '♭VII');
      expect(numeral('Gb', 'F#'), 'I');
      expect(numeral('Ebm7', 'Gb'), 'vi7');
    });

    test('slash chords keep the bass as an arabic degree', () {
      expect(numeral('C/E', 'C'), 'I/3');
      expect(numeral('G/B', 'C'), 'V/7');
      expect(numeral('D/C', 'C'), 'II/1');
      expect(numeral('C/Bb', 'C'), 'I/♭7');
      expect(numeral('Am7/G', 'C'), 'vi7/5');
    });

    test('a suffix that is not understood stays as written', () {
      final chord = Chord.tryParse('Cmxyz')!;
      expect(chord.parsedSuffix, isNull);
      expect(chord.toNumeral(Key.tryParse('C')!), 'Imxyz');
    });

    test('quality and extension are separate parts', () {
      final parts = Chord.tryParse('Bm7b5')!.toNumeralParts(Key.tryParse('C')!);
      expect(mergeChordParts(parts), [
        const ChordPart('viiø'),
        const ChordPart('7', raised: true),
      ]);
      expect(mergeChordParts(parts, superscript: false), [
        const ChordPart('viiø7'),
      ]);
    });
  });

  group('Roman numerals with chord symbol (ADR-0059)', () {
    String symbol(
      String chord,
      String key, [
      ChordStyle style = ChordStyle.standard,
    ]) => Chord.tryParse(chord)!.toNumeral(
      Key.tryParse(key)!,
      spelling: NumeralSpelling.chordSymbol,
      style: style,
    );

    test('the numeral is always upper case, the suffix in the style', () {
      const examples = {
        'C': ('I', 'I', 'I'),
        'Dm': ('IIm', 'IIm', 'II−'),
        'Dm7': ('IIm7', 'IIm7', 'II−7'),
        'Dmi7': ('IImi7', 'IIm7', 'II−7'),
        'G7': ('V7', 'V7', 'V7'),
        'Am': ('VIm', 'VIm', 'VI−'),
        'Cmaj7': ('Imaj7', 'Imaj7', 'IΔ7'),
        'Bm7b5': ('VIIm7b5', 'VIIm7b5', 'VIIø7'),
        'Bdim': ('VIIdim', 'VIIdim', 'VII°'),
        'Bdim7': ('VIIdim7', 'VIIdim7', 'VII°7'),
        'Caug': ('Iaug', 'Iaug', 'I+'),
        'Csus4': ('Isus4', 'Isus4', 'Isus4'),
        'G7b9': ('V7b9', 'V7b9', 'V7♭9'),
      };
      for (final MapEntry(:key, value: (written, standard, jazz))
          in examples.entries) {
        expect(symbol(key, 'C', ChordStyle.asWritten), written, reason: key);
        expect(symbol(key, 'C'), standard, reason: key);
        expect(symbol(key, 'C', ChordStyle.jazz), jazz, reason: key);
      }
    });

    test('ii-V-I as in jazz charts', () {
      expect(
        ['Dm7', 'G7', 'Cmaj7'].map((c) => symbol(c, 'C')).join(' – '),
        'IIm7 – V7 – Imaj7',
      );
    });

    test('accidentals and minor keys as with the case spelling', () {
      expect(symbol('Am', 'Am'), 'Im');
      expect(symbol('Bm7b5', 'Am'), 'IIm7b5');
      expect(symbol('C', 'Am'), '♭III');
      expect(symbol('F', 'Am'), '♭VI');
      expect(symbol('G', 'Am'), '♭VII');
      expect(symbol('F#m7b5', 'C'), '♭Vm7b5');
      expect(symbol('Bbm', 'C'), '♭VIIm');
    });

    test('slash chords keep the bass as an arabic degree', () {
      expect(symbol('Dm7/C', 'C'), 'IIm7/1');
      expect(symbol('C/Bb', 'C'), 'I/♭7');
      expect(symbol('Am7/G', 'C', ChordStyle.jazz), 'VI−7/5');
    });

    test('a suffix that is not understood stays as written', () {
      expect(symbol('Cmxyz', 'C'), 'Imxyz');
    });

    test('the extension is a raised part in Standard and Jazz', () {
      final parts = Chord.tryParse('Dm7')!.toNumeralParts(
        Key.tryParse('C')!,
        spelling: NumeralSpelling.chordSymbol,
        style: ChordStyle.jazz,
      );
      expect(mergeChordParts(parts), [
        const ChordPart('II−'),
        const ChordPart('7', raised: true),
      ]);
    });

    test('the case spelling ignores the chord style', () {
      for (final style in ChordStyle.values) {
        expect(
          Chord.tryParse('Dm7')!.toNumeral(Key.tryParse('C')!, style: style),
          'ii7',
        );
      }
    });
  });
}
