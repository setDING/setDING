import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';

import '../../l10n/generated/app_localizations.dart';
import 'chord_diagram.dart';

/// A unit of the song layout that is placed as a whole into a column.
class SongBlock {
  SongBlock.notes(String this.text)
    : section = null,
      label = null,
      lines = const [],
      isRecallLabel = false,
      breakBefore = false,
      diagrams = null,
      delegate = null,
      recalled = null,
      startFormat = FormatState();

  /// A delegated environment (SVG, textblock, ABC, Lilypond).
  SongBlock.delegate(DelegateSection this.delegate, {required this.startFormat})
    : section = null,
      text = null,
      label = delegate.label,
      lines = const [],
      isRecallLabel = false,
      breakBefore = false,
      recalled = null,
      diagrams = null;

  /// Diagrams of all chords of the song (`{diagrams}`, ADR-0012).
  SongBlock.diagrams(List<DiagramData> this.diagrams)
    : section = null,
      delegate = null,
      text = null,
      label = null,
      lines = const [],
      isRecallLabel = false,
      breakBefore = false,
      recalled = null,
      startFormat = FormatState();

  SongBlock.section(
    Section this.section,
    this.label,
    this.lines, {
    required this.startFormat,
    this.breakBefore = false,
  }) : text = null,
       diagrams = null,
       delegate = null,
       recalled = null,
       isRecallLabel = false;

  SongBlock.recall(
    String this.label, {
    required this.startFormat,
    this.recalled,
  }) : section = null,
       text = null,
       lines = const [],
       isRecallLabel = true,
       diagrams = null,
       delegate = null,
       breakBefore = false;

  /// Personal note text (notes block).
  final String? text;

  /// Chord diagrams (diagrams block).
  final List<DiagramData>? diagrams;

  /// Delegated environment (delegate block).
  final DelegateSection? delegate;
  final Section? section;
  final String? label;
  final List<Line> lines;

  /// A repeated chorus shown only as a label.
  final bool isRecallLabel;

  /// The chorus repeated by a recall label, if it was defined before.
  final Section? recalled;

  /// The section the block shows or repeats, if any.
  Section? get shownSection => section ?? recalled;

  /// `{column_break}` / `{new_page}` before this block: it starts a new
  /// column.
  final bool breakBefore;

  /// Font/size/colour directives in effect at the start of the block.
  final FormatState startFormat;

  bool get isChorus => section?.kind == SectionKind.chorus;

  /// Role whose style the block is shown in (ADR-0033): the label of a
  /// repeated chorus is shown like the chorus.
  SectionRole get role => isRecallLabel
      ? SectionRole.chorus
      : section?.role ?? SectionRole.standard;
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
/// Column and page breaks split a section and start a new column. With
/// [collapseRecalls], a repeated chorus (`{chorus}`) is shown as a label
/// only instead of repeating its lines, to save space in live mode.
List<SongBlock> buildSongBlocks(
  Song song, {
  required bool lyricsOnly,
  required SectionLabeler labeler,
  String? notes,
  bool collapseRecalls = false,
  List<DiagramData> diagrams = const [],
  bool diagramsOnTop = false,
}) {
  bool visible(Line l) =>
      !lyricsOnly || l is! LyricLine || l.plainText.trim().isNotEmpty;

  final blocks = <SongBlock>[];
  final note = notes?.trim();
  if (note != null && note.isNotEmpty) blocks.add(SongBlock.notes(note));
  if (diagrams.isNotEmpty && diagramsOnTop) {
    blocks.add(SongBlock.diagrams(diagrams));
  }
  final chorusLabel = labeler(SectionKind.chorus) ?? 'Chorus';
  final format = FormatState();
  var pendingBreak = false;

  /// Adds [section] split at breaks; [label] goes to the first part.
  void addSection(Section section, String? label, {bool applyFormats = true}) {
    var part = <Line>[];
    var partLabel = label;
    var startFormat = format.copy();
    // Formats of a repeated chorus were already applied where it was defined.
    final local = applyFormats ? format : format.copy();

    void flush() {
      final hasContent = part.any((l) => l is! FormatLine);
      if (hasContent || partLabel != null) {
        blocks.add(
          SongBlock.section(
            section,
            partLabel,
            part,
            startFormat: startFormat,
            breakBefore: pendingBreak,
          ),
        );
        pendingBreak = false;
      }
      part = <Line>[];
      partLabel = null;
      startFormat = local.copy();
    }

    for (final line in section.lines) {
      if (line is BreakLine) {
        flush();
        pendingBreak = true;
        continue;
      }
      if (line is FormatLine) local.apply(line);
      if (visible(line)) part.add(line);
    }
    flush();
  }

  for (final element in song.elements) {
    switch (element) {
      case final Section s:
        addSection(s, s.label ?? labeler(s.kind));
      case final ChorusRecall r:
        final chorus = r.chorus;
        final label = r.label ?? chorus?.label ?? chorusLabel;
        if (chorus == null || collapseRecalls) {
          blocks.add(
            SongBlock.recall(
              label,
              startFormat: format.copy(),
              recalled: chorus,
            ),
          );
        } else {
          addSection(chorus, label, applyFormats: false);
        }
      case final DelegateSection d:
        blocks.add(SongBlock.delegate(d, startFormat: format.copy()));
    }
  }
  if (diagrams.isNotEmpty && !diagramsOnTop) {
    blocks.add(SongBlock.diagrams(diagrams));
  }
  return blocks;
}

/// Gap between columns, relative to the font size.
const columnGap = 1.5;

/// Width of one of [columns] columns in [width] at [fontSize].
double columnWidth(double width, int columns, double fontSize) =>
    (width - columnGap * fontSize * (columns - 1)) / columns;

/// Number of columns forced by breaks, or null if the song has none.
int? forcedColumns(List<SongBlock> blocks) {
  if (!blocks.any((b) => b.breakBefore)) return null;
  return 1 + blocks.skip(1).where((b) => b.breakBefore).length;
}

/// End indices (except the last) of the columns for [blocks].
///
/// Breaks in the song decide the columns; otherwise the blocks are split
/// into [columns] columns of similar height (see [partitionColumns]).
List<int> columnBreaks(
  List<SongBlock> blocks,
  List<double> heights,
  int columns,
) {
  if (forcedColumns(blocks) != null) {
    return [
      for (var i = 1; i < blocks.length; i++)
        if (blocks[i].breakBefore) i,
    ];
  }
  return partitionColumns(heights, columns);
}

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

/// Tallest column when [heights] are split at [breaks].
double tallestColumn(List<double> heights, List<int> breaks) {
  var tallest = 0.0;
  var start = 0;
  for (final end in [...breaks, heights.length]) {
    var h = 0.0;
    for (var i = start; i < end; i++) {
      h += heights[i];
    }
    tallest = math.max(tallest, h);
    start = end;
  }
  return tallest;
}

/// Tallest column when [heights] are split into [columns] columns.
double partitionHeight(List<double> heights, int columns) =>
    tallestColumn(heights, partitionColumns(heights, columns));
