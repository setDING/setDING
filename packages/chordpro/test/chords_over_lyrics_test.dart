import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('merges a chord line into the lyrics line below', () {
    expect(
      convertChordsOverLyrics('C        G\nHello my friend'),
      '[C]Hello my [G]friend',
    );
  });

  test('pads lyrics that are shorter than the chord line', () {
    expect(
      convertChordsOverLyrics('Am    F       G\nOh yeah'),
      '[Am]Oh yea[F]h       [G]',
    );
  });

  test('keeps a chord line without lyrics, with its spacing', () {
    expect(
      convertChordsOverLyrics('C  G  Am  F\n\nla'),
      '[C]  [G]  [Am]  [F]\n\nla',
    );
  });

  test('bar lines and repeat marks', () {
    expect(
      convertChordsOverLyrics('| C | G | x2'),
      '[|] [C] [|] [G] [|] [*x2]',
    );
  });

  test('section headers in brackets become comments', () {
    expect(
      convertChordsOverLyrics('[Verse 1]\nD\nSing\n\n[Chorus]:\n[Am]'),
      '{comment: Verse 1}\n[D]Sing\n\n{comment: Chorus}\n[Am]',
    );
  });

  test('ChordPro and plain lyrics stay as they are', () {
    const source = '{title: T}\n# C G\n[C]Hello\njust words\n';
    expect(convertChordsOverLyrics(source), source);
  });

  test('two chord lines: only the second is merged', () {
    expect(
      convertChordsOverLyrics('C G\nAm   F\nWords here'),
      '[C] [G]\n[Am]Words[F] here',
    );
  });

  test('optional chords and slash chords', () {
    expect(convertChordsOverLyrics('(C)  G/B\nAh   oh'), '[(C)]Ah   [G/B]oh');
  });

  group('isChordLine', () {
    test('accepts chord lines', () {
      expect(isChordLine('  Am7  Dsus4 F#m/C# '), isTrue);
      expect(isChordLine('N.C.  C'), isTrue);
    });

    test('rejects lyrics and directives', () {
      expect(isChordLine('A man walks in'), isFalse);
      expect(isChordLine('{c: C G}'), isFalse);
      expect(isChordLine('| |'), isFalse);
      expect(isChordLine('Chorus'), isFalse);
      expect(isChordLine('Dad Go Fine'), isFalse);
      expect(isChordLine(''), isFalse);
    });
  });

  test('looksLikeChordsOverLyrics', () {
    expect(looksLikeChordsOverLyrics('C G\nHello'), isTrue);
    expect(looksLikeChordsOverLyrics('[C]Hello\nC G'), isFalse);
    expect(looksLikeChordsOverLyrics('C G\n\nHello'), isFalse);
  });
}
