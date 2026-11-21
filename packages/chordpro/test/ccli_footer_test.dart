import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

const _footer =
    'CCLI Song # 6016351\n'
    '© 2011 Example Songs | Other Music Ltd\n'
    'For use solely with the SongSelect® Terms of Use. All rights reserved. '
    'www.ccli.com\n'
    'CCLI License # 1375063\n';

void main() {
  test('finds the English footer with its values', () {
    const source = '{title: T}\n\n[G]La la\n\n$_footer';
    final footers = findCcliFooters(source);
    expect(footers, hasLength(1));
    final f = footers.single;
    expect(f.line, 5);
    expect(source.substring(f.start, f.end), _footer);
    expect(f.songNumber, '6016351');
    expect(f.copyright, '2011 Example Songs | Other Music Ltd');
  });

  test('finds the German footer', () {
    const source =
        '[G]La la\n\nCCLI-Liednummer 7654321\r\n© 2024 Example\r\n'
        'Nur zur Verwendung gemäss den SongSelect® Nutzungsbedingungen. '
        'Alle Rechte vorbehalten. www.ccli.com\r\n'
        'CCLI-Lizenznummer 1234567';
    final f = findCcliFooters(source).single;
    expect(f.songNumber, '7654321');
    expect(f.copyright, '2024 Example');
    expect(f.end, source.length);
  });

  test('lyrics, comments and metadata are no footer', () {
    expect(
      findCcliFooters(
        '{ccli: 123}\n{copyright: 2020 X}\n{footer: SongSelect www.ccli.com}\n'
        '© 2020 X\nCCLI is great\n[G]Song 123\n{comment: CCLI Song # 1}\n',
      ),
      isEmpty,
    );
  });

  test('removal keeps the values as metadata', () {
    const source = '{title: T}\n{key: G}\n\n[G]La la\n\n\n$_footer';
    expect(
      removeCcliFooters(source),
      '{title: T}\n{key: G}\n{x_ccli: 6016351}\n'
      '{copyright: 2011 Example Songs | Other Music Ltd}\n\n[G]La la\n',
    );
  });

  test('existing metadata is not overwritten', () {
    const source =
        '{title: T}\n{x_ccli: 1}\n{copyright: Mine}\n{ccli_license: 2}\n\n'
        '[G]La\n\n$_footer';
    expect(
      removeCcliFooters(source),
      '{title: T}\n{x_ccli: 1}\n{copyright: Mine}\n{ccli_license: 2}\n\n[G]La\n',
    );
  });

  test('a footer between paragraphs leaves one empty line', () {
    const source = '{title: T}\n{x_ccli: 1}\n\nA\n\n$_footer\nB\n';
    expect(
      removeCcliFooters(source),
      '{title: T}\n{x_ccli: 1}\n'
      '{copyright: 2011 Example Songs | Other Music Ltd}\n\nA\n\nB\n',
    );
  });

  test('each song keeps the values of its own footer', () {
    const source =
        '{title: A}\n\nla\n\nCCLI Song # 1\n{new_song}\n'
        '{title: B}\n\nlo\n\nCCLI Song # 2\n';
    expect(
      removeCcliFooters(source),
      '{title: A}\n{x_ccli: 1}\n\nla\n{new_song}\n'
      '{title: B}\n{x_ccli: 2}\n\nlo\n',
    );
  });

  test('a {ccli} of a song saved before #777 is kept', () {
    expect(
      removeCcliFooters('{title: T}\n{ccli: 1}\n\nla\n\nCCLI Song # 2\n'),
      '{title: T}\n{ccli: 1}\n\nla\n',
    );
  });

  test('a licence number alone is a footer and not kept', () {
    expect(
      removeCcliFooters('{title: T}\n\nla\n\nCCLI License # 1375063\n'),
      '{title: T}\n\nla\n',
    );
  });

  test('a source without footer is unchanged', () {
    const source = '{title: T}\n\n[G]La la\n';
    expect(removeCcliFooters(source), same(source));
  });
}
