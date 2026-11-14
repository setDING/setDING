import 'package:bandchords/data/demo_song.dart';
import 'package:bandchords/ui/render/song_view.dart';
import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
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
      final heights = [
        for (final b in blocks)
          blockHeight(b, lyricsOnly: false, fontSize: result.fontSize),
      ];
      expect(
        partitionHeight(heights, result.columns),
        lessThanOrEqualTo(size.height),
      );
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

    test('falls back to scrolling when nothing fits', () {
      final result = fit(const Size(300, 120));
      expect(result.fits, isFalse);
      expect(result.columns, 1);
      expect(result.fontSize, greaterThanOrEqualTo(12));
    });
  });
}
