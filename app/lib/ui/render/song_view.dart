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
  });

  final ChordFormatter formatter;
  final bool lyricsOnly;
  final double fontSize;
  final int columns;
  final String? notes;

  SongRenderOptions copyWith({double? fontSize, int? columns}) =>
      SongRenderOptions(
        formatter: formatter,
        lyricsOnly: lyricsOnly,
        fontSize: fontSize ?? this.fontSize,
        columns: columns ?? this.columns,
        notes: notes,
      );
}

/// Renders the body of a ChordPro song: sections with chords above lyrics.
class SongBody extends StatelessWidget {
  const SongBody({super.key, required this.song, required this.options});

  final Song song;
  final SongRenderOptions options;

  @override
  Widget build(BuildContext context) {
    final style = SongTextStyles.of(context, options.fontSize);
    final l10n = AppLocalizations.of(context);
    final blocks = <Widget>[];
    final heights = <double>[];

    final notes = options.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      blocks.add(_NotesCard(text: notes, style: style));
      heights.add(style.fontSize * 3);
    }

    for (final element in song.elements) {
      final section = switch (element) {
        Section s => s,
        ChorusRecall r => r.chorus,
        // Exhaustive: no other element types.
      };
      final label = switch (element) {
        Section s => _label(s, l10n),
        ChorusRecall r => r.label ?? r.chorus?.label ?? l10n.sectionChorus,
      };
      if (section == null) {
        blocks.add(
          _SectionLabel(text: label ?? l10n.sectionChorus, style: style),
        );
        heights.add(style.fontSize * 2);
        continue;
      }
      final lines = _visibleLines(section);
      if (lines.isEmpty && label == null) continue;
      blocks.add(
        _SectionBlock(
          section: section,
          label: label,
          lines: lines,
          options: options,
          style: style,
        ),
      );
      heights.add(
        estimateSectionHeight(
          section,
          label != null,
          options.lyricsOnly,
          options.fontSize,
        ),
      );
    }

    if (options.columns <= 1 || blocks.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      );
    }
    final split = _balancedSplit(heights);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: blocks.sublist(0, split),
          ),
        ),
        SizedBox(width: options.fontSize * 1.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: blocks.sublist(split),
          ),
        ),
      ],
    );
  }

  List<Line> _visibleLines(Section section) {
    if (!options.lyricsOnly) return section.lines;
    return section.lines
        .where((l) => l is! LyricLine || l.text.trim().isNotEmpty)
        .toList();
  }

  static String? _label(Section s, AppLocalizations l10n) =>
      s.label ??
      switch (s.kind) {
        SectionKind.verse => l10n.sectionVerse,
        SectionKind.chorus => l10n.sectionChorus,
        SectionKind.bridge => l10n.sectionBridge,
        SectionKind.tab => l10n.sectionTab,
        SectionKind.grid => l10n.sectionGrid,
        SectionKind.none || SectionKind.custom => null,
      };
}

/// Index splitting [heights] into two columns of similar height.
int _balancedSplit(List<double> heights) {
  final total = heights.fold<double>(0, (a, b) => a + b);
  var acc = 0.0;
  for (var i = 0; i < heights.length; i++) {
    if (acc + heights[i] / 2 >= total / 2) return math.max(1, i);
    acc += heights[i];
  }
  return heights.length - 1;
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.style});

  final String text;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: style.fontSize * 0.6),
    child: Text(text.toUpperCase(), style: style.label),
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

// Layout estimation -----------------------------------------------------------

/// Estimated height of a section in logical pixels at [fontSize].
double estimateSectionHeight(
  Section section,
  bool hasLabel,
  bool lyricsOnly,
  double fontSize,
) {
  final lyric = fontSize * SongTextStyles.lineHeightFactor;
  final chord =
      fontSize * SongTextStyles.chordScale * SongTextStyles.lineHeightFactor;
  var height = fontSize * 0.8; // section spacing
  if (hasLabel) {
    height +=
        fontSize * SongTextStyles.labelScale * SongTextStyles.lineHeightFactor;
  }
  for (final line in section.lines) {
    height += switch (line) {
      LyricLine l when !lyricsOnly && l.hasChords =>
        lyric + chord + fontSize * 0.1,
      LyricLine l when lyricsOnly && l.text.trim().isEmpty => 0,
      LyricLine() => lyric,
      CommentLine() => lyric * 0.85 + fontSize * 0.5,
      RawLine() => lyric * 0.85,
      EmptyLine() => fontSize * 0.6,
    };
  }
  return height;
}

