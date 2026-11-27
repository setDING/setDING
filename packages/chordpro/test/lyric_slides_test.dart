import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// The lyrics slide model of the projection (ADR-0068, #1166).
void main() {
  List<String> codes(List<LyricSection> s) => [
    for (final x in s) x.code ?? '-',
  ];
  List<String> firstLines(List<LyricSection> s) => [
    for (final x in s) x.lines.first,
  ];

  group('lyricSections', () {
    test('plain lyrics without sections, chords and markup removed', () {
      final song = parseChordPro(
        '{title: T}\n[G]Amazing <b>grace</b>, how [D]sweet\n[C]the sound\n',
      );
      final sections = lyricSections(song);
      expect(sections, hasLength(1));
      expect(sections.single.lines, ['Amazing grace, how sweet', 'the sound']);
      expect(sections.single.code, isNull);
      expect(sections.single.label, isNull);
    });

    test(
      'comments, tabs, grids, chord-only lines and delegates are left out',
      () {
        final song = parseChordPro('''
{start_of_verse: Intro}
[G] [D] [C]
{end_of_verse}
{start_of_verse: Verse 1}
{comment: softly}
[G]Line one
{image: src="x.png"}
{end_of_verse}
{start_of_tab: Riff}
e|--3--|
{end_of_tab}
{start_of_grid}
| G . . . | D . . . |
{end_of_grid}
{start_of_textblock}
Spoken words
{end_of_textblock}
''');
        final sections = lyricSections(song);
        expect(codes(sections), ['V1']);
        expect(sections.single.lines, ['Line one']);
        expect(sections.single.label, 'Verse 1');
      },
    );

    test('paragraph breaks are kept once and never at an edge', () {
      final song = parseChordPro(
        '{start_of_verse}\n\nOne\n\n\nTwo\n\n{end_of_verse}\n',
      );
      expect(lyricSections(song).single.lines, ['One', '', 'Two']);
      expect(lyricSections(song).single.textLines, 2);
    });

    test('document order repeats a recalled chorus', () {
      final song = parseChordPro('''
{start_of_verse}
First verse
{end_of_verse}
{start_of_chorus}
Chorus line
{end_of_chorus}
{start_of_verse}
Second verse
{end_of_verse}
{chorus}
''');
      final sections = lyricSections(song);
      expect(firstLines(sections), [
        'First verse',
        'Chorus line',
        'Second verse',
        'Chorus line',
      ]);
      expect(codes(sections), ['V1', 'C', 'V2', 'C']);
      expect(identical(sections[1].section, sections[3].section), isTrue);
    });

    test('a sequence sets the order, repeats parts and keeps repetitions', () {
      final song = parseChordPro('''
{x_sequence: V1, C, V2, C x2}
{start_of_verse: Verse 1}
First verse
{end_of_verse}
{start_of_verse: Verse 2}
Second verse
{end_of_verse}
{start_of_chorus: Chorus}
Chorus line
{end_of_chorus}
''');
      final sections = lyricSections(song, sequence: song.sequence);
      expect(firstLines(sections), [
        'First verse',
        'Chorus line',
        'Second verse',
        'Chorus line',
      ]);
      expect([for (final s in sections) s.repeat], [null, null, null, 2]);
    });

    test('an unnumbered part takes the next section of its kind', () {
      final song = parseChordPro('''
{start_of_verse}
First verse
{end_of_verse}
{start_of_verse}
Second verse
{end_of_verse}
''');
      final sequence = parseSequence('V, V');
      expect(firstLines(lyricSections(song, sequence: sequence)), [
        'First verse',
        'Second verse',
      ]);
    });

    test('a sequence matching no part falls back to document order', () {
      final song = parseChordPro('{start_of_verse}\nOnly\n{end_of_verse}\n');
      expect(firstLines(lyricSections(song, sequence: parseSequence('Coda'))), [
        'Only',
      ]);
    });
  });

  group('lyricSlides', () {
    LyricSection section(int lines, {String prefix = 'L'}) => LyricSection(
      section: Section(kind: SectionKind.verse),
      lines: [for (var i = 1; i <= lines; i++) '$prefix$i'],
    );

    List<int> sizes(List<LyricSlide> slides) => [
      for (final s in slides) s.lines.length,
    ];

    test('a section that fits is one slide', () {
      final slides = lyricSlides([section(8), section(3)]);
      expect(sizes(slides), [8, 3]);
      expect([for (final s in slides) s.index], [0, 1]);
      expect([for (final s in slides) (s.page, s.pages)], [(0, 1), (0, 1)]);
      expect(slides.first.second, isNull);
    });

    test('a long section is split evenly, the first slides longer', () {
      expect(sizes(lyricSlides([section(10)])), [5, 5]);
      final slides = lyricSlides([section(17)]);
      expect(sizes(slides), [6, 6, 5]);
      expect(slides.last.lines.first, 'L13');
      expect([for (final s in slides) s.page], [0, 1, 2]);
      expect(slides.every((s) => s.pages == 3), isTrue);
    });

    test('lines per slide below one counts as one', () {
      expect(sizes(lyricSlides([section(2)], linesPerSlide: 0)), [1, 1]);
    });

    test('a paragraph break at a slide edge is dropped', () {
      final s = LyricSection(
        section: Section(kind: SectionKind.verse),
        lines: const ['A', 'B', '', 'C', 'D'],
      );
      final slides = lyricSlides([s], linesPerSlide: 2);
      expect(
        [for (final x in slides) x.lines],
        [
          ['A', 'B'],
          ['C', 'D'],
        ],
      );
      expect(lyricSlides([s]).single.lines, ['A', 'B', '', 'C', 'D']);
    });

    test('two languages are paired by position and split alike', () {
      final slides = lyricSlides(
        [section(4), section(12), section(2)],
        second: [
          section(4, prefix: 'E'),
          section(6, prefix: 'E'),
        ],
      );
      expect(sizes(slides), [4, 6, 6, 2]);
      expect(slides[0].second, ['E1', 'E2', 'E3', 'E4']);
      expect(slides[1].second, ['E1', 'E2', 'E3']);
      expect(slides[2].second, ['E4', 'E5', 'E6']);
      expect(slides[3].second, isNull);
      expect(slides[3].secondSource, isNull);
    });

    test('a longer second language adds slides to the pair', () {
      final slides = lyricSlides(
        [section(2)],
        linesPerSlide: 4,
        second: [section(9, prefix: 'E')],
      );
      expect(slides, hasLength(3));
      expect(
        [for (final s in slides) s.lines],
        [
          ['L1'],
          ['L2'],
          <String>[],
        ],
      );
      expect([for (final s in slides) s.second!.length], [3, 3, 3]);
    });
  });

  group('feature showcase', () {
    final song = parseChordPro(
      File('../../docs/examples/feature-showcase.cho').readAsStringSync(),
    );

    test('copyright for the slides', () {
      expect(song.copyright, '2026 setDING (free to use)');
    });

    test('follows the sequence and keeps only lyrics', () {
      final sections = lyricSections(song, sequence: song.sequence);
      expect(codes(sections), ['V1', 'C', 'C x2', 'B', 'O']);
      final lines = sections.expand((s) => s.lines).toList();
      expect(lines, isNot(contains(contains('<'))));
      expect(lines.first, startsWith('Markup in lyrics: bold, italic'));
      expect(lines, isNot(contains(contains('e|'))));
      expect(lyricSlides(sections), isNotEmpty);
    });

    test('document order has no tab, grid or delegate content', () {
      final sections = lyricSections(song);
      final labels = [for (final s in sections) s.label];
      expect(labels, isNot(contains('Riff')));
      expect(labels, isNot(contains('Intro grid')));
      expect(labels, isNot(contains('Spoken intro')));
      expect(labels, isNot(contains('Inline SVG')));
    });
  });
}
