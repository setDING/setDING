import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import 'chord_diagram.dart';
import 'abc_view.dart';
import 'song_blocks.dart';
import 'song_delegates.dart';
import 'song_image.dart';
import 'song_grid.dart';
import 'song_style.dart';
import '../../settings/display_options.dart';
export '../../settings/display_options.dart' show ChorusRepeat;

// Layout measurement ----------------------------------------------------------
//
// Mirrors the widgets in song_view.dart. Sizes are stored per unit of font
// size; text widths are measured once with TextPainter at a reference size
// using the same styles (song_style.dart). Lines without chords (plain
// lyrics, comments, notes) may wrap; chord lines, tabs, grids and labels
// must fit the column width.

const _referenceFontSize = 20.0;

/// Share of the computed font size that [fitSong] uses: room for what the
/// measurement does not model exactly, e.g. text lines rounded up to whole
/// pixels (about 1 %).
const fitSafety = 0.98;

/// Spacing between chord diagrams, relative to the font size.
const diagramSpacing = 0.8;
const diagramRunSpacing = 0.6;

/// Size information of a [SongBlock], independent of the font size.
class BlockMetrics {
  const BlockMetrics({
    required this.fixedHeight,
    required this.wrapping,
    required this.minWidth,
    this.indent = 0,
    this.images = const [],
    this.custom = const [],
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

  /// Images that shrink to the column width.
  final List<ImageBox> images;

  /// Content with its own layout: height in pixels for (font size, column
  /// width), e.g. ABC notation that breaks at bar lines.
  final List<double Function(double fontSize, double columnWidth)> custom;

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
    final available = columnWidth - indent * f;
    for (final image in images) {
      h += image.height(f, available) + 2 * SongSpacing.lineItemPadding * f;
    }
    for (final part in custom) {
      h += part(f, available);
    }
    return h;
  }
}

/// Number of [measureBlocks] calls, for tests of the render caches.
int debugMeasureBlocksCalls = 0;

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
  DiagramResolver? diagramResolver,
  ImageLookup? imageLookup,
}) {
  debugMeasureBlocksCalls++;
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
        _measure(
          b,
          formatter,
          lyricsOnly,
          painter,
          styles,
          diagramResolver,
          imageLookup,
        ),
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
  DiagramResolver? diagramResolver,
  ImageLookup? imageLookup,
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

  final delegate = block.delegate;
  if (delegate != null) {
    return _measureDelegate(
      delegate,
      block,
      styles,
      width,
      spanWidth,
      lineUnits,
      formatter.transpose + formatter.leadingTranspose,
    );
  }

  final diagrams = block.diagrams;
  if (diagrams != null) {
    // Diagrams wrap in rows; modelled as one wrapping "line".
    final tallest = diagrams.fold<double>(
      0,
      (h, d) => math.max(h, d.heightUnits),
    );
    return BlockMetrics(
      fixedHeight: SongSpacing.diagramsBlockGap - diagramRunSpacing,
      wrapping: [
        (
          width: diagrams.fold<double>(
            0,
            (w, d) => w + d.widthUnits + diagramSpacing,
          ),
          lineHeight: tallest + diagramRunSpacing,
          padding: 0,
        ),
      ],
      minWidth: diagrams.fold<double>(0, (w, d) => math.max(w, d.widthUnits)),
    );
  }

  if (block.text != null) {
    // Notes card: margin, padding; the text wraps next to the icon.
    final noteStyle = styles.lyrics.copyWith(
      fontSize: f * SongSpacing.smallText,
    );
    return BlockMetrics(
      fixedHeight: SongSpacing.blockGap + 2 * SongSpacing.notesPadding,
      wrapping: [
        (
          width: width(block.text!, noteStyle),
          lineHeight: SongSpacing.smallText * lh,
          padding:
              2 * SongSpacing.notesPadding +
              SongSpacing.notesIcon +
              SongSpacing.notesIconGap,
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
          SongSpacing.blockGap +
          math.max(
            _labelLines(block.label!) * lineUnits(labelStyle),
            SongSpacing.recallIcon,
          ),
      wrapping: const [],
      minWidth:
          SongSpacing.recallIcon +
          SongSpacing.iconGap +
          _labelWidth(block.label!, labelStyle, spanWidth),
    );
  }

  final chorus = block.isChorus;
  final indent = chorus
      ? SongSpacing.chorusIndent + SongSpacing.chorusBorderPixels / f
      : 0.0;
  var fixed = SongSpacing.blockGap;
  var minWidth = 0.0;
  final wrapping = <({double width, double lineHeight, double padding})>[];
  if (block.label != null) {
    fixed += _labelLines(block.label!) * lineUnits(labelStyle);
    minWidth = _labelWidth(block.label!, labelStyle, spanWidth);
  }

  GridGeometry? grid;
  final images = <ImageBox>[];
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
                  SongSpacing.chordGap * (lyric.fontSize ?? f) / f,
            );
          }
          lineWidth += w;
        }
        fixed +=
            SongSpacing.chordLineTop * (lyric.fontSize ?? f) / f +
            lineUnits(chord) +
            tallestLyric;
        minWidth = math.max(minWidth, lineWidth);
      case LyricLine l:
        final lyric = styles.lyricsFor(format, inChorus: chorus);
        wrapping.add((
          width: spanWidth(markupSpan(l.text, lyric, forMeasuring: true)),
          lineHeight: lineUnits(lyric) * markupSizeFactor(l.text),
          padding: 0,
        ));
      case CommentLine c:
        // The comment's spacing scales with its text size (song_view.dart).
        final base = (styles.lyricsFor(format).fontSize ?? f) / f;
        final style = styles
            .lyricsFor(format)
            .copyWith(
              fontSize: base * f * SongSpacing.smallText,
              fontStyle: c.style == CommentStyle.italic
                  ? FontStyle.italic
                  : null,
            );
        fixed +=
            base *
            2 *
            (SongSpacing.commentMargin + SongSpacing.commentPaddingVertical);
        wrapping.add((
          width: spanWidth(markupSpan(c.text, style, forMeasuring: true)),
          lineHeight: lineUnits(style) * markupSizeFactor(c.text),
          padding: base * 2 * SongSpacing.commentPaddingHorizontal,
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
      case ImageLine i when resolveImage(i, imageLookup) != null:
        images.add(resolveImage(i, imageLookup)!.$2);
      case ChordDiagramLine c
          when diagramResolver?.forDefinition(c.definition) != null:
        final data = diagramResolver!.forDefinition(c.definition)!;
        fixed += data.heightUnits + 2 * SongSpacing.lineItemPadding;
        minWidth = math.max(minWidth, data.widthUnits);
      case ImageLine() || ChordDiagramLine():
        // Placeholder: icon (one unit) or label, whichever is taller.
        fixed +=
            2 * SongSpacing.lineItemPadding +
            math.max(lineUnits(labelStyle), 1.0);
      case BreakLine():
        break;
      case EmptyLine():
        fixed += SongSpacing.emptyLine;
    }
  }
  return BlockMetrics(
    fixedHeight: fixed,
    wrapping: wrapping,
    minWidth: minWidth + indent,
    indent: indent,
    images: images,
  );
}

