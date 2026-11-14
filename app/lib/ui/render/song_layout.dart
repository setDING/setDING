import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import 'song_blocks.dart';
import 'song_grid.dart';
import 'song_style.dart';

// Layout measurement ----------------------------------------------------------
//
// Mirrors the widgets in song_view.dart. Sizes are stored per unit of font
// size; text widths are measured once with TextPainter at a reference size
// using the same styles (song_style.dart). Lines without chords (plain
// lyrics, comments, notes) may wrap; chord lines, tabs, grids and labels
// must fit the column width.

const _referenceFontSize = 20.0;

/// Size information of a [SongBlock], independent of the font size.
class BlockMetrics {
  const BlockMetrics({
    required this.fixedHeight,
    required this.wrapping,
    required this.minWidth,
    this.indent = 0,
  });

  /// Height of everything that never wraps, per unit of font size.
  final double fixedHeight;

  /// Lines that may wrap: text width, line height and horizontal padding,
  /// each per unit of font size.
  final List<({double width, double lineHeight, double padding})> wrapping;

  /// Widest content that must not wrap, per unit of font size.
  final double minWidth;

  /// Left indent (chorus border), per unit of font size.
  final double indent;

  /// Height at [fontSize] in a column of [columnWidth] logical pixels.
  double height(double fontSize, double columnWidth) {
    final f = fontSize;
    var h = fixedHeight * f;
    for (final line in wrapping) {
      final available = columnWidth - (indent + line.padding) * f;
      final count = available <= 0
          ? 1
          : math.max(1, (line.width * f * 1.05 / available).ceil());
      h += count * line.lineHeight * f;
    }
    return h;
  }
}

/// Measures [blocks] for layout.
///
/// [baseStyle] must be the default text style the song is rendered with
/// (`DefaultTextStyle.of(context).style`), so the same font is measured.
List<BlockMetrics> measureBlocks(
  List<SongBlock> blocks, {
  required ChordFormatter formatter,
  required bool lyricsOnly,
  required TextScaler textScaler,
  TextStyle? baseStyle,
}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );
  final styles = SongTextStyles.fromBase(
    baseStyle ?? const TextStyle(),
    _referenceFontSize,
  );
  try {
    return [
      for (final b in blocks)
        _measure(b, formatter, lyricsOnly, painter, styles),
    ];
  } finally {
    painter.dispose();
  }
}

