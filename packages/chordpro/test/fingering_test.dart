import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

Chord c(String name) => Chord.tryParse(name)!;

List<int> intervals(String name) => chordTones(c(name)).intervals;

String frets(String name, StringInstrument instrument) => fingeringFor(
  c(name),
  instrument,
)!.frets.map((f) => f?.toString() ?? 'x').join(' ');

void main() {
  group('chordTones', () {
    test('triads and sevenths', () {
      expect(intervals('C'), [0, 4, 7]);
      expect(intervals('Am'), [0, 3, 7]);
      expect(intervals('G7'), [0, 4, 7, 10]);
      expect(intervals('Cmaj7'), [0, 4, 7, 11]);
      expect(intervals('Em7'), [0, 3, 7, 10]);
      expect(intervals('Bdim'), [0, 3, 6]);
      expect(intervals('Bm7b5'), [0, 3, 6, 10]);
      expect(intervals('Cdim7'), [0, 3, 6, 9]);
      expect(intervals('Caug'), [0, 4, 8]);
    });

    test('suspensions, additions and extensions', () {
      expect(intervals('Dsus4'), [0, 5, 7]);
      expect(intervals('Dsus2'), [0, 2, 7]);
      expect(intervals('Fsus'), [0, 5, 7]);
      expect(intervals('Eb2'), [0, 4, 7, 14]);
      expect(intervals('F(4)'), [0, 4, 5, 7]);
      expect(intervals('Cadd9'), [0, 4, 7, 14]);
      expect(intervals('C6'), [0, 4, 7, 9]);
      expect(intervals('C9'), [0, 4, 7, 10, 14]);
      expect(intervals('G7(b9)'), [0, 4, 7, 10, 13]);
      expect(intervals('E5'), [0, 7]);
    });

    test('slash chords keep the bass note', () {
      final t = chordTones(c('D/F#'));
      expect(t.bass, 6);
      expect(t.lowest, 6);
      expect(chordTones(c('C/C')).bass, isNull);
    });
  });

  group('fingeringFor guitar', () {
    const g = StringInstrument.guitar;

    test('common open chords', () {
      expect(frets('C', g), 'x 3 2 0 1 0');
      expect(frets('G', g), '3 2 0 0 0 3');
      expect(frets('Am', g), 'x 0 2 2 1 0');
      expect(frets('E', g), '0 2 2 1 0 0');
      expect(frets('D', g), 'x x 0 2 3 2');
      expect(frets('Em', g), '0 2 2 0 0 0');
    });

    test('barre chords and slash chords are playable', () {
      for (final name in [
        'F',
        'Bb',
        'Bm',
        'F#m',
        'C#m7',
        'D/F#',
        'G/B',
        'Ebmaj7',
        'Ab',
      ]) {
        final f = fingeringFor(c(name), g);
        expect(f, isNotNull, reason: name);
        final tones = chordTones(c(name));
        final sounding = [
          for (var s = 0; s < 6; s++)
            if (f!.frets[s] != null) (g.tuning[s] + f.frets[s]!) % 12,
        ];
        expect(
          sounding.toSet().containsAll(tones.required),
          isTrue,
          reason: name,
        );
      }
      // D/F#: the F# must be the lowest note.
      final dfs = fingeringFor(c('D/F#'), g)!;
      final lowest = [
        for (var s = 0; s < 6; s++)
          if (dfs.frets[s] != null) g.tuning[s] + dfs.frets[s]!,
      ].reduce((a, b) => a < b ? a : b);
      expect(lowest % 12, 6);
    });

    test('definition relative to base fret', () {
      final def = fingeringFor(c('Bm'), g)!.toDefinition('Bm');
      expect(def.name, 'Bm');
      expect(def.frets, hasLength(6));
    });
  });

  group('fingeringFor ukulele and bass', () {
    test('ukulele open chords', () {
      expect(frets('C', StringInstrument.ukulele), '0 0 0 3');
      expect(frets('Am', StringInstrument.ukulele), '2 0 0 0');
      expect(frets('F', StringInstrument.ukulele), '2 0 1 0');
      expect(frets('G', StringInstrument.ukulele), '0 2 3 2');
    });

    test('bass plays the lowest note', () {
      final f = fingeringFor(c('G/B'), StringInstrument.bass)!;
      final notes = [
        for (var s = 0; s < 4; s++)
          if (f.frets[s] != null) StringInstrument.bass.tuning[s] + f.frets[s]!,
      ];
      expect(notes.reduce((a, b) => a < b ? a : b) % 12, 11);
    });
  });

  test('keyboard voicing', () {
    expect(keyboardVoicing(c('C')), [60, 64, 67]);
    expect(keyboardVoicing(c('Am/C')), [48, 69, 72, 76]);
  });
}
