import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

const _footer =
    'CCLI Song # 6016351\n'
    '© 2011 Example Songs\n'
    'For use solely with the SongSelect® Terms of Use. All rights reserved. '
    'www.ccli.com\n'
    'CCLI License # 1375063\n';

void main() {
  test('a tidy song has nothing to convert', () {
    const source =
        '{title: T}\n{x_ccli: 1}\n{start_of_verse: label="Verse 1"}\n'
        '[G]La la\n{end_of_verse}\n';
    expect(countChordProConversions(source), 0);
    expect(applyChordProConversions(source), source);
  });

  test('counts every kind of conversion', () {
    const source =
        '{title: T}\n{ccli: 6016351}\n{ccli_license: 1375063}\n'
        '{start_of_verse: Verse 1}\n[G]La la\n{end_of_verse}\n'
        '{comment: Turnaround}\n[|][G]  [.]  [.]  [.][|]\n\n$_footer';
    // Two directives, one footer, one grid, one label.
    expect(countChordProConversions(source), 5);
  });

  test('applies every conversion, after which nothing is left', () {
    const source =
        '{title: T}\n{ccli: 6016351}\n{ccli_license: 1375063}\n'
        '{start_of_verse: Verse 1}\n[G]La la\n{end_of_verse}\n'
        '{comment: Turnaround}\n[|][G]  [.]  [.]  [.][|]\n\n$_footer';
    final converted = applyChordProConversions(source);
    expect(countChordProConversions(converted), 0);
    expect(converted, contains('{x_ccli: 6016351}'));
    // The footer does not add a second song number.
    expect('{x_ccli'.allMatches(converted), hasLength(1));
    expect(converted, isNot(contains('ccli_license')));
    expect(converted, isNot(contains('SongSelect')));
    expect(converted, contains('{start_of_verse: label="Verse 1"}'));
    expect(
      converted,
      contains('{start_of_grid shape="1x4" label="Turnaround"}'),
    );
  });
}
