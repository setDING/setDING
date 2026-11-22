import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// A key suggested from the chords (#919, ADR-0056).
void main() {
  KeyGuess? guess(String body) => guessKey(parseChordPro('{title: T}\n$body'));
  Key key(String name) => Key.tryParse(name)!;

  test('a plain pop song in G', () {
    final g = guess('[G]One [D]two [Em]three [C]four\n[G]Five [D]six [G]end');
    expect(g?.key, key('G'));
  });

  test('a minor song with the major dominant', () {
    final g = guess(
      '[Am]One [Dm]two [E7]three [Am]four\n[F]Five [E]six [Am]end',
    );
    expect(g?.key, key('Am'));
  });

  test('relative major and minor: the first and last chord decide', () {
    final major = guess('[C]La [Am]la [F]la [G]la [C]la');
    expect(major?.key, key('C'));
    final minor = guess('[Am]La [F]la [C]la [G]la [Am]la');
    expect(minor?.key, key('Am'));
    // The relative key is offered as the alternative.
    expect(minor?.alternative, key('C'));
  });

  test('a clear key has no alternative', () {
    final g = guess(
      '[D]La [G]la [A7]la [D]la\n[Bm]La [G]la [A]la [D]la\n[G]La [A]la [D]la',
    );
    expect(g, KeyGuess(key('D')));
  });

  test('a Mixolydian song starting and ending on its tonic', () {
    final g = guess('[G]La [F]la [C]la [G]la\n[G]La [F]la [C]la [G]la');
    expect(g?.key, key('G'));
    expect(g?.alternative, key('C'));
  });

  test('two different chords are too few', () {
    expect(guess('[G]La [D]la [G]la [D]la [G]la'), isNull);
    expect(guess('Just words'), isNull);
  });

  test('no guess when {key} is at the top', () {
    expect(guess('{key: G}\n[G]La [C]la [D]la [G]la'), isNull);
  });

  test('only chords before the first {key} count', () {
    final g = guess('[A]La [D]la [E]la [A]la\n{key: Bb}\n[Bb]La [Eb]la [F]la');
    expect(g?.key, key('A'));
    // Before the key change there are too few chords.
    expect(guess('[A]La [E]la\n{key: Bb}\n[Bb]La [Eb]la [F]la'), isNull);
  });

  test('grids, slash chords and seventh chords count', () {
    final g = guess(
      '{start_of_grid}\n| E . . . | A/E . . . | B7 . . . | E . . . |\n'
      '{end_of_grid}',
    );
    expect(g?.key, key('E'));
  });

  test('annotations, N.C. and Nashville numbers are skipped', () {
    final g = guess('[*Riff][N.C.][1][4]\n[F]La [Bb]la [C7]la [F]la');
    expect(g?.key, key('F'));
  });

  test('the key is spelled as usual for its tonic', () {
    final g = guess('[Gb]La [Cb]la [Db]la [Gb]la');
    expect(g?.key.format(ChordNotation.international), 'F#');
    final flat = guess('[A#]La [D#]la [F]la [A#]la');
    expect(flat?.key.format(ChordNotation.international), 'Bb');
  });

  test('diminished chords fit as the leading-tone chord', () {
    final g = guess('[C]La [Bdim]la [C]la [F]la [Bm7b5]la [C]la');
    expect(g?.key, key('C'));
  });

  test('the feature showcase has a key, so there is no guess', () {
    final source = File(
      '../../docs/examples/feature-showcase.cho',
    ).readAsStringSync();
    expect(guessKey(parseChordPro(source)), isNull);
  });
}
