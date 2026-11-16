import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

typedef P = ChordProProblemKind;

List<(P, int, String)> problems(String source) => [
  for (final p in validateChordPro(source))
    (p.kind, p.line, source.substring(p.start, p.end)),
];

void main() {
  test('a valid song has no problems', () {
    expect(
      problems('{title: T}\n[G]la [C]li\n{start_of_abc}\nX:1\n{end_of_abc}'),
      isEmpty,
    );
    expect(problems(''), isEmpty);
  });

  test('unclosed brackets', () {
    expect(problems('{title: T\n[G]la [Am li\n{c: ok}'), [
      (P.unclosedDirective, 1, '{title: T'),
      (P.unclosedChord, 2, '[Am li'),
    ]);
  });

  test('an unclosed delegated environment', () {
    expect(problems('[G]la\n  {start_of_svg}  \n<svg/>\n[C]li'), [
      (P.unclosedEnvironment, 2, '{start_of_svg}'),
    ]);
    // Brackets inside the environment are not checked.
    expect(problems('{start_of_abc}\n[GBd\n{end_of_abc}'), isEmpty);
  });

  test('each song of a file is checked', () {
    expect(problems('{start_of_ly}\nx\n{new_song}\n{title: B}\n[C'), [
      (P.unclosedEnvironment, 1, '{start_of_ly}'),
      (P.unclosedChord, 5, '[C'),
    ]);
  });

  test('the feature showcase has no problems', () {
    final source = File(
      '../../docs/examples/feature-showcase.cho',
    ).readAsStringSync();
    expect(validateChordPro(source), isEmpty);
  });
}
