import 'package:realchord/data/demo_song.dart';
import 'package:realchord/ui/render/song_view.dart';
import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

String? _labeler(SectionKind kind) => switch (kind) {
  SectionKind.verse => 'Verse',
  SectionKind.chorus => 'Chorus',
  SectionKind.bridge => 'Bridge',
  _ => null,
};

void main() {
  group('partitionColumns', () {
    test('keeps order and balances heights', () {
      expect(partitionColumns([1, 1, 1, 1], 2), [2]);
      expect(partitionColumns([3, 1, 1, 1], 2), [1]);
      expect(partitionColumns([1, 2, 3, 4, 5], 3), [3, 4]);
      expect(partitionHeight([1, 2, 3, 4, 5], 3), 6);
    });

    test('never creates more columns than blocks', () {
      expect(partitionColumns([5], 3), isEmpty);
      expect(partitionColumns([1, 1], 4), [1]);
    });
  });

  group('songPages', () {
    test('uses as few pages as possible', () {
      expect(songPages([1, 1, 1, 1], 1, 4), [4]);
      expect(songPages([1, 1, 1, 1], 1, 2), [2, 4]);
      expect(songPages([1, 1, 1, 1, 1], 1, 2), [2, 4, 5]);
    });

    test('pages continue the columns', () {
      // Two columns per page: blocks 0-1 and 2-3 on the first page.
      expect(songPages([1, 1, 1, 1, 1, 1], 2, 2), [4, 6]);
    });

    test('does not fit when a block is taller than the page', () {
      expect(songPages([1, 3, 1], 1, 2), isNull);
      expect(songPages([1, 1, 1, 1], 1, 1, maxPages: 3), isNull);
    });
  });

  group('buildSongBlocks', () {
    final song = parseChordPro(demoSongSource);

    test('repeats the chorus in full by default', () {
      final blocks = buildSongBlocks(
        song,
        lyricsOnly: false,
        labeler: _labeler,
      );
      expect(blocks.where((b) => b.isRecallLabel), isEmpty);
      expect(
        blocks.where((b) => b.section?.kind == SectionKind.chorus),
        hasLength(3),
      );
    });

    test('collapses repeated choruses to labels', () {
      final blocks = buildSongBlocks(
        song,
        lyricsOnly: false,
        labeler: _labeler,
        collapseRecalls: true,
      );
      expect(blocks.where((b) => b.isRecallLabel), hasLength(2));
    });

    test('notes come first', () {
      final blocks = buildSongBlocks(
        song,
        lyricsOnly: false,
        labeler: _labeler,
        notes: 'Hi',
      );
      expect(blocks.first.text, 'Hi');
    });
  });

  group('fitSong', () {
    final song = parseChordPro(demoSongSource);
    final formatter = ChordFormatter.forSong(song);

    SongFit fit(
      Size size, {
      int maxColumns = 4,
      ChorusRepeat chorus = ChorusRepeat.auto,
      int maxPages = 1,
    }) => fitSong(
      song,
      formatter: formatter,
      lyricsOnly: false,
      labeler: _labeler,
      baseFontSize: 20,
      maxFontSize: 40,
      minFontSize: 12,
      size: size,
      textScaler: TextScaler.noScaling,
      maxColumns: maxColumns,
      chorusRepeat: chorus,
      maxPages: maxPages,
    );

    test('fits a long song on a landscape tablet using columns', () {
      final result = fit(const Size(1240, 680));
      expect(result.fits, isTrue);
      expect(result.columns, greaterThan(1));
    });

    test('result fits within the screen height', () {
      const size = Size(1240, 680);
      final result = fit(size);
      final blocks = buildSongBlocks(
        song,
        lyricsOnly: false,
        labeler: _labeler,
        collapseRecalls: result.collapseRecalls,
      );
      final metrics = measureBlocks(
        blocks,
        formatter: formatter,
        lyricsOnly: false,
        textScaler: TextScaler.noScaling,
      );
      final width = columnWidth(size.width, result.columns, result.fontSize);
      final heights = [
        for (final m in metrics) m.height(result.fontSize, width),
      ];
      expect(
        partitionHeight(heights, result.columns),
        lessThanOrEqualTo(size.height),
      );
    });

    /// [verses] verses of short chord lines: the height limits the font.
    SongFit fitVerses(int verses, {required int maxPages}) {
      final long = parseChordPro(
        '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}',
      );
      return fitSong(
        long,
        formatter: ChordFormatter.forSong(long),
        lyricsOnly: false,
        labeler: _labeler,
        baseFontSize: 20,
        maxFontSize: 40,
        minFontSize: 12,
        size: const Size(1240, 680),
        textScaler: TextScaler.noScaling,
        maxPages: maxPages,
      );
    }

    test('splits a long song into pages for a clearly larger font', () {
      final one = fitVerses(16, maxPages: 1);
      final paged = fitVerses(16, maxPages: 4);
      expect(one.pages, 1);
      expect(paged.fits, isTrue);
      expect(paged.pages, 2);
      expect(paged.fontSize, greaterThan(one.fontSize / pagePenalty));
    });

    test('another page only when clearly better', () {
      final one = fitVerses(12, maxPages: 1);
      expect(one.fontSize, lessThan(20));
      final paged = fitVerses(12, maxPages: 4);
      expect(paged.pages, 1);
      expect(paged.fontSize, one.fontSize);
    });

    test('a song limited by its line width stays on one page', () {
      final paged = fit(const Size(1240, 680), maxPages: 4);
      expect(paged.pages, 1);
      expect(paged.fontSize, fit(const Size(1240, 680)).fontSize);
    });

    test('respects the maximum number of columns', () {
      expect(fit(const Size(1240, 680), maxColumns: 1).columns, 1);
      expect(
        fit(const Size(1240, 680), maxColumns: 2).columns,
        lessThanOrEqualTo(2),
      );
    });

    test('chorus setting full never collapses, label always does', () {
      expect(
        fit(const Size(400, 300), chorus: ChorusRepeat.full).collapseRecalls,
        isFalse,
      );
      expect(
        fit(const Size(1240, 680), chorus: ChorusRepeat.label).collapseRecalls,
        isTrue,
      );
    });

    test('long lines without chords wrap instead of shrinking the font', () {
      final withFooter = parseChordPro(
        '$demoSongSource\n\n${'Copyright notice with a very long text. ' * 8}',
      );
      final result = fitSong(
        withFooter,
        formatter: ChordFormatter.forSong(withFooter),
        lyricsOnly: false,
        labeler: _labeler,
        baseFontSize: 20,
        maxFontSize: 40,
        minFontSize: 12,
        size: const Size(1240, 680),
        textScaler: TextScaler.noScaling,
      );
      expect(result.fits, isTrue);
      expect(result.columns, greaterThan(1));
      expect(result.fontSize, greaterThan(14));
    });

    test('falls back to scrolling when nothing fits', () {
      final result = fit(const Size(300, 120));
      expect(result.fits, isFalse);
      expect(result.columns, 1);
      expect(result.fontSize, greaterThanOrEqualTo(12));
    });
  });

  group('scrollColumns', () {
    BlockMetrics block(double height, {double minWidth = 5}) => BlockMetrics(
      fixedHeight: height,
      wrapping: const [],
      minWidth: minWidth,
    );
    SongLayout layout(List<BlockMetrics> metrics) => (
      blocks: [for (final _ in metrics) SongBlock.notes('x')],
      metrics: metrics,
    );

    test('uses the fewest columns with which the song fits', () {
      // Four blocks of 200 px at 20 px.
      final song = layout(List.filled(4, block(10)));
      int columns(double height) =>
          scrollColumns(song, fontSize: 20, size: Size(1200, height));
      expect(columns(800), 1);
      expect(columns(400), 2);
      expect(columns(200), 4);
    });

    test('scrolls with as many columns as the width allows', () {
      final song = layout(List.filled(8, block(10)));
      const short = Size(1200, 100);
      expect(scrollColumns(song, fontSize: 20, size: short), 4);
      expect(scrollColumns(song, fontSize: 20, size: short, maxColumns: 2), 2);
      // Columns narrower than the minimum width: one column.
      expect(scrollColumns(song, fontSize: 20, size: const Size(400, 100)), 1);
      // Chord lines of 500 px fit two columns of 1200 px, not three.
      final wide = layout(List.filled(8, block(10, minWidth: 25)));
      expect(scrollColumns(wide, fontSize: 20, size: short), 2);
    });

    test('breaks in the song decide the columns when they fit', () {
      final blocks = buildSongBlocks(
        parseChordPro(
          '{start_of_verse}\n[C]One\n{end_of_verse}\n{column_break}\n'
          '{start_of_verse}\n[G]Two\n{end_of_verse}',
        ),
        lyricsOnly: false,
        labeler: _labeler,
      );
      final song = (
        blocks: blocks,
        metrics: [for (final _ in blocks) block(10)],
      );
      expect(scrollColumns(song, fontSize: 20, size: const Size(1200, 50)), 2);
      expect(scrollColumns(song, fontSize: 20, size: const Size(400, 50)), 1);
    });
  });
}
