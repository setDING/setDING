import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  final song = parseChordPro(
    '{key: C}\n[C]a [Am]b [F]c [G7/B]d [N.C.]e [*Riff]f',
  );
  List<String> chords(ChordFormatter f) =>
      (song.sections.first.lines.first as LyricLine).segments
          .map((s) => f.format(s.chord!))
          .toList();

  test('no changes keeps raw chords', () {
    expect(chords(ChordFormatter.forSong(song)), [
      'C',
      'Am',
      'F',
      'G7/B',
      'N.C.',
      'Riff',
    ]);
  });

  test('transposes into a sharp key', () {
    final f = ChordFormatter.forSong(song, transpose: 2);
    expect(chords(f), ['D', 'Bm', 'G', 'A7/C#', 'N.C.', 'Riff']);
    expect(f.formatKey(), 'D');
  });

  test('transposes into a flat key', () {
    final f = ChordFormatter.forSong(song, transpose: -2);
    expect(chords(f), ['Bb', 'Gm', 'Eb', 'F7/A', 'N.C.', 'Riff']);
    expect(f.formatKey(), 'Bb');
  });

  test('capo shows shapes, key stays sounding', () {
    final f = ChordFormatter.forSong(song, transpose: 2, capo: 2);
    expect(chords(f).take(4), ['C', 'Am', 'F', 'G7/B']);
    expect(f.formatKey(), 'D');
  });

  test('German notation', () {
    final f = ChordFormatter.forSong(
      song,
      transpose: -2,
      notation: ChordNotation.german,
    );
    expect(chords(f).first, 'B');
    expect(
      chords(ChordFormatter.forSong(song, notation: ChordNotation.german))[3],
      'G7/H',
    );
  });

  test('Nashville numbers ignore transposition', () {
    final f = ChordFormatter.forSong(song, transpose: 5, nashville: true);
    expect(chords(f), ['1', '6m', '4', '57/7', 'N.C.', 'Riff']);
  });

  test('Nashville without key falls back to chord names', () {
    final noKey = parseChordPro('[C]a');
    final f = ChordFormatter.forSong(noKey, nashville: true);
    expect(f.showsNashville, isFalse);
    expect(
      f.format(
        (noKey.sections.first.lines.first as LyricLine).segments.first.chord!,
      ),
      'C',
    );
  });

  test('convertGermanToInternational', () {
    const german = '{key: H}\n[H]Ein [B]Lied [Hm7/Fis]x [Es]y\n';
    final converted = convertGermanToInternational(german);
    expect(converted, contains('{key: B}'));
    expect(converted, contains('[B]Ein [Bb]Lied'));
    // German note names in the bass are understood too (Fis = F#).
    expect(converted, contains('[Bm7/F#]x'));
    expect(converted, contains('[Eb]y')); // Es = E flat
  });
}
