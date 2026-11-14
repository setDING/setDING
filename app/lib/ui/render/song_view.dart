import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Options for rendering a song (combined layers of ADR-0006).
class SongRenderOptions {
  const SongRenderOptions({
    required this.formatter,
    this.lyricsOnly = false,
    this.fontSize = 20,
    this.columns = 1,
    this.notes,
    this.collapseRecalls = false,
  });

  final ChordFormatter formatter;
  final bool lyricsOnly;
  final double fontSize;
  final int columns;
  final String? notes;

  /// Show a repeated chorus as a label only.
  final bool collapseRecalls;

  SongRenderOptions copyWith({double? fontSize, int? columns}) =>
      SongRenderOptions(
        formatter: formatter,
        lyricsOnly: lyricsOnly,
        fontSize: fontSize ?? this.fontSize,
        columns: columns ?? this.columns,
        notes: notes,
        collapseRecalls: collapseRecalls,
      );
}

/// A unit of the song layout that is placed as a whole into a column.
class SongBlock {
  const SongBlock.notes(String this.text)
    : section = null,
      label = null,
      lines = const [],
      isRecallLabel = false;

  const SongBlock.section(Section this.section, this.label, this.lines)
    : text = null,
      isRecallLabel = false;

  const SongBlock.recall(String this.label)
    : section = null,
      text = null,
      lines = const [],
      isRecallLabel = true;

  /// Personal note text (notes block).
  final String? text;
  final Section? section;
  final String? label;
  final List<Line> lines;

  /// A repeated chorus shown only as a label.
  final bool isRecallLabel;
}

/// Default label for a section kind (localized), or null for none.
typedef SectionLabeler = String? Function(SectionKind kind);

SectionLabeler sectionLabeler(AppLocalizations l10n) =>
    (kind) => switch (kind) {
      SectionKind.verse => l10n.sectionVerse,
      SectionKind.chorus => l10n.sectionChorus,
      SectionKind.bridge => l10n.sectionBridge,
      SectionKind.tab => l10n.sectionTab,
      SectionKind.grid => l10n.sectionGrid,
      SectionKind.none || SectionKind.custom => null,
    };

/// Splits [song] into layout blocks.
///
/// With [collapseRecalls], a repeated chorus (`{chorus}`) is shown as a
/// label only instead of repeating its lines, to save space in live mode.
List<SongBlock> buildSongBlocks(
  Song song, {
  required bool lyricsOnly,
  required SectionLabeler labeler,
  String? notes,
  bool collapseRecalls = false,
}) {
  List<Line> visible(Section s) => lyricsOnly
      ? s.lines
            .where((l) => l is! LyricLine || l.text.trim().isNotEmpty)
            .toList()
      : s.lines;

  final blocks = <SongBlock>[];
  final note = notes?.trim();
  if (note != null && note.isNotEmpty) blocks.add(SongBlock.notes(note));
  final chorusLabel = labeler(SectionKind.chorus) ?? 'Chorus';

  for (final element in song.elements) {
    switch (element) {
      case Section s:
        final label = s.label ?? labeler(s.kind);
        final lines = visible(s);
        if (lines.isEmpty && label == null) continue;
        blocks.add(SongBlock.section(s, label, lines));
      case ChorusRecall r:
        final chorus = r.chorus;
        final label = r.label ?? chorus?.label ?? chorusLabel;
        if (chorus == null || collapseRecalls) {
          blocks.add(SongBlock.recall(label));
        } else {
          blocks.add(SongBlock.section(chorus, label, visible(chorus)));
        }
    }
  }
  return blocks;
}

/// Renders the body of a ChordPro song: sections with chords above lyrics,
/// arranged in [SongRenderOptions.columns] columns.
class SongBody extends StatelessWidget {
  const SongBody({super.key, required this.song, required this.options});

  final Song song;
  final SongRenderOptions options;

