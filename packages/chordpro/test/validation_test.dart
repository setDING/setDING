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

  test('text after a directive (#309)', () {
    expect(
      problems('{title: T}\n{comment: Chorus} (first time a cappella)\n[G]la'),
      [(P.textAfterDirective, 2, '(first time a cappella)')],
    );
    expect(problems('  {soc} [G]la [Am'), [
      (P.textAfterDirective, 1, '[G]la [Am'),
    ]);
    // Braces in lyrics, a directive whose argument contains a brace and
    // the content of a delegated environment are fine.
    expect(
      problems(
        'la {c: x} li\n{c: a} b}\n{start_of_abc}\n{c: x} y\n{end_of_abc}',
      ),
      isEmpty,
    );
  });

  group('fixes', () {
    test('plain text becomes an italic comment before the directive', () {
      const source =
          '{title: T}\n{comment: Chorus} (first time a cappella)\n[G]la';
      const fixed =
          '{title: T}\n{comment_italic: (first time a cappella)}\n'
          '{comment: Chorus}\n[G]la';
      expect(fixChordProProblems(source), fixed);
      final problem = validateChordPro(source).single;
      expect(canFixChordProProblem(problem), isTrue);
      expect(fixChordProProblem(source, problem), fixed);
      expect(validateChordPro(fixed), isEmpty);
      // Indentation and Windows line breaks are kept.
      expect(
        fixChordProProblems('  {soc}   x2  \r\n[G]la'),
        '  {comment_italic: x2}\r\n  {soc}\r\n[G]la',
      );
    });

    test('chords, directives and remarks move to a line of their own', () {
      expect(fixChordProProblems('{soc} [G]la\n'), '{soc}\n[G]la\n');
      expect(fixChordProProblems('{soc} # note'), '{soc}\n# note');
      // A fix that reveals another problem is followed by its fix.
      expect(
        fixChordProProblems('{c: a} {c: b} x'),
        '{c: a}\n{comment_italic: x}\n{c: b}',
      );
    });

    test('several problems are all fixed', () {
      expect(
        fixChordProProblems('{c: A} one\n[G]la\n{c: B} two'),
        '{comment_italic: one}\n{c: A}\n[G]la\n{comment_italic: two}\n{c: B}',
      );
    });

    test('other problems have no fix', () {
      final problem = validateChordPro('{title: T').single;
      expect(canFixChordProProblem(problem), isFalse);
      expect(fixChordProProblem('{title: T', problem), isNull);
      expect(fixChordProProblems('{title: T\n[C'), '{title: T\n[C');
    });
  });

  test('the feature showcase has no problems', () {
    final source = File(
      '../../docs/examples/feature-showcase.cho',
    ).readAsStringSync();
    expect(validateChordPro(source), isEmpty);
  });
}
