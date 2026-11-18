import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Regression test for docs/examples/feature-showcase.cho, which uses every
/// supported ChordPro feature.
void main() {
  final source = File(
    '../../docs/examples/feature-showcase.cho',
  ).readAsStringSync();

  List<Line> linesOf(Song song) =>
      song.sections.expand((s) => s.lines).toList();

  List<String> comments(Song song) => [
    for (final l in linesOf(song))
      if (l is CommentLine) l.text,
  ];

  test('two songs in one file', () {
    final songs = parseChordProSongs(source);
    expect(songs.map((s) => s.title), [
      'Feature Showcase',
      'Second Song in the Same File',
    ]);
    expect(splitChordProSongs(source), hasLength(2));
  });

  group('first song', () {
    final song = parseChordPro(
      source,
      selectors: const SelectorContext(instrument: 'guitar', user: 'alto'),
    );

    test('meta-data', () {
      expect(song.sortTitle, 'Showcase, Feature');
      expect(song.sortArtist, 'setDING Band, The');
      expect(song.meta['composer'], hasLength(2));
      expect(song.tags, ['Test', 'Showcase']);
      expect(song.sequence.map((i) => i.part), [
        SequencePart.intro,
        SequencePart.verse,
        SequencePart.chorus,
        SequencePart.verse,
        SequencePart.preChorus,
        SequencePart.chorus,
        SequencePart.bridge,
        SequencePart.outro,
      ]);
      expect(song.meta['key'], ['G', 'A']);
      expect(song.tempo, 96);
      expect(song.meter, Meter.common);
      expect(song.columns, 2);
      expect(song.diagrams, 'bottom');
    });

    test('metadata substitution and comment styles', () {
      final c = comments(song);
      expect(
        c,
        contains('Feature Showcase by The setDING Band – key G, 96 BPM'),
      );
      expect(
        c,
        contains(
          'Composers: A. Composer, B. Composer (first: A. Composer, last: B. Composer)',
        ),
      );
      expect(c, contains('Album: Test Recordings · This year'));
      expect(c, contains('Instrument: guitar · User: alto'));
      expect(c, contains('Escaped markup characters: %{not metadata}'));
      final styles = linesOf(
        song,
      ).whereType<CommentLine>().map((l) => l.style).toSet();
      expect(styles, containsAll(CommentStyle.values));
    });

    test('conditional directives', () {
      final c = comments(song);
      expect(c, contains('Shown only for guitar'));
      expect(c, isNot(contains('Shown only for ukulele')));
      expect(c, isNot(contains('Shown for every instrument except guitar')));
      expect(c, contains('Shown only for the user "alto"'));
      expect(c, contains('Shown because the meta item "duet" is true'));
      expect(c, isNot(contains('Never shown')));
      expect(
        song.sections.map((s) => s.label),
        isNot(contains('Soprano only')),
      );

      final ukulele = parseChordPro(
        source,
        selectors: const SelectorContext(
          instrument: 'ukulele',
          user: 'soprano',
        ),
      );
      expect(comments(ukulele), contains('Shown only for ukulele'));
      expect(
        comments(ukulele),
        contains('Shown for every instrument except guitar'),
      );
      expect(ukulele.sections.map((s) => s.label), contains('Soprano only'));
      // The ukulele definition of G6 replaces the guitar one.
      final g6 = ukulele.definitions.where((d) => d.name == 'G6').last;
      expect(g6.frets, hasLength(4));
    });

    test('sections, labels, recalls and SongSelect headings', () {
      final labels = song.sections.map((s) => s.label).toList();
      expect(labels, contains('Verse 1\nAll voices'));
      expect(
        song.sections.any(
          (s) => s.kind == SectionKind.custom && s.name == 'outro',
        ),
        isTrue,
      );
      expect(song.elements.whereType<ChorusRecall>(), hasLength(2));
      final heading = song.sections.firstWhere((s) => s.label == 'Chorus 2');
      expect(heading.kind, SectionKind.chorus);

      // The editor colours the heading section like the parser reads it.
      final editor = sourceSections(source).where(
        (s) =>
            source.substring(s.start, s.end).startsWith('{comment: Chorus 2}'),
      );
      expect(editor.single.type, 'chorus');
      expect(
        source.substring(editor.single.start, editor.single.end),
        endsWith('becomes a chorus section.'),
      );
    });

    test('chords: markup, annotations, optional, German names, escapes', () {
      final verse = song.sections.firstWhere(
        (s) => s.label == 'Verse 1\nAll voices',
      );
      final tokens = [
        for (final l in verse.lines.whereType<LyricLine>())
          for (final s in l.segments)
            if (s.chord != null) s.chord!,
      ];
      final f = ChordFormatter.forSong(song, transpose: 2);
      String shown(String raw) =>
          f.format(tokens.firstWhere((t) => t.raw == raw));
      expect(shown('<b>Am</b>'), 'Bm');
      expect(
        chordMarkupStyle(tokens.firstWhere((t) => t.raw == '<b>Am</b>')).bold,
        isTrue,
      );
      expect(shown('*<i>Rit.</i>'), 'Rit.');
      expect(shown('N.C.'), 'N.C.');
      expect(shown('(D/F#)'), '(E/G#)');
      expect(shown('Hm'), 'C#m');
      expect(shown('Fis'), 'G#');
      expect(shown('Bes'), 'C');
      expect(shown('Es'), 'F');
      expect(shown('As'), 'A#'); // spelled for the sharp key A
      // Spelling variants, unified by the chord style (ADR-0022).
      String styled(String raw, ChordStyle style) => ChordFormatter.forSong(
        song,
        style: style,
      ).format(tokens.firstWhere((t) => t.raw == raw));
      expect(
        [
          'Ami7',
          'A-7',
          'CΔ7',
          'Bø',
          'C°7',
        ].map((r) => styled(r, ChordStyle.standard)).toList(),
        ['Am7', 'Am7', 'Cmaj7', 'Bm7b5', 'Cdim7'],
      );
      expect(
        [
          'Ami7',
          'A-7',
          'CΔ7',
          'Bø',
          'C°7',
        ].map((r) => styled(r, ChordStyle.jazz)).toList(),
        ['A−7', 'A−7', 'CΔ7', 'Bø7', 'C°7'],
      );
      expect(shown('CΔ7'), 'DΔ7'); // as written, transposed
      final escaped = verse.lines.whereType<LyricLine>().firstWhere(
        (l) => l.text.contains('Escaped'),
      );
      expect(escaped.text, contains('[not a chord]'));
      final markup = verse.lines.whereType<LyricLine>().first;
      expect(markup.plainText, startsWith('Markup in lyrics: bold, italic'));
    });

    test('transpose directives and key changes', () {
      final section = song.sections.firstWhere(
        (s) => s.label == 'Transposition',
      );
      final rows = [
        for (final l in section.lines.whereType<LyricLine>())
          [
            for (final s in l.segments)
              if (s.chord != null)
                ChordFormatter.forSong(song).format(s.chord!),
          ],
      ];
      expect(rows, [
        ['C', 'D', 'E', 'F'],
        ['D', 'E', 'F#', 'G'],
        ['D', 'E', 'Gb', 'G'],
        ['D', 'E', 'Gb', 'G'],
        ['C', 'D', 'E', 'F'],
      ]);
      final modulation = song.sections.firstWhere(
        (s) => s.label == 'Modulation to A',
      );
      final nashville = ChordFormatter.forSong(song, nashville: true);
      expect(
        [
          for (final s in (modulation.lines.first as LyricLine).segments)
            if (s.chord != null) nashville.format(s.chord!),
        ],
        ['1', '4', '5'],
      );
    });

    test('tab and grids', () {
      final tab = song.sections.firstWhere((s) => s.kind == SectionKind.tab);
      expect(tab.lines.whereType<RawLine>(), hasLength(3));
      final grids = song.sections
          .where((s) => s.kind == SectionKind.grid)
          .toList();
      expect(grids.first.label, 'Intro grid');
      expect(grids.first.gridShape!.right, 4);
      final tokens = grids.first.lines.whereType<GridLine>().expand(
        (l) => l.row.tokens,
      );
      expect(tokens.whereType<GridBar>().map((b) => b.volta).whereType<int>(), [
        1,
        2,
      ]);
      expect(
        tokens.whereType<GridMark>().map((m) => m.symbol).toSet(),
        containsAll(GridSymbol.values),
      );
      final strums = grids.last.lines.whereType<GridLine>().map((l) => l.row);
      expect(strums.map((r) => (r.strum, r.hideBars)), [
        (true, false),
        (true, true),
      ]);
    });

    test('format, break and diagram lines', () {
      final lines = linesOf(song);
      // Every format change is undone again by the end of the song.
      final state = FormatState();
      applyFormatLines(state, lines);
      for (final target in FormatTarget.values) {
        expect(state.valuesFor(target).isDefault, isTrue, reason: '$target');
      }
      final targets = lines
          .whereType<FormatLine>()
          .map((f) => f.target)
          .toSet();
      expect(
        targets,
        containsAll({
          FormatTarget.text,
          FormatTarget.chord,
          FormatTarget.label,
          FormatTarget.chorus,
        }),
      );
      expect(lines.whereType<BreakLine>().map((b) => b.kind), [
        BreakKind.column,
        BreakKind.page,
      ]);
      final diagrams = lines
          .whereType<ChordDiagramLine>()
          .map((l) => l.definition)
          .toList();
      expect(diagrams.map((d) => d.name), ['Am', 'E7', 'Dm']);
      expect(diagrams.last.transposable, isTrue);
      expect(
        song.definitions.map((d) => d.name),
        containsAll(['Am', 'G6', 'Hm7', 'Csus2']),
      );
      expect(
        song.definitions.firstWhere((d) => d.name == 'Csus2').diagram,
        isFalse,
      );
      expect(song.definitions.firstWhere((d) => d.name == 'Hm7').copy, 'Bm7');
    });

    test('images and delegated environments', () {
      final image = linesOf(song).whereType<ImageLine>().single;
      expect(image.src, 'stage-plan.svg');
      expect(image.attributes['width'], '50%');
      final delegates = song.elements.whereType<DelegateSection>().toList();
      expect(delegates.map((d) => d.type).toSet(), DelegateType.values.toSet());
      final abc = parseAbc(
        delegates.firstWhere((d) => d.type == DelegateType.abc).content,
      );
      expect(abc.title, 'Showcase Melody');
      expect(abc.key.name, 'G');
      expect(
        abc.lines.single.elements.whereType<AbcNote>().first.lyric,
        "Here's",
      );
    });
  });

  test('second song: odd meter with a grouping (ADR-0026)', () {
    final second = parseChordProSongs(source).last;
    expect(second.meter.toString(), '7/8');
    expect(second.meter.kind, MeterKind.odd);
    expect(second.meter.groups, [2, 2, 3]);
    expect(second.tempo, 210);
  });
}