  @override
  Widget build(BuildContext context) {
    final style = SongTextStyles.of(context, options.fontSize);
    final blocks = buildSongBlocks(
      song,
      lyricsOnly: options.lyricsOnly,
      labeler: sectionLabeler(AppLocalizations.of(context)),
      notes: options.notes,
      collapseRecalls: options.collapseRecalls,
    );
    Widget render(SongBlock b) => b.text != null
        ? _NotesCard(text: b.text!, style: style)
        : b.isRecallLabel
        ? _RecallLabel(text: b.label!, style: style)
        : _SectionBlock(
            section: b.section!,
            label: b.label,
            lines: b.lines,
            options: options,
            style: style,
          );

    final columns = math.min(options.columns, blocks.length);
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final b in blocks) render(b)],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = columnWidth(
          constraints.maxWidth,
          columns,
          options.fontSize,
        );
        final metrics = measureBlocks(
          blocks,
          formatter: options.formatter,
          lyricsOnly: options.lyricsOnly,
          textScaler: MediaQuery.textScalerOf(context),
          baseStyle: DefaultTextStyle.of(context).style,
        );
        final heights = [
          for (final m in metrics) m.height(options.fontSize, width),
        ];
        final breaks = [...partitionColumns(heights, columns), blocks.length];
        final children = <Widget>[];
        var start = 0;
        for (final end in breaks) {
          if (start > 0) {
            children.add(SizedBox(width: options.fontSize * columnGap));
          }
          children.add(
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in blocks.sublist(start, end)) render(b),
                ],
              ),
            ),
          );
          start = end;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}

/// Gap between columns, relative to the font size.
const columnGap = 1.5;

/// Splits ordered [heights] into at most [columns] consecutive groups so that
/// the tallest group is as short as possible. Returns the end index of each
/// group except the last.
List<int> partitionColumns(List<double> heights, int columns) {
  final n = heights.length;
  final k = math.min(columns, n);
  if (k <= 1) return const [];
  final prefix = [0.0];
  for (final h in heights) {
    prefix.add(prefix.last + h);
  }

  // best[j][i]: minimal tallest group for the first i heights in j groups.
  final best = List.generate(k + 1, (_) => List.filled(n + 1, double.infinity));
  final cut = List.generate(k + 1, (_) => List.filled(n + 1, 0));
  best[0][0] = 0;
  for (var j = 1; j <= k; j++) {
    for (var i = j; i <= n; i++) {
      for (var p = j - 1; p < i; p++) {
        final value = math.max(best[j - 1][p], prefix[i] - prefix[p]);
        if (value < best[j][i]) {
          best[j][i] = value;
          cut[j][i] = p;
        }
      }
    }
  }
  final breaks = <int>[];
  var i = n;
  for (var j = k; j > 1; j--) {
    i = cut[j][i];
    breaks.insert(0, i);
  }
  return breaks;
}

/// Tallest column when [heights] are split into [columns] columns.
double partitionHeight(List<double> heights, int columns) {
  var tallest = 0.0;
  var start = 0;
  for (final end in [...partitionColumns(heights, columns), heights.length]) {
    var h = 0.0;
    for (var i = start; i < end; i++) {
      h += heights[i];
    }
    tallest = math.max(tallest, h);
    start = end;
  }
  return tallest;
}

/// Text styles derived from the font size and theme.
class SongTextStyles {
  SongTextStyles._(
    this.fontSize,
    this.lyrics,
    this.chord,
    this.label,
    this.mono,
    this.colors,
  );

