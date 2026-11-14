import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('Chord.tryParse', () {
    test('parses simple chords', () {
      final c = Chord.tryParse('C')!;
      expect(c.root.pitch, 0);
      expect(c.suffix, '');
      expect(c.bass, isNull);
    });

    test('parses accidentals, suffix and bass', () {
      final c = Chord.tryParse('F#m7/C#')!;
      expect(c.root.pitch, 6);
      expect(c.suffix, 'm7');
      expect(c.bass!.pitch, 1);
      expect(c.isMinor, isTrue);
    });

    test('parses flats', () {
      final c = Chord.tryParse('Bbmaj7')!;
      expect(c.root.pitch, 10);
      expect(c.root.preferFlat, isTrue);
      expect(c.isMinor, isFalse);
    });

    test('accepts H as B', () {
      expect(Chord.tryParse('H7')!.root.pitch, 11);
    });

    test('German input: B is B flat, H is B', () {
      expect(Chord.tryParse('B', germanInput: true)!.root.pitch, 10);
      expect(Chord.tryParse('H', germanInput: true)!.root.pitch, 11);
    });

    test('rejects non-chords', () {
      expect(Chord.tryParse('N.C.'), isNull);
      expect(Chord.tryParse('x'), isNull);
      expect(Chord.tryParse(''), isNull);
      expect(Chord.tryParse('Hello world'), isNull);
    });

    test('keeps complex suffixes', () {
      expect(Chord.tryParse('Csus4')!.suffix, 'sus4');
      expect(Chord.tryParse('G7(b9)')!.suffix, '7(b9)');
      expect(Chord.tryParse('Dadd9')!.suffix, 'add9');
    });
  });

  group('transpose and format', () {
    test('transposes up with sharps', () {
      expect(
        Chord.tryParse('C')!.transpose(2).format(ChordNotation.international),
        'D',
      );
      expect(
        Chord.tryParse(
          'A',
        )!.transpose(1, useFlats: false).format(ChordNotation.international),
        'A#',
      );
    });

    test('transposes down with flats', () {
      expect(
        Chord.tryParse(
          'C/E',
        )!.transpose(-2, useFlats: true).format(ChordNotation.international),
        'Bb/D',
      );
    });

    test('wraps around the octave', () {
      expect(
        Chord.tryParse('B')!.transpose(1).format(ChordNotation.international),
        'C',
      );
      expect(
        Chord.tryParse('C')!.transpose(-1).format(ChordNotation.international),
        'B',
      );
    });

    test('German notation output', () {
      expect(Chord.tryParse('B')!.format(ChordNotation.german), 'H');
      expect(Chord.tryParse('Bb')!.format(ChordNotation.german), 'B');
      expect(Chord.tryParse('Bbm7/F')!.format(ChordNotation.german), 'Bm7/F');
      expect(Chord.tryParse('G/B')!.format(ChordNotation.german), 'G/H');
    });
  });

  group('Nashville', () {
    final c = Key.tryParse('C')!;
    final g = Key.tryParse('G')!;

    test('degrees in C', () {
      expect(Chord.tryParse('C')!.toNashville(c), '1');
      expect(Chord.tryParse('F')!.toNashville(c), '4');
      expect(Chord.tryParse('G7')!.toNashville(c), '57');
      expect(Chord.tryParse('Am')!.toNashville(c), '6m');
      expect(Chord.tryParse('Bb')!.toNashville(c), 'b7');
      expect(Chord.tryParse('C/E')!.toNashville(c), '1/3');
    });

    test('degrees in G', () {
      expect(Chord.tryParse('D')!.toNashville(g), '5');
      expect(Chord.tryParse('Em')!.toNashville(g), '6m');
    });
  });

  group('Key', () {
    test('parses and detects minor', () {
      final k = Key.tryParse('Em')!;
      expect(k.tonic.pitch, 4);
      expect(k.minor, isTrue);
    });

    test('flat keys', () {
      expect(Key.tryParse('F')!.usesFlats, isTrue);
      expect(Key.tryParse('G')!.usesFlats, isFalse);
      expect(Key.tryParse('Dm')!.usesFlats, isTrue);
    });

    test('transposed key is spelled conventionally', () {
      expect(Key.tryParse('G')!.transpose(3).toString(), 'Bb');
      expect(Key.tryParse('C')!.transpose(6).toString(), 'F#');
    });
  });
}
