import 'package:realchord/ui/widgets/key_picker.dart';
import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes to the shortest transposition', () {
    expect(normalizeSemitones(0), 0);
    expect(normalizeSemitones(7), -5);
    expect(normalizeSemitones(-7), 5);
    expect(normalizeSemitones(6), 6);
    expect(normalizeSemitones(-6), 6);
    expect(normalizeSemitones(11), -1);
  });

  test('offers twelve keys in chromatic order from C', () {
    final options = keyOptions(
      cp.Key.tryParse('G'),
      cp.ChordNotation.international,
    );
    expect(options.map((o) => o.label), [
      'C',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ]);
    expect(options.firstWhere((o) => o.isOriginal).label, 'G');
    expect(options.firstWhere((o) => o.label == 'A').semitones, 2);
    expect(options.firstWhere((o) => o.label == 'C').semitones, 5);
    expect(options.firstWhere((o) => o.label == 'D').semitones, -5);
  });

  test('uses the chosen notation and minor keys', () {
    final options = keyOptions(cp.Key.tryParse('Am'), cp.ChordNotation.german);
    expect(options.map((o) => o.label), contains('Hm'));
    expect(options.map((o) => o.label), contains('Bm'));
    expect(options.firstWhere((o) => o.isOriginal).label, 'Am');
  });

  test('without a key offers semitone offsets', () {
    final options = keyOptions(null, cp.ChordNotation.international);
    expect(options.first.label, '−5');
    expect(options.last.label, '+6');
    expect(options.firstWhere((o) => o.isOriginal).label, '0');
  });
}
