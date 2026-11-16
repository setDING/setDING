import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/ui/songs/song_details_dialog.dart';

void main() {
  test('offers 12 major and 12 minor keys in the chosen notation', () {
    final options = keyDetailOptions('', cp.ChordNotation.german);
    expect(options, hasLength(24));
    expect(options.take(12).map((o) => o.label), [
      'C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'B', 'H', //
    ]);
    // Written to the source in international notation.
    expect(options[11].value, 'B');
    expect(options[10].value, 'Bb');
    expect(options.skip(12).first.label, 'Cm');
  });

  test('keeps the spelling of the current key', () {
    final options = keyDetailOptions('A#', cp.ChordNotation.international);
    expect(options, hasLength(24));
    expect(options.where((o) => o.value == 'A#').single.label, 'Bb');
  });

  test('offers a value that is no key first', () {
    final options = keyDetailOptions('G/D', cp.ChordNotation.international);
    expect(options.first, (value: 'G/D', label: 'G/D'));
    expect(options, hasLength(25));
  });
}
