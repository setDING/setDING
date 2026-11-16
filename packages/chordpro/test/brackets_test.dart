import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('cursor on either side of a bracket', () {
    const s = 'la [Am] li';
    // Before "[", after "[", before "]", after "]".
    expect(matchBracket(s, 3), const BracketMatch(3, 6));
    expect(matchBracket(s, 4), const BracketMatch(3, 6));
    expect(matchBracket(s, 6), const BracketMatch(6, 3));
    expect(matchBracket(s, 7), const BracketMatch(6, 3));
  });

  test('no match away from brackets', () {
    const s = 'la [Am] li';
    for (final cursor in [0, 1, 2, 5, 8, 9, 10]) {
      expect(matchBracket(s, cursor), isNull, reason: '$cursor');
    }
    expect(matchBracket('', 0), isNull);
  });

  test('the bracket before the cursor wins', () {
    // Cursor between "]" and "[".
    expect(matchBracket('[C][G]', 3), const BracketMatch(2, 0));
  });

  test('nested brackets of different kinds', () {
    const s = '{chord: [Dm]}';
    expect(matchBracket(s, 0), const BracketMatch(0, 12));
    expect(matchBracket(s, 13), const BracketMatch(12, 0));
    expect(matchBracket(s, 8), const BracketMatch(8, 11));
  });

  test('unmatched brackets', () {
    expect(matchBracket('[G la', 0), const BracketMatch(0, null));
    expect(matchBracket('la G]', 5), const BracketMatch(4, null));
    expect(matchBracket('{title: x]', 10), const BracketMatch(9, null));
  });

  test('matching is per line', () {
    expect(matchBracket('[G\n]', 0), const BracketMatch(0, null));
    expect(matchBracket('[G\n]', 4), const BracketMatch(3, null));
  });

  test('escaped brackets, comments and delegates are ignored', () {
    expect(matchBracket(r'\[x]', 2), isNull);
    expect(matchBracket(r'\[x]', 4), const BracketMatch(3, null));
    expect(matchBracket('# [C]', 3), isNull);
    const abc = '{start_of_abc}\n[GBd]\n{end_of_abc}';
    expect(matchBracket(abc, 15), isNull);
    expect(matchBracket(abc, 0), const BracketMatch(0, 13));
  });
}