BlockMetrics _measureDelegate(
  DelegateSection d,
  SongBlock block,
  SongTextStyles styles,
  double Function(String, TextStyle) width,
  double Function(InlineSpan) spanWidth,
  double Function(TextStyle) lineUnits,
  int transpose,
) {
  const f = _referenceFontSize;
  final format = block.startFormat;
  final abc = d.type == DelegateType.abc ? abcTuneOf(d, transpose) : null;
  final title = d.label ?? abc?.title;
  final labelStyle = styles.labelFor(format);
  var fixed = SongSpacing.blockGap;
  var minWidth = 0.0;
  if (title != null) {
    fixed += _labelLines(title) * lineUnits(labelStyle);
    minWidth = _labelWidth(title, labelStyle, spanWidth);
  }
  switch (d.type) {
    case DelegateType.abc:
      // Lines break at bar lines exactly as when rendering.
      return BlockMetrics(
        fixedHeight: fixed,
        wrapping: const [],
        minWidth: minWidth,
        custom: [(f, width) => abcHeight(abc!, f, width)],
      );
    case DelegateType.svg:
      return BlockMetrics(
        fixedHeight: fixed,
        wrapping: const [],
        minWidth: minWidth,
        images: [svgDelegateBox(d)],
      );
    case DelegateType.textblock:
      final block = TextBlockStyle.of(d.attributes);
      final lyric = styles.lyricsFor(format);
      final text = lyric.copyWith(
        fontSize: (lyric.fontSize ?? f) * block.sizeFactor,
      );
      return BlockMetrics(
        fixedHeight: fixed + 2 * block.paddingUnits,
        wrapping: [
          for (final line in d.lines)
            (
              width: spanWidth(markupSpan(line, text, forMeasuring: true)),
              lineHeight: lineUnits(text) * markupSizeFactor(line),
              padding: 2 * block.paddingUnits,
            ),
        ],
        minWidth: minWidth,
      );
    case DelegateType.ly:
      final mono = styles.tabFor(format);
      // Same style as the notice in song_delegates.dart.
      final notice = styles
          .lyricsFor(format)
          .copyWith(fontSize: mono.fontSize, fontStyle: FontStyle.italic);
      final monoSize = (mono.fontSize ?? f) / f;
      var widest = 0.0;
      for (final line in d.lines) {
        final w = width(line, mono);
        if (w > widest) widest = w;
      }
      return BlockMetrics(
        fixedHeight:
            fixed + monoSize * (1.0 + 0.4) + d.lines.length * lineUnits(mono),
        wrapping: [
          (
            width: width(
              'Lilypond notation cannot be rendered on this device. Source:',
              notice,
            ),
            lineHeight: lineUnits(notice),
            padding: monoSize + 2 / f,
          ),
        ],
        minWidth: [
          minWidth,
          widest + monoSize + 2 / f,
        ].reduce((a, b) => a > b ? a : b),
      );
  }
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

/// The blocks of [song] with their measurements, as [SongBody] would build
/// and measure them for the same options (to cache them, see
/// `SongRenderOptions.layout`).
SongLayout layoutSong(
  Song song, {
  required ChordFormatter formatter,
  required bool lyricsOnly,
  required SectionLabeler labeler,
  String? notes,
  bool collapseRecalls = false,
  DiagramResolver? diagramResolver,
  DiagramsPosition diagramsPosition = DiagramsPosition.off,
  required TextScaler textScaler,
  TextStyle? baseStyle,
  ImageLookup? imageLookup,
}) {
  final blocks = buildSongBlocks(
    song,
    lyricsOnly: lyricsOnly,
    labeler: labeler,
    notes: notes,
    collapseRecalls: collapseRecalls,
    diagrams:
        diagramsPosition == DiagramsPosition.off || diagramResolver == null
        ? const []
        : diagramResolver.allChords(),
    diagramsOnTop: diagramsPosition == DiagramsPosition.top,
  );
  return (
    blocks: blocks,
    metrics: measureBlocks(
      blocks,
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      textScaler: textScaler,
      baseStyle: baseStyle,
      diagramResolver: diagramResolver,
      imageLookup: imageLookup,
    ),
  );
}

/// Result of [fitSong].
class SongFit {
  const SongFit({
    required this.fontSize,
    required this.columns,
    this.collapseRecalls = false,
    this.fits = true,
    this.layout,
  });

  final double fontSize;
  final int columns;
  final bool collapseRecalls;

  /// Blocks and measurements of the chosen arrangement, so that rendering
  /// does not build and measure them again (see `SongRenderOptions.layout`);
  /// null when the song does not fit.
  final SongLayout? layout;

  /// Whether the whole song fits on the screen without scrolling.
  final bool fits;
}

/// Blocks of a song with their measurements.
typedef SongLayout = ({List<SongBlock> blocks, List<BlockMetrics> metrics});

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
  ImageLookup? imageLookup,
  int minColumns = 1,
  int maxColumns = 4,
  double minColumnWidth = 220,
  ChorusRepeat chorusRepeat = ChorusRepeat.auto,
  DiagramResolver? diagramResolver,
  DiagramsPosition diagramsPosition = DiagramsPosition.off,
}) {
  final diagrams =
      diagramsPosition == DiagramsPosition.off || diagramResolver == null
      ? const <DiagramData>[]
      : diagramResolver.allChords();
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
      diagrams: diagrams,
      diagramsOnTop: diagramsPosition == DiagramsPosition.top,
    );
    if (blocks.isEmpty) return SongFit(fontSize: baseFontSize, columns: 1);
    final metrics = measureBlocks(
      blocks,
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      textScaler: textScaler,
      baseStyle: baseStyle,
      diagramResolver: diagramResolver,
      imageLookup: imageLookup,
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
      font *= fitSafety;
      // Prefer fewer columns and full choruses unless clearly better.
      final penalty = collapse && chorusRepeat == ChorusRepeat.auto
          ? 0.85
          : 1.0;
      final score = font * penalty * (1 - 0.03 * (k - 1));
      if (score > bestScore) {
        bestScore = score;
        best = SongFit(
          fontSize: font,
          columns: k,
          collapseRecalls: collapse,
          layout: (blocks: blocks, metrics: metrics),
        );
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
