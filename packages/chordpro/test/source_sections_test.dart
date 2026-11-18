import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('finds closed sections with long and short directives', () {
    const source =
        '{title: T}\n{start_of_verse: Intro}\nla\n{end_of_verse}\n\n{soc}\nx\n{eoc}';
    expect(sourceSections(source), [
      const SourceSection(11, 52, 'verse'),
      SourceSection(54, source.length, 'chorus'),
    ]);
    expect(
      source.substring(11, 52),
      '{start_of_verse: Intro}\nla\n{end_of_verse}',
    );
  });

  test('an unclosed section ends before the next one or at the end', () {
    const source = '{sov}\na\n{start_of_bridge}\nb';
    expect(sourceSections(source), [
      const SourceSection(0, 7, 'verse'),
      const SourceSection(8, 27, 'bridge'),
    ]);
  });

  test('other environments and chorus recalls', () {
    const source =
        '{chorus}\n{start_of_tab}\ne|--\n{end_of_tab}\n{start_of_abc}\nX:1\n{end_of_abc}';
    expect(sourceSections(source).map((s) => s.type), ['tab', 'abc']);
  });

  test('an end without a start is ignored', () {
    expect(sourceSections('{eoc}\nla'), isEmpty);
  });

  group('heading comments (#463)', () {
    List<(String, String)> sections(String source) => [
      for (final s in sourceSections(source))
        (s.type, source.substring(s.start, s.end)),
    ];

    test('a heading comment opens a section up to the empty line', () {
      const source =
          '{title: T}\n{comment: Verse 1}\n[G]la\nla\n\n'
          '{c: Chorus}\n[C]oh\n\n{c: Strophe 2:}\nx\n';
      expect(sections(source), [
        ('verse', '{comment: Verse 1}\n[G]la\nla'),
        ('chorus', '{c: Chorus}\n[C]oh'),
        ('verse', '{c: Strophe 2:}\nx'),
      ]);
    });

    test('bridge and other headings', () {
      expect(sections('{c: Bridge}\na\n\n{comment: Intro 2}\nb'), [
        ('bridge', '{c: Bridge}\na'),
        ('custom', '{comment: Intro 2}\nb'),
      ]);
    });

    test('other comments may precede the heading (#465)', () {
      expect(
        sections('{ci: first time a cappella}\n{c: Chorus}\nx\n{c: Verse}'),
        [('chorus', '{c: Chorus}\nx\n{c: Verse}')],
      );
    });

    test('only a normal comment before any lyrics is a heading', () {
      expect(
        sourceSections(
          'la\n{c: Chorus}\nx\n\n{ci: Chorus}\ny\n\n{c: Play softly}\nz\n\n'
          '{c-guitar: Chorus}\nw',
        ),
        isEmpty,
      );
    });

    test('ignores other directives and comment lines before it', () {
      expect(sections('{key: G}\n# note\n{c: Verse}\na\n{tempo: 90}\nb'), [
        ('verse', '{c: Verse}\na\n{tempo: 90}\nb'),
      ]);
    });

    test('ends before an explicit section or a chorus recall', () {
      expect(
        sections('{c: Verse}\na\n{soc}\nb\n{eoc}\n{c: Bridge}\nc\n{chorus}'),
        [
          ('verse', '{c: Verse}\na'),
          ('chorus', '{soc}\nb\n{eoc}'),
          ('bridge', '{c: Bridge}\nc'),
        ],
      );
    });

    test('a heading inside an explicit section is not a section', () {
      expect(sections('{sov}\n{c: Chorus}\na\n\nb\n{eov}'), [
        ('verse', '{sov}\n{c: Chorus}\na\n\nb\n{eov}'),
      ]);
    });

    test('agrees with the parser', () {
      const source = '{c: Verse 1}\na\n\n{c: Refrain}\nb\n\n{c: Solo}\nc';
      final parsed = parseChordPro(source).elements.whereType<Section>();
      expect(parsed.map((s) => s.kind), [
        SectionKind.verse,
        SectionKind.chorus,
        SectionKind.custom,
      ]);
      expect(sourceSections(source).map((s) => s.type), [
        'verse',
        'chorus',
        'custom',
      ]);
    });
  });
}