  factory SongTextStyles.of(BuildContext context, double fontSize) {
    final theme = Theme.of(context);
    final base = TextStyle(
      fontSize: fontSize,
      height: lineHeightFactor,
      color: theme.colorScheme.onSurface,
    );
    return SongTextStyles._(
      fontSize,
      base,
      base.copyWith(
        fontSize: fontSize * chordScale,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
      base.copyWith(
        fontSize: fontSize * labelScale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: theme.colorScheme.secondary,
      ),
      base.copyWith(fontFamily: 'monospace', fontSize: fontSize * 0.85),
      theme.colorScheme,
    );
  }

  static const lineHeightFactor = 1.25;
  static const chordScale = 0.9;
  static const labelScale = 0.75;

  final double fontSize;
  final TextStyle lyrics;
  final TextStyle chord;
  final TextStyle label;
  final TextStyle mono;
  final ColorScheme colors;
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.text, required this.style});

  final String text;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: style.fontSize * 0.8),
    padding: EdgeInsets.all(style.fontSize * 0.5),
    decoration: BoxDecoration(
      color: style.colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.sticky_note_2_outlined,
          size: style.fontSize,
          color: style.colors.onTertiaryContainer,
        ),
        SizedBox(width: style.fontSize * 0.4),
        Expanded(
          child: Text(
            text,
            style: style.lyrics.copyWith(
              fontSize: style.fontSize * 0.85,
              color: style.colors.onTertiaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecallLabel extends StatelessWidget {
  const _RecallLabel({required this.text, required this.style});

  final String text;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: style.fontSize * 0.8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.repeat,
          size: style.fontSize * 0.9,
          color: style.colors.secondary,
        ),
        SizedBox(width: style.fontSize * 0.3),
        Text(text.toUpperCase(), style: style.label),
      ],
    ),
  );
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.label,
    required this.lines,
    required this.options,
    required this.style,
  });

  final Section section;
  final String? label;
  final List<Line> lines;
  final SongRenderOptions options;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) Text(label!.toUpperCase(), style: style.label),
        for (final line in lines) _buildLine(line),
      ],
    );
    final isChorus = section.kind == SectionKind.chorus;
    return Padding(
      padding: EdgeInsets.only(bottom: style.fontSize * 0.8),
      child: isChorus
          ? Container(
              padding: EdgeInsets.only(left: style.fontSize * 0.6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: style.colors.primary, width: 3),
                ),
              ),
              child: content,
            )
          : content,
    );
  }

  Widget _buildLine(Line line) => switch (line) {
    LyricLine l when !options.lyricsOnly && l.hasChords => _ChordLyricLine(
      line: l,
      formatter: options.formatter,
      style: style,
    ),
    LyricLine l => Text(l.text, style: style.lyrics),
    CommentLine c => _Comment(comment: c, style: style),
    RawLine r => Text(r.text, style: style.mono, softWrap: false),
    EmptyLine() => SizedBox(height: style.fontSize * 0.6),
  };
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment, required this.style});

  final CommentLine comment;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(vertical: style.fontSize * 0.15),
    padding: EdgeInsets.symmetric(
      horizontal: style.fontSize * 0.4,
      vertical: style.fontSize * 0.1,
    ),
    decoration: BoxDecoration(
      color: comment.style == CommentStyle.box
          ? null
          : style.colors.surfaceContainerHighest,
      border: comment.style == CommentStyle.box
          ? Border.all(color: style.colors.outline)
          : null,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      comment.text,
      style: style.lyrics.copyWith(
        fontSize: style.fontSize * 0.85,
        fontStyle: comment.style == CommentStyle.italic
            ? FontStyle.italic
            : FontStyle.normal,
      ),
    ),
  );
}

final _wordPattern = RegExp(r'\S+\s*|\s+');

class _ChordLyricLine extends StatelessWidget {
  const _ChordLyricLine({
    required this.line,
    required this.formatter,
    required this.style,
  });

  final LyricLine line;
  final ChordFormatter formatter;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[];
    for (final segment in line.segments) {
      final chord = segment.chord == null
          ? null
          : formatter.format(segment.chord!);
      final words = _wordPattern
          .allMatches(segment.text)
          .map((m) => m.group(0)!)
          .toList();
      if (words.isEmpty) words.add('');
      for (var i = 0; i < words.length; i++) {
        pieces.add(_piece(i == 0 ? chord : null, words[i]));
      }
    }
    return Padding(
      padding: EdgeInsets.only(top: style.fontSize * 0.1),
      child: Wrap(children: pieces),
    );
  }

  Widget _piece(String? chord, String word) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(
          right: chord == null ? 0 : style.fontSize * 0.35,
        ),
        child: Text(chord ?? ' ', style: style.chord),
      ),
      Text(word.isEmpty ? ' ' : word, style: style.lyrics),
    ],
  );
}

