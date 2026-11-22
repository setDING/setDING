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
    expect(f.formatShapeKey(), 'C');
  });

  test('shape key follows the song capo and a personal capo', () {
    final withCapo = parseChordPro('{key: A}\n{capo: 3}\n[A]a');
    final asWritten = ChordFormatter.forSong(withCapo);
    expect(asWritten.formatShapeKey(), 'A');
    expect(asWritten.formatKey(), 'C');
    final personal = ChordFormatter.forSong(song, capo: 3);
    expect(personal.formatShapeKey(), 'A');
    expect(personal.formatKey(), 'C');
    expect(ChordFormatter.forSong(song).formatShapeKey(), 'C');
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
    final f = ChordFormatter.forSong(
      song,
      transpose: 5,
      view: ChordView.nashville,
    );
    expect(chords(f), ['1', '6m', '4', '57/7', 'N.C.', 'Riff']);
  });

  test('Roman numerals ignore transposition and the chord style', () {
    for (final style in ChordStyle.values) {
      final f = ChordFormatter.forSong(
        song,
        transpose: 5,
        view: ChordView.numerals,
        style: style,
        notation: ChordNotation.german,
      );
      expect(chords(f), ['I', 'vi', 'IV', 'V7/7', 'N.C.', 'Riff']);
    }
  });

  test('Roman numerals raise the extension with superscript', () {
    final f = ChordFormatter.forSong(
      parseChordPro('{key: C}\n[Bm7b5]a [G7b9]b'),
      view: ChordView.numerals,
      superscript: true,
    );
    expect(f.format(ChordToken('Bm7b5')), 'viiø7');
    expect(f.formatParts(ChordToken('G7b9')), [
      const ChordPart('V'),
      const ChordPart('7♭9', raised: true),
    ]);
    expect(f.formatParts(ChordToken('Bm7b5')), [
      const ChordPart('viiø'),
      const ChordPart('7', raised: true),
    ]);
  });

  test('Roman numerals without key fall back to chord names', () {
    final noKey = parseChordPro('[Am]a');
    final f = ChordFormatter.forSong(noKey, view: ChordView.numerals);
    expect(f.showsDegrees, isFalse);
    expect(
      f.format(
        (noKey.sections.first.lines.first as LyricLine).segments.first.chord!,
      ),
      'Am',
    );
  });

  test('Nashville without key falls back to chord names', () {
    final noKey = parseChordPro('[C]a');
    final f = ChordFormatter.forSong(noKey, view: ChordView.nashville);
    expect(f.showsDegrees, isFalse);
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

  group('chord style', () {
    final styledSong = parseChordPro(
      '{key: C}\n[Ami7]a [CΔ7]b [(Dm7b5)]c [N.C.]d [*Riff]e',
    );
    List<List<ChordPart>> parts(ChordFormatter f) =>
        (styledSong.sections.first.lines.first as LyricLine).segments
            .map((s) => f.formatParts(s.chord!))
            .toList();

    test('as written keeps the raw chords', () {
      expect(parts(ChordFormatter.forSong(styledSong)).map(chordPartsText), [
        'Ami7',
        'CΔ7',
        '(Dm7b5)',
        'N.C.',
        'Riff',
      ]);
    });

    test('standard and jazz styles', () {
      final standard = ChordFormatter.forSong(
        styledSong,
        style: ChordStyle.standard,
      );
      expect(parts(standard).map(chordPartsText), [
        'Am7',
        'Cmaj7',
        '(Dm7b5)',
        'N.C.',
        'Riff',
      ]);
      final jazz = ChordFormatter.forSong(
        styledSong,
        style: ChordStyle.jazz,
        transpose: 2,
      );
      expect(parts(jazz).map(chordPartsText), [
        'B−7',
        'DΔ7',
        '(Eø7)',
        'N.C.',
        'Riff',
      ]);
    });

    test('superscript returns raised parts', () {
      final f = ChordFormatter.forSong(
        styledSong,
        style: ChordStyle.jazz,
        superscript: true,
      );
      expect(parts(f).take(3), [
        [const ChordPart('A−'), const ChordPart('7', raised: true)],
        [const ChordPart('C'), const ChordPart('Δ7', raised: true)],
        [
          const ChordPart('(Dø'),
          const ChordPart('7', raised: true),
          const ChordPart(')'),
        ],
      ]);
      // Without a style, superscript has no effect.
      final plain = ChordFormatter.forSong(styledSong, superscript: true);
      expect(parts(plain).first, [const ChordPart('Ami7')]);
    });

    test('Nashville numbers with style', () {
      final f = ChordFormatter.forSong(
        styledSong,
        view: ChordView.nashville,
        style: ChordStyle.jazz,
      );
      expect(parts(f).take(3).map(chordPartsText), ['6−7', '1Δ7', '(2ø7)']);
    });

    test('chord names for diagrams use the style', () {
      final f = ChordFormatter.forSong(styledSong, style: ChordStyle.jazz);
      expect(f.chordName(Chord.tryParse('Am7')!), 'A−7');
    });
  });
}