BlockMetrics _measure(
  SongBlock block,
  ChordFormatter formatter,
  bool lyricsOnly,
  TextPainter painter,
  SongTextStyles styles,
) {
  const f = _referenceFontSize;
  const lh = SongTextStyles.lineHeightFactor;

  /// Width of a span in units of [f].
  double spanWidth(InlineSpan span) {
    painter.text = span;
    painter.layout();
    return painter.width / f;
  }

  double width(String text, TextStyle style) =>
      spanWidth(TextSpan(text: text, style: style));

  /// Height factor (per unit of f) of a style's line.
  double lineUnits(TextStyle style) => (style.fontSize ?? f) * lh / f;

  if (block.text != null) {
    // Notes card: margin, padding; the text wraps next to the icon.
    final noteStyle = styles.lyrics.copyWith(fontSize: f * 0.85);
    return BlockMetrics(
      fixedHeight: 0.8 + 1.0,
      wrapping: [
        (
          width: width(block.text!, noteStyle),
          lineHeight: 0.85 * lh,
          padding: 1.0 + 1.0 + 0.4,
        ),
      ],
      minWidth: 0,
    );
  }

  final format = block.startFormat.copy();
  final labelStyle = styles.labelFor(format);
  if (block.isRecallLabel) {
    return BlockMetrics(
      fixedHeight:
          0.8 +
          math.max(_labelLines(block.label!) * lineUnits(labelStyle), 0.9),
      wrapping: const [],
      minWidth: 1.2 + _labelWidth(block.label!, labelStyle, spanWidth),
    );
  }

  final chorus = block.isChorus;
  final indent = chorus ? 0.6 + 3 / f : 0.0;
  var fixed = 0.8;
  var minWidth = 0.0;
  final wrapping = <({double width, double lineHeight, double padding})>[];
  if (block.label != null) {
    fixed += _labelLines(block.label!) * lineUnits(labelStyle);
    minWidth = _labelWidth(block.label!, labelStyle, spanWidth);
  }

  GridGeometry? grid;
  for (final line in block.lines) {
    switch (line) {
      case FormatLine l:
        format.apply(l);
      case LyricLine l when !lyricsOnly && l.hasChords:
        final lyric = styles.lyricsFor(format, inChorus: chorus);
        final chord = styles.chordFor(format);
        final pieces = chordLinePieces(l, formatter);
        var lineWidth = 0.0;
        var tallestLyric = lineUnits(lyric);
        for (final p in pieces) {
          var w = p.runs.isEmpty
              ? width(' ', lyric)
              : spanWidth(
                  TextSpan(
                    children: [
                      for (final r in p.runs) runSpan(r, lyric, (s) => s, true),
                    ],
                  ),
                );
          for (final r in p.runs) {
            final size = applyMarkupStyle(lyric, r.style).fontSize ?? f;
            tallestLyric = math.max(tallestLyric, size * lh / f);
          }
          if (p.chord != null) {
            w = math.max(
              w,
              width(p.chord!, applyMarkupStyle(chord, p.chordMarkup)) +
                  0.35 * (lyric.fontSize ?? f) / f,
            );
          }
          lineWidth += w;
        }
        fixed += 0.1 + lineUnits(chord) + tallestLyric;
        minWidth = math.max(minWidth, lineWidth);
      case LyricLine l:
        final lyric = styles.lyricsFor(format, inChorus: chorus);
        wrapping.add((
          width: spanWidth(markupSpan(l.text, lyric, forMeasuring: true)),
          lineHeight: lineUnits(lyric) * markupSizeFactor(l.text),
          padding: 0,
        ));
      case CommentLine c:
        final style = styles
            .lyricsFor(format)
            .copyWith(
              fontSize: (styles.lyricsFor(format).fontSize ?? f) * 0.85,
              fontStyle: c.style == CommentStyle.italic
                  ? FontStyle.italic
                  : null,
            );
        fixed += 0.3 + 0.2;
        wrapping.add((
          width: spanWidth(markupSpan(c.text, style, forMeasuring: true)),
          lineHeight: lineUnits(style) * markupSizeFactor(c.text),
          padding: 0.8,
        ));
      case RawLine r:
        final style = styles.tabFor(format);
        fixed += lineUnits(style);
        minWidth = math.max(minWidth, width(r.text, style));
      case GridLine g:
        final text = styles.gridFor(format);
        final chordStyle = styles.gridChordFor(format);
        final size = text.fontSize ?? f;
        double gridWidth(String s, {bool chord = false}) =>
            width(s, chord ? chordStyle : text) * f / size;
        grid ??= GridGeometry.of(block.lines, formatter, gridWidth);
        fixed += GridGeometry.rowHeight * size / f;
        minWidth = math.max(
          minWidth,
          grid.rowWidth(g.row, formatter, gridWidth) * size / f,
        );
      case ImageLine() || ChordDiagramLine():
        fixed += 0.3 + math.max(lineUnits(labelStyle), 1.0);
      case BreakLine():
        break;
      case EmptyLine():
        fixed += 0.6;
    }
  }
  return BlockMetrics(
    fixedHeight: fixed,
    wrapping: wrapping,
    minWidth: minWidth + indent,
    indent: indent,
  );
}

int _labelLines(String label) => '\n'.allMatches(label).length + 1;

double _labelWidth(
  String label,
  TextStyle style,
  double Function(InlineSpan) spanWidth,
) {
  var widest = 0.0;
  for (final line in label.split('\n')) {
    widest = math.max(
      widest,
      spanWidth(
        markupSpan(
          line,
          style,
          transform: (s) => s.toUpperCase(),
          forMeasuring: true,
        ),
      ),
    );
  }
  return widest;
}

/// Result of [fitSong].
class SongFit {
  const SongFit({
    required this.fontSize,
    required this.columns,
    this.collapseRecalls = false,
    this.fits = true,
  });

  final double fontSize;
  final int columns;
  final bool collapseRecalls;

  /// Whether the whole song fits on the screen without scrolling.
  final bool fits;
}

