import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

List<String> chordsOf(Song song, ChordFormatter f, {int section = 0}) => [
  for (final line
      in song.sections.elementAt(section).lines.whereType<LyricLine>())
    for (final s in line.segments)
      if (s.chord != null) f.format(s.chord!),
];

void main() {
  group('directive syntax', () {
    test('attributes, quotes and multi-line labels', () {
      final song = parseChordPro(
        "{start_of_verse: label='Verse 1\\nAll'}\n[C]x\n{end_of_verse}\n"
        '{start_of_chorus Chorus 2}\n[F]y\n{eoc}',
      );
      expect(song.sections.first.label, 'Verse 1\nAll');
      expect(song.sections.last.label, 'Chorus 2');
    });

    test('custom environments keep their name', () {
      final song = parseChordPro('{start_of_outro}\n[C]End\n{end_of_outro}');
      expect(song.sections.single.kind, SectionKind.custom);
      expect(song.sections.single.name, 'outro');
    });

    test('x_ directives and unknown directives are ignored', () {
      final song = parseChordPro('{x_mspro_pedal: 3}\n{pagetype: a4}\n[C]Hi');
      expect(song.sections.single.lines, hasLength(1));
    });

    test('escaped brackets are literal text', () {
      final line = parseLyricLine(r'Use \[brackets\] [G]here');
      expect(line.text, 'Use [brackets] here');
      expect(line.segments.last.chord!.raw, 'G');
    });
  });

  group('meta-data', () {
    test('all standard items, multiple values and meta directive', () {
      final song = parseChordPro('''
{title: Song}
{sorttitle: Song, The}
{sortartist: Beatles, The}
{arranger: Someone}
{tag: Rock}
{tag: Needs study}
{meta: composer John Lennon}
{meta: composer Paul McCartney}
{meta: mood happy}
''');
      expect(song.sortTitle, 'Song, The');
      expect(song.sortArtist, 'Beatles, The');
      expect(song.metaValue('arranger'), 'Someone');
      expect(song.tags, ['Rock', 'Needs study']);
      expect(song.meta['composer'], ['John Lennon', 'Paul McCartney']);
      expect(song.metaValue('mood'), 'happy');
    });

    test('metadata substitution in comments and labels', () {
      final song = parseChordPro('''
{title: Swing Low}
{album: Cover Stories}
{album: Greatest Hits}
{key: C}
{c: %{title} – %{album}}
{c: %{album.1} / %{album.-1}}
{c: %{album|Album: %{}|none}}
{c: %{year|Year %{}|No year}}
{c: %{key=C|In C|Not in C}}
{c: Price \\%\\{literal\\}}
{start_of_verse: %{title} verse}
[C]x
{end_of_verse}
''');
      final comments = song.sections
          .expand((s) => s.lines)
          .whereType<CommentLine>()
          .map((c) => c.text)
          .toList();
      expect(comments, [
        'Swing Low – Cover Stories, Greatest Hits',
        'Cover Stories / Greatest Hits',
        'Album: Cover Stories, Greatest Hits',
        'No year',
        'In C',
        'Price %{literal}',
      ]);
      expect(song.sections.last.label, 'Swing Low verse');
    });

    test('key_actual, key_from and _key follow transposition and capo', () {
      final song = parseChordPro('''
{key: C}
{capo: 2}
{c: %{key_actual}|%{key_from}|%{_key}}
{transpose: 2}
{c: %{key_actual}|%{key_from}}
''');
      final comments = song.sections
          .expand((s) => s.lines)
          .whereType<CommentLine>()
          .map((c) => c.text)
          .toList();
      expect(comments, ['C||D', 'D|C']);
    });
  });

  group('transpose', () {
    test('example from the specification: +2 uses sharps', () {
      final song = parseChordPro(
        '[C]A song [D] line with [E]chords [F]\n{transpose: 2}\n'
        '[C]A song [D] line with [E]chords [F]',
      );
      final f = ChordFormatter.forSong(song);
      expect(chordsOf(song, f), ['C', 'D', 'E', 'F', 'D', 'E', 'F#', 'G']);
    });

    test('example from the specification: -10 uses flats', () {
      final song = parseChordPro('{transpose: -10}\n[E]x');
      expect(chordsOf(song, ChordFormatter.forSong(song)), ['Gb']);
    });

    test('s/f suffix overrides the accidentals', () {
      final flat = parseChordPro('{transpose: 2f}\n[E]x');
      expect(chordsOf(flat, ChordFormatter.forSong(flat)), ['Gb']);
      final sharp = parseChordPro('{transpose: -10s}\n[E]x');
      expect(chordsOf(sharp, ChordFormatter.forSong(sharp)), ['F#']);
    });

    test('empty transpose restores the previous transposition', () {
      final song = parseChordPro(
        '{transpose: 2}\n[C]a\n{transpose: 5}\n[C]b\n{transpose}\n[C]c\n'
        '{transpose}\n[C]d',
      );
      expect(chordsOf(song, ChordFormatter.forSong(song)), [
        'D',
        'F',
        'D',
        'C',
      ]);
    });

    test('combines with app transposition and shifts the header key', () {
      final song = parseChordPro('{key: C}\n{transpose: 2}\n[C]x');
      final f = ChordFormatter.forSong(song, transpose: 1);
      expect(chordsOf(song, f), ['Eb']);
      expect(f.formatKey(), 'Eb');
    });
  });

  group('key and capo', () {
    test('Nashville numbers follow key changes (modulation)', () {
      final song = parseChordPro('{key: C}\n[C]a [G]b\n{key: D}\n[D]c [A]d');
      final f = ChordFormatter.forSong(song, view: ChordView.nashville);
      expect(chordsOf(song, f), ['1', '5', '1', '5']);
      expect(song.meta['key'], ['C', 'D']);
    });

    test('song capo: chords are shapes, sounding key is key + capo', () {
      final song = parseChordPro('{key: C}\n{capo: 2}\n[C]a [G]b');
      final asWritten = ChordFormatter.forSong(song);
      expect(chordsOf(song, asWritten), ['C', 'G']);
      expect(asWritten.formatKey(), 'D');
      expect(asWritten.effectiveCapo, 2);
      // Without capo the player needs the sounding chords.
      final noCapo = ChordFormatter.forSong(song, capo: 0);
      expect(chordsOf(song, noCapo), ['D', 'A']);
    });
  });

  group('conditional directives', () {
    const source = '''
{title: Choir}
{comment-alto: Very softly!}
{comment-tenor: Sing this with power}
{comment-guitar!: No guitar here}
{start_of_verse-soprano}
[C]Soprano only
{end_of_verse}
{start_of_verse}
[G]Everyone
{end_of_verse}
{meta: duet true}
{c-duet: Duet part}
''';

    List<String> visible(SelectorContext context) {
      final song = parseChordPro(source, selectors: context);
      return [
        for (final line in song.sections.expand((s) => s.lines))
          switch (line) {
            final CommentLine c => c.text,
            final LyricLine l => l.text,
            _ => '',
          },
      ];
    }

    test('selects by instrument and user', () {
      expect(
        visible(const SelectorContext(instrument: 'guitar', user: 'alto')),
        ['Very softly!', 'Everyone', 'Duet part'],
      );
      expect(visible(const SelectorContext(user: 'Soprano')), [
        'No guitar here',
        'Soprano only',
        'Everyone',
        'Duet part',
      ]);
    });

    test('define depends on the instrument', () {
      const defs = '''
{define-guitar: Am base-fret 1 frets 0 2 2 1 0 0}
{define-ukulele: Am base-fret 1 frets 2 0 0 0}
''';
      final guitar = parseChordPro(
        defs,
        selectors: const SelectorContext(instrument: 'guitar'),
      );
      expect(guitar.definitions.single.frets, hasLength(6));
      final ukulele = parseChordPro(
        defs,
        selectors: const SelectorContext(instrument: 'ukulele'),
      );
      expect(ukulele.definitions.single.frets, hasLength(4));
    });
  });

  group('new_song', () {
    test('splits a file into several songs', () {
      final songs = parseChordProSongs(
        '{title: One}\n[C]a\n{new_song}\n{title: Two}\n[G]b\n{ns}\n{t: Three}',
      );
      expect(songs.map((s) => s.title), ['One', 'Two', 'Three']);
      expect(parseChordPro('{title: One}\n{ns}\n{title: Two}').title, 'One');
    });

    test('splits the source text per song', () {
      final parts = splitChordProSongs(
        '{ns}\n{title: One}\n[C]a\n\n{new_song}\n{title: Two}\r\n[G]b\n{ns}\n',
      );
      expect(parts, ['{title: One}\n[C]a\n', '{title: Two}\n[G]b\n']);
      expect(splitChordProSongs('[C]single'), ['[C]single\n']);
    });
  });

  group('grids', () {
    final song = parseChordPro('''
{start_of_grid shape="1+4x2+4" label="Intro"}
A    || G7 . | % . | %% . | . . |
     | C7 . | %  . || G7 . | % . ||
     |: C7 . | %  . :|: G7~D7 . | / . :| repeat 4 times
{end_of_grid}
{start_of_grid}
| S dn up dn up |
{end_of_grid}
''');

    test('shape, label and margins', () {
      final grid = song.sections.first;
      expect(grid.kind, SectionKind.grid);
      expect(grid.label, 'Intro');
      expect(grid.gridShape!.left, 1);
      expect(grid.gridShape!.measures, 4);
      expect(grid.gridShape!.beats, 2);
      expect(grid.gridShape!.right, 4);
      final rows = grid.lines.whereType<GridLine>().map((l) => l.row).toList();
      expect(rows.first.leftMargin, 'A');
      expect(rows.last.rightMargin, 'repeat 4 times');
    });

    test('tokens: bars, chords, marks and multiple chords per cell', () {
      final row = (song.sections.first.lines[2] as GridLine).row;
      expect(row.tokens.first, isA<GridBar>());
      expect((row.tokens.first as GridBar).symbol, '|:');
      final multi = row.tokens.whereType<GridChords>().firstWhere(
        (c) => c.chords.length == 2,
      );
      expect(multi.chords.map((c) => c.raw), ['G7', 'D7']);
      expect(
        row.tokens.whereType<GridMark>().map((m) => m.symbol),
        contains(GridSymbol.slash),
      );
      final first = (song.sections.first.lines[0] as GridLine).row;
      expect(
        first.tokens.whereType<GridMark>().map((m) => m.symbol),
        containsAll([GridSymbol.repeat1, GridSymbol.repeat2, GridSymbol.empty]),
      );
    });

    test('grid chords are transposed', () {
      final f = ChordFormatter.forSong(song, transpose: 2);
      final chords = (song.sections.first.lines[0] as GridLine).row.tokens
          .whereType<GridChords>()
          .first
          .chords;
      expect(f.format(chords.single), 'A7');
    });

    test('strum lines and shape reuse', () {
      final strum = song.sections.last;
      expect(strum.gridShape!.measures, 4); // reused from the previous grid
      final row = (strum.lines.single as GridLine).row;
      expect(row.strum, isTrue);
      expect(row.tokens.whereType<GridStrum>().map((s) => s.symbol), [
        '↓',
        '↑',
        '↓',
        '↑',
      ]);
    });

    test('legacy shape argument', () {
      final legacy = parseChordPro(
        '{start_of_grid: 4x4 Verse}\n| C . . . |\n{eog}',
      );
      expect(legacy.sections.single.gridShape!.cells, 16);
      expect(legacy.sections.single.label, 'Verse');
    });
  });

  group('delegated environments', () {
    test('abc, ly, svg and textblock keep their raw content', () {
      final song = parseChordPro('''
{start_of_abc label="Tune"}
X:1
K:G
GABc|
{end_of_abc}
{start_of_ly}
\\relative c' { c d e f }
{end_of_ly}
{start_of_svg}
<svg xmlns="http://www.w3.org/2000/svg"><circle r="5"/></svg>
{end_of_svg}
{start_of_textblock align=right flush=right}
She died of the [fever]
{end_of_textblock}
''');
      final delegates = song.elements.whereType<DelegateSection>().toList();
      expect(delegates.map((d) => d.type), [
        DelegateType.abc,
        DelegateType.ly,
        DelegateType.svg,
        DelegateType.textblock,
      ]);
      expect(delegates.first.label, 'Tune');
      expect(delegates.first.lines, ['X:1', 'K:G', 'GABc|']);
      expect(delegates.last.attributes['flush'], 'right');
      expect(delegates.last.content, 'She died of the [fever]');
      expect(song.hasContent, isTrue);
    });
  });

  group('images, diagrams and output directives', () {
    final song = parseChordPro('''
{image: src="score.png" width=200 align=center}
{image: "simple.png"}
{define: C7 base-fret 1 frets x 3 2 3 1 0 fingers 0 3 2 4 1 0}
{define: [Bb] base-fret 1 frets 1 1 3 3 3 1}
{chord: Am}
{chord: As base-fret 4 frets 1 3 3 2 1 1 fingers 1 3 4 2 1 1}
{diagrams: top}
{columns: 2}
[C]Before
{column_break}
[G]After
{new_page}
{textcolour: red}
{textsize: 150%}
[F]Big red
{textcolour}
{cf: serif}
''');
    final lines = song.sections.expand((s) => s.lines).toList();

    test('images with attributes and plain file name', () {
      final images = lines.whereType<ImageLine>().toList();
      expect(images.first.src, 'score.png');
      expect(images.first.attributes['width'], '200');
      expect(images.last.src, 'simple.png');
    });

    test('chord definitions and inline diagrams', () {
      final c7 = song.definitions.first;
      expect(c7.name, 'C7');
      expect(c7.frets, [null, 3, 2, 3, 1, 0]);
      expect(c7.fingers, [null, 3, 2, 4, 1, null]);
      expect(song.definitions.last.transposable, isTrue);
      final inline = lines.whereType<ChordDiagramLine>().toList();
      expect(inline.first.definition.name, 'Am');
      expect(inline.first.definition.hasShape, isFalse);
      expect(inline.last.definition.baseFret, 4);
      expect(song.diagrams, 'top');
    });

    test('columns, breaks and format changes', () {
      expect(song.columns, 2);
      expect(lines.whereType<BreakLine>().map((b) => b.kind), [
        BreakKind.column,
        BreakKind.page,
      ]);
      final formats = lines.whereType<FormatLine>().toList();
      expect(formats.map((f) => (f.target, f.property, f.value)), [
        (FormatTarget.text, FormatProperty.colour, 'red'),
        (FormatTarget.text, FormatProperty.size, '150%'),
        (FormatTarget.text, FormatProperty.colour, null),
        (FormatTarget.chord, FormatProperty.font, 'serif'),
      ]);
    });
  });

  group('chord names', () {
    test('German and Dutch note names', () {
      String name(String c) => Chord.tryParse(c)!.toString();
      expect(name('Cis'), 'C#');
      expect(name('Fism7'), 'F#m7');
      expect(name('Bes'), 'Bb');
      expect(name('As'), 'Ab');
      expect(name('Es7'), 'Eb7');
      expect(name('Asus4'), 'Asus4');
      expect(name('Esus'), 'Esus');
      expect(name('H7'), 'B7');
    });

    test('Roman and Nashville chords in the source are not transposed', () {
      final song = parseChordPro('[IV]a [1]b [vi]c');
      final f = ChordFormatter.forSong(song, transpose: 3);
      expect(chordsOf(song, f), ['IV', '1', 'vi']);
    });
  });
}
