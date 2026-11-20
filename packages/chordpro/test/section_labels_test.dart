import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

List<(int, String, String)> found(String source) => [
  for (final l in findLegacySectionLabels(source))
    (l.line, source.substring(l.start, l.end), l.replacement),
];

void main() {
  test('section starts with a plain label', () {
    expect(
      found(
        '{title: T}\n{start_of_verse: Verse 1}\nla\n{eov}\n'
        '  {soc:Chorus}\r\n{eoc}\n{start_of_verse-alto: Alto}\n'
        '{start_of_intro Intro}\n',
      ),
      [
        (2, '{start_of_verse: Verse 1}', '{start_of_verse: label="Verse 1"}'),
        (5, '{soc:Chorus}', '{soc: label="Chorus"}'),
        (
          7,
          '{start_of_verse-alto: Alto}',
          '{start_of_verse-alto: label="Alto"}',
        ),
        (8, '{start_of_intro Intro}', '{start_of_intro: label="Intro"}'),
      ],
    );
  });

  test('attribute form, no label and other directives are left alone', () {
    expect(
      found(
        '{start_of_verse: label="Verse 1"}\n{start_of_chorus}\n{sov}\n'
        '{comment: Verse 1}\n{chorus: Chorus}\n{title: start_of_verse}\n'
        '{start_of_grid shape="4x4" label="Intro"}',
      ),
      isEmpty,
    );
  });

  test('labels with quotes', () {
    expect(found('{sov: The "Big" one}'), [
      (1, '{sov: The "Big" one}', "{sov: label='The \"Big\" one'}"),
    ]);
    // Both kinds of quotes cannot be written as an attribute.
    expect(found('{sov: Rock \'n\' "roll"}'), isEmpty);
  });

  test('legacy grid arguments become shape and label', () {
    expect(found('{start_of_grid: 1+4x2+4 Intro}\n{sog: 4x4}\n{sog: Strums}'), [
      (
        1,
        '{start_of_grid: 1+4x2+4 Intro}',
        '{start_of_grid: shape="1+4x2+4" label="Intro"}',
      ),
      (2, '{sog: 4x4}', '{sog: shape="4x4"}'),
      (3, '{sog: Strums}', '{sog: label="Strums"}'),
    ]);
  });

  test('lines inside delegated environments are skipped', () {
    expect(
      found(
        '{start_of_abc: Tune}\n{sov: Not a directive}\n{end_of_abc}\n'
        '{start_of_svg}\n{new_song}\n{sov: Second song}',
      ),
      [
        (1, '{start_of_abc: Tune}', '{start_of_abc: label="Tune"}'),
        (6, '{sov: Second song}', '{sov: label="Second song"}'),
      ],
    );
  });

  test('conversion keeps everything else and reads back the same', () {
    const source =
        '{title: T}\n  {start_of_verse: Verse 1}\r\n[G]la\n{eov}\n'
        '{start_of_grid: 1+4x2+4 Intro}\n| G . | C . |\n{eog}\n'
        '{soc: Refrain %{title}}\n[C]li\n{eoc}';
    final converted = convertLegacySectionLabels(source);
    expect(
      converted,
      '{title: T}\n  {start_of_verse: label="Verse 1"}\r\n[G]la\n{eov}\n'
      '{start_of_grid: shape="1+4x2+4" label="Intro"}\n| G . | C . |\n{eog}\n'
      '{soc: label="Refrain %{title}"}\n[C]li\n{eoc}',
    );
    expect(findLegacySectionLabels(converted), isEmpty);
    expect(validateChordPro(converted), isEmpty);
    List<(String?, String?)> sections(String s) => [
      for (final section in parseChordPro(s).sections)
        (section.name, section.label),
    ];
    expect(sections(converted), sections(source));
    final grids = [
      for (final s in [source, converted])
        parseChordPro(
          s,
        ).sections.firstWhere((x) => x.gridShape != null).gridShape!.cells,
    ];
    expect(grids[1], grids[0]);
  });
}
