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
}