// Layout measurement ----------------------------------------------------------
//
// Mirrors the paddings of the widgets above. Sizes are stored per unit of font
// size; text widths are measured once with TextPainter at a reference size.
// Lines without chords (plain lyrics, comments, notes) may wrap; chord lines,
// tabs and labels must fit the column width.

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
  try {
    return [
      for (final b in blocks)
        _measure(b, formatter, lyricsOnly, painter, baseStyle),
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
  TextStyle? baseStyle,
) {
  const f = _referenceFontSize;
  const lh = SongTextStyles.lineHeightFactor;
  const labelHeight = SongTextStyles.labelScale * lh;
  final lyric = (baseStyle ?? const TextStyle()).merge(
    const TextStyle(fontSize: f, height: lh),
  );
  final chordStyle = lyric.copyWith(
    fontSize: f * SongTextStyles.chordScale,
    fontWeight: FontWeight.w700,
  );
  final labelStyle = lyric.copyWith(
    fontSize: f * SongTextStyles.labelScale,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  double unit(String text, TextStyle style) {
    painter.text = TextSpan(text: text, style: style);
    painter.layout();
    return painter.width / f;
  }

  if (block.text != null) {
    // Notes card: margin, padding; the text wraps next to the icon.
    return BlockMetrics(
      fixedHeight: 0.8 + 1.0,
      wrapping: [
        (
          width: unit(block.text!, lyric.copyWith(fontSize: f * 0.85)),
          lineHeight: 0.85 * lh,
          padding: 1.0 + 1.0 + 0.4,
        ),
      ],
      minWidth: 0,
    );
  }
  if (block.isRecallLabel) {
    return BlockMetrics(
      fixedHeight: 0.8 + math.max(labelHeight, 0.9),
      wrapping: const [],
      minWidth: 1.2 + unit(block.label!.toUpperCase(), labelStyle),
    );
  }

  final indent = block.section?.kind == SectionKind.chorus ? 0.6 + 3 / f : 0.0;
  var fixed = 0.8;
  var minWidth = 0.0;
  final wrapping = <({double width, double lineHeight, double padding})>[];
  if (block.label != null) {
    fixed += labelHeight;
    minWidth = unit(block.label!.toUpperCase(), labelStyle);
  }
  for (final line in block.lines) {
    switch (line) {
      case LyricLine l when !lyricsOnly && l.hasChords:
        fixed += 0.1 + SongTextStyles.chordScale * lh + lh;
        minWidth = math.max(
          minWidth,
          _chordLineWidth(
                l,
                formatter,
                f,
                (text) => unit(text, lyric) * f,
                (text) => unit(text, chordStyle) * f,
              ) /
              f,
        );
      case LyricLine l:
        wrapping.add((width: unit(l.text, lyric), lineHeight: lh, padding: 0));
      case CommentLine c:
        fixed += 0.3 + 0.2;
        wrapping.add((
          width: unit(
            c.text,
            lyric.copyWith(
              fontSize: f * 0.85,
              fontStyle: c.style == CommentStyle.italic
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          lineHeight: 0.85 * lh,
          padding: 0.8,
        ));
      case RawLine r:
        fixed += 0.85 * lh;
        minWidth = math.max(
          minWidth,
          unit(
            r.text,
            lyric.copyWith(fontFamily: 'monospace', fontSize: f * 0.85),
          ),
        );
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

double _chordLineWidth(
  LyricLine line,
  ChordFormatter formatter,
  double fontSize,
  double Function(String) lyricWidth,
  double Function(String) chordWidth,
) {
  var total = 0.0;
  for (final segment in line.segments) {
    final words = _wordPattern
        .allMatches(segment.text)
        .map((m) => m.group(0)!)
        .toList();
    if (words.isEmpty) words.add(' ');
    for (var i = 0; i < words.length; i++) {
      var w = lyricWidth(words[i]);
      if (i == 0 && segment.chord != null) {
        w = math.max(
          w,
          chordWidth(formatter.format(segment.chord!)) + fontSize * 0.35,
        );
      }
      total += w;
    }
  }
  return total;
}

/// Width of one of [columns] columns in [width] at [fontSize].
double columnWidth(double width, int columns, double fontSize) =>
    (width - columnGap * fontSize * (columns - 1)) / columns;

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

/// Chooses font size, number of columns and chorus display for live mode so
/// that the whole song fits into [size] without scrolling.
///
/// Sections are kept whole and distributed over 1 to [maxColumns] columns in
/// reading order. Chord lines must fit the column width; lines without chords
/// may wrap. The arrangement with the largest font wins; more columns are
/// only used when they give a clearly larger font, and repeated choruses are
/// only collapsed to a label when that gives a clearly larger font. If
/// nothing fits at [minFontSize], one scrollable column is returned.
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

    final lowest = math.min(minColumns, blocks.length);
    final highest = math.min(maxColumns, blocks.length);
    for (var k = lowest; k <= highest; k++) {
      if (k > 1 && columnWidth(size.width, k, baseFontSize) < minColumnWidth) {
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
        final tallest = partitionHeight([
          for (final m in metrics) m.height(font, width),
        ], k);
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

/// How a repeated chorus (`{chorus}`) is shown in live mode.
enum ChorusRepeat {
  /// Full lines, shortened to a label only if that is needed to fit.
  auto,

  /// Always the full lines.
  full,

  /// Always a label only.
  label,
}