/// How a repeated chorus (`{chorus}`) is shown in live mode.
enum ChorusRepeat {
  /// Full lines, shortened to a label only if that is needed to fit.
  auto,

  /// Always the full lines.
  full,

  /// Always a label only.
  label,
}

/// Chooses font size, number of columns and chorus display for live mode so
/// that the whole song fits into [size] without scrolling.
///
/// Sections are kept whole and distributed over [minColumns] to
/// [maxColumns] columns in reading order; `{column_break}` and `{new_page}`
/// in the song decide the columns themselves. Chord lines must fit the
/// column width; lines without chords may wrap. The arrangement with the
/// largest font wins; more columns are only used when they give a clearly
/// larger font, and repeated choruses are only collapsed to a label when
/// that gives a clearly larger font. If nothing fits at [minFontSize], one
/// scrollable column is returned.
SongFit fitSong(
  Song song, {
  required ChordFormatter formatter,
  required bool lyricsOnly,
  required SectionLabeler labeler,
  String? notes,
  required double baseFontSize,
  required double maxFontSize,
  required double minFontSize,
  required Size size,
  required TextScaler textScaler,
  TextStyle? baseStyle,
  int minColumns = 1,
  int maxColumns = 4,
  double minColumnWidth = 220,
  ChorusRepeat chorusRepeat = ChorusRepeat.auto,
}) {
  SongFit? best;
  double bestScore = 0;
  double? singleColumnFont;

  final collapseOptions = switch (chorusRepeat) {
    ChorusRepeat.auto => const [false, true],
    ChorusRepeat.full => const [false],
    ChorusRepeat.label => const [true],
  };
  for (final collapse in collapseOptions) {
    final blocks = buildSongBlocks(
      song,
      lyricsOnly: lyricsOnly,
      labeler: labeler,
      notes: notes,
      collapseRecalls: collapse,
    );
    if (blocks.isEmpty) return SongFit(fontSize: baseFontSize, columns: 1);
    final metrics = measureBlocks(
      blocks,
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      textScaler: textScaler,
      baseStyle: baseStyle,
    );
    final widest = metrics.fold<double>(0, (w, m) => math.max(w, m.minWidth));
    singleColumnFont ??= widest <= 0 ? maxFontSize : size.width / widest;

    final forced = forcedColumns(blocks);
    final lowest = forced ?? math.min(minColumns, blocks.length);
    final highest = forced ?? math.min(maxColumns, blocks.length);
    for (var k = lowest; k <= highest; k++) {
      if (forced == null &&
          k > 1 &&
          columnWidth(size.width, k, baseFontSize) < minColumnWidth) {
        continue;
      }
      // Start with the largest font the width allows, then shrink until the
      // tallest column fits (wrapping changes with the font size).
      var font = widest <= 0
          ? maxFontSize
          : size.width / (k * widest + columnGap * (k - 1));
      font = math.min(font, maxFontSize);
      var fits = false;
      for (var i = 0; i < 12 && font >= minFontSize; i++) {
        final width = columnWidth(size.width, k, font);
        final heights = [for (final m in metrics) m.height(font, width)];
        final tallest = tallestColumn(
          heights,
          columnBreaks(blocks, heights, k),
        );
        if (tallest <= size.height) {
          fits = true;
          break;
        }
        font *= size.height / tallest * 0.99;
      }
      if (!fits) continue;
      font *= 0.98;
      // Prefer fewer columns and full choruses unless clearly better.
      final penalty = collapse && chorusRepeat == ChorusRepeat.auto
          ? 0.85
          : 1.0;
      final score = font * penalty * (1 - 0.03 * (k - 1));
      if (score > bestScore) {
        bestScore = score;
        best = SongFit(fontSize: font, columns: k, collapseRecalls: collapse);
      }
    }
  }

  if (best != null) return best;
  // Does not fit: one column, as large as the width allows, scrollable.
  return SongFit(
    fontSize: (singleColumnFont ?? baseFontSize).clamp(
      minFontSize,
      maxFontSize,
    ),
    columns: 1,
    collapseRecalls: chorusRepeat == ChorusRepeat.label,
    fits: false,
  );
}