/// Estimated total height of [song] at [fontSize] in [columns] columns.
double estimateSongHeight(
  Song song, {
  required bool lyricsOnly,
  required double fontSize,
  int columns = 1,
}) {
  final heights = <double>[];
  for (final element in song.elements) {
    switch (element) {
      case Section s:
        heights.add(
          estimateSectionHeight(
            s,
            s.kind != SectionKind.none || s.label != null,
            lyricsOnly,
            fontSize,
          ),
        );
      case ChorusRecall r:
        heights.add(
          r.chorus == null
              ? fontSize * 2
              : estimateSectionHeight(r.chorus!, true, lyricsOnly, fontSize),
        );
    }
  }
  final total = heights.fold<double>(0, (a, b) => a + b);
  if (columns <= 1 || heights.length < 2) return total;
  final split = _balancedSplit(heights);
  final first = heights.sublist(0, split).fold<double>(0, (a, b) => a + b);
  return math.max(first, total - first);
}

/// Width of the widest line of [song] at [fontSize].
double measureWidestLine(
  Song song, {
  required ChordFormatter formatter,
  required bool lyricsOnly,
  required double fontSize,
  required TextScaler textScaler,
}) {
  final lyricStyle = TextStyle(
    fontSize: fontSize,
    height: SongTextStyles.lineHeightFactor,
  );
  final chordStyle = lyricStyle.copyWith(
    fontSize: fontSize * SongTextStyles.chordScale,
    fontWeight: FontWeight.w700,
  );
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );
  double width(String text, TextStyle style) {
    painter.text = TextSpan(text: text, style: style);
    painter.layout();
    return painter.width;
  }

  var widest = 0.0;
  for (final section in song.sections) {
    for (final line in section.lines) {
      final w = switch (line) {
        LyricLine l when !lyricsOnly && l.hasChords => l.segments.fold<double>(
          0,
          (sum, s) {
            final text = width(s.text, lyricStyle);
            final chord = s.chord == null
                ? 0.0
                : width(formatter.format(s.chord!), chordStyle) +
                      fontSize * 0.35;
            return sum + math.max(text, chord);
          },
        ),
        LyricLine l => width(l.text, lyricStyle),
        CommentLine c => width(c.text, lyricStyle) * 0.85 + fontSize,
        RawLine r => width(
          r.text,
          lyricStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: fontSize * 0.85,
          ),
        ),
        EmptyLine() => 0.0,
      };
      widest = math.max(widest, w);
    }
  }
  painter.dispose();
  return widest;
}

/// Result of [fitSong].
class SongFit {
  const SongFit(this.fontSize, this.columns);

  final double fontSize;
  final int columns;
}

/// Chooses font size and column count for live mode.
///
/// The font size is limited so the widest line fits the column width
/// (never above [maxFontSize]). If the song then does not fit on one screen
/// but would after shrinking by at most 30 %, it is shrunk. Two columns are
/// only used when [allowTwoColumns] and the song fits on one screen with them.
SongFit fitSong(
  Song song, {
  required ChordFormatter formatter,
  required bool lyricsOnly,
  required double baseFontSize,
  required double maxFontSize,
  required double minFontSize,
  required Size size,
  required TextScaler textScaler,
  required bool allowTwoColumns,
  bool forceTwoColumns = false,
}) {
  SongFit fitFor(int columns) {
    final columnWidth = columns == 1
        ? size.width
        : (size.width - baseFontSize * 1.5) / 2;
    final widest = measureWidestLine(
      song,
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      fontSize: baseFontSize,
      textScaler: textScaler,
    );
    var font = widest <= 0 ? maxFontSize : baseFontSize * columnWidth / widest;
    font = font.clamp(minFontSize, maxFontSize);
    final height = estimateSongHeight(
      song,
      lyricsOnly: lyricsOnly,
      fontSize: font,
      columns: columns,
    );
    if (height > size.height) {
      final shrunk = font * size.height / height;
      if (shrunk >= font * 0.7 && shrunk >= minFontSize) font = shrunk;
    }
    return SongFit(font, columns);
  }

  final one = fitFor(1);
  if (forceTwoColumns) return fitFor(2);
  if (!allowTwoColumns) return one;
  final oneFits =
      estimateSongHeight(
        song,
        lyricsOnly: lyricsOnly,
        fontSize: one.fontSize,
      ) <=
      size.height;
  if (oneFits) return one;
  final two = fitFor(2);
  final twoFits =
      estimateSongHeight(
        song,
        lyricsOnly: lyricsOnly,
        fontSize: two.fontSize,
        columns: 2,
      ) <=
      size.height;
  return twoFits ? two : one;
}
