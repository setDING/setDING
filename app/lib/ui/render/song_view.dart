import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/attachment_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import 'chord_diagram.dart';
import 'song_blocks.dart';
import 'song_delegates.dart';
import 'song_image.dart';
import 'song_grid.dart';
import 'song_layout.dart';
import 'song_style.dart';

export 'song_blocks.dart';
export 'song_layout.dart';
export 'song_style.dart';

/// Options for rendering a song (combined layers of ADR-0006).
class SongRenderOptions {
  const SongRenderOptions({
    required this.formatter,
    this.lyricsOnly = false,
    this.fontSize = 20,
    this.columns = 1,
    this.notes,
    this.collapseRecalls = false,
    this.diagramResolver,
    this.diagramsPosition = DiagramsPosition.off,
    this.imageLookup,
    this.layout,
  });

  final ChordFormatter formatter;
  final bool lyricsOnly;
  final double fontSize;
  final int columns;
  final String? notes;

  /// Show a repeated chorus as a label only.
  final bool collapseRecalls;

  /// Resolves chord diagrams; null = no diagrams.
  final DiagramResolver? diagramResolver;

  /// Where the diagrams of all chords are shown.
  final DiagramsPosition diagramsPosition;

  /// Finds image files for `{image}`; null = images are not available.
  final ImageLookup? imageLookup;

  /// Blocks and measurements from [fitSong] for exactly these options;
  /// null = built and measured when rendering.
  final SongLayout? layout;

  /// Diagrams of all chords for [diagramsPosition].
  List<DiagramData> get songDiagrams =>
      diagramsPosition == DiagramsPosition.off || diagramResolver == null
      ? const []
      : diagramResolver!.allChords();
}

/// Lines a [SongBlock] counts for [BodyProgress]: a rough measure of what
/// building and laying it out costs.
int songBlockLines(SongBlock block) => math.max(1, block.lines.length);

/// Builds a [SongBody] over several frames, for a page that is not shown
/// yet (live mode, issue #296): only the blocks that start within the first
/// [value] lines (see [songBlockLines]) are built. Raising it builds the
/// next blocks without building the others again; lowering it removes
/// blocks from the end.
class BodyProgress extends ValueNotifier<int> {
  BodyProgress() : super(0);

  /// Lines of the body as last built, set by [SongBody]; null when no body
  /// was built.
  int? total;
}

/// Renders the body of a ChordPro song: sections with chords above lyrics,
/// arranged in [SongRenderOptions.columns] columns. Column breaks in the
/// song (`{column_break}`) start new columns when more than one column is
/// used.
class SongBody extends StatelessWidget {
  const SongBody({
    super.key,
    required this.song,
    required this.options,
    this.progress,
    this.firstLine = 0,
  });

  final Song song;
  final SongRenderOptions options;

  /// Builds the blocks in steps; null builds all at once.
  final BodyProgress? progress;

  /// Lines of the song before this body for [progress], e.g. of the pages
  /// before it: the pages of a song are built one after the other.
  final int firstLine;

  @override
  Widget build(BuildContext context) {
    final style = SongTextStyles.of(context, options.fontSize);
    final blocks =
        options.layout?.blocks ??
        buildSongBlocks(
          song,
          lyricsOnly: options.lyricsOnly,
          labeler: sectionLabeler(AppLocalizations.of(context)),
          notes: options.notes,
          collapseRecalls: options.collapseRecalls,
          diagrams: options.songDiagrams,
          diagramsOnTop: options.diagramsPosition == DiagramsPosition.top,
        );
    Widget blockWidget(SongBlock b) => b.delegate != null
        ? DelegateView(
            delegate: b.delegate!,
            lyrics: style.lyricsFor(b.startFormat),
            label: style.labelFor(b.startFormat),
            mono: style.tabFor(b.startFormat),
            colors: style.colors,
            transpose:
                options.formatter.transpose +
                options.formatter.leadingTranspose,
          )
        : b.diagrams != null
        ? _DiagramsBlock(diagrams: b.diagrams!, style: style)
        : b.text != null
        ? _NotesCard(text: b.text!, style: style)
        : b.isRecallLabel
        ? _RecallLabel(block: b, style: style)
        : _SectionBlock(block: b, options: options, style: style);
    // Lines before each block, for building in steps.
    final progress = this.progress;
    final starts = <int>[];
    var lines = firstLine;
    for (final b in blocks) {
      starts.add(lines);
      lines += songBlockLines(b);
    }
    if (progress != null) {
      progress.total = math.max(progress.total ?? 0, lines);
    }
    // Keyed by index, so tests can compare rendered and measured heights.
    Widget render(int i, SongBlock b) => KeyedSubtree(
      key: ValueKey(('song-block', i)),
      child: progress == null
          ? blockWidget(b)
          : ValueListenableBuilder<int>(
              valueListenable: progress,
              // Built once it is reached; blocks already built are kept.
              builder: (context, built, child) =>
                  starts[i] < built ? child! : const SizedBox.shrink(),
              child: blockWidget(b),
            ),
    );

    final columns = forcedColumns(blocks) != null && options.columns > 1
        ? forcedColumns(blocks)!
        : math.min(options.columns, blocks.length);
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final (i, b) in blocks.indexed) render(i, b)],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = columnWidth(
          constraints.maxWidth,
          columns,
          options.fontSize,
        );
        final metrics =
            options.layout?.metrics ??
            measureBlocks(
              blocks,
              formatter: options.formatter,
              lyricsOnly: options.lyricsOnly,
              textScaler: MediaQuery.textScalerOf(context),
              baseStyle: DefaultTextStyle.of(context).style,
              diagramResolver: options.diagramResolver,
              imageLookup: options.imageLookup,
            );
        final heights = [
          for (final m in metrics) m.height(options.fontSize, width),
        ];
        final ends = [...columnBreaks(blocks, heights, columns), blocks.length];
        final children = <Widget>[];
        var start = 0;
        for (final end in ends) {
          if (start > 0) {
            children.add(SizedBox(width: options.fontSize * columnGap));
          }
          children.add(
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < end; i++) render(i, blocks[i]),
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

/// Diagrams of all chords of the song.
class _DiagramsBlock extends StatelessWidget {
  const _DiagramsBlock({required this.diagrams, required this.style});

  final List<DiagramData> diagrams;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: style.fontSize * SongSpacing.diagramsBlockGap,
    ),
    child: Wrap(
      spacing: style.fontSize * diagramSpacing,
      runSpacing: style.fontSize * diagramRunSpacing,
      children: [
        for (final d in diagrams)
          ChordDiagramView(
            data: d,
            fontSize: style.fontSize,
            color: style.colors.onSurfaceVariant,
            accent: style.colors.primary,
            nameStyle: style.lyrics,
          ),
      ],
    ),
  );
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.text, required this.style});

  final String text;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: style.fontSize * SongSpacing.blockGap),
    padding: EdgeInsets.all(style.fontSize * SongSpacing.notesPadding),
    decoration: BoxDecoration(
      color: style.colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.sticky_note_2_outlined,
          size: style.fontSize * SongSpacing.notesIcon,
          color: style.colors.onTertiaryContainer,
        ),
        SizedBox(width: style.fontSize * SongSpacing.notesIconGap),
        Expanded(
          child: Text(
            text,
            style: style.lyrics.copyWith(
              fontSize: style.fontSize * SongSpacing.smallText,
              color: style.colors.onTertiaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A section label (upper case, markup allowed, `\n` for several lines).
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) =>
      Text.rich(markupSpan(text, style, transform: (s) => s.toUpperCase()));
}

class _RecallLabel extends StatelessWidget {
  const _RecallLabel({required this.block, required this.style});

  final SongBlock block;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) {
    final labelStyle = style.labelFor(block.startFormat);
    return Padding(
      padding: EdgeInsets.only(bottom: style.fontSize * SongSpacing.blockGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: style.fontSize * SongSpacing.recallIcon,
            color: labelStyle.color,
          ),
          SizedBox(width: style.fontSize * SongSpacing.iconGap),
          _Label(text: block.label!, style: labelStyle),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.block,
    required this.options,
    required this.style,
  });

  final SongBlock block;
  final SongRenderOptions options;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) {
    final format = block.startFormat.copy();
    final chorus = block.isChorus;
    GridGeometry? grid;
    final children = <Widget>[
      if (block.label != null)
        _Label(text: block.label!, style: style.labelFor(format)),
    ];
    for (final line in block.lines) {
      switch (line) {
        case final FormatLine l:
          format.apply(l);
        case final LyricLine l when !options.lyricsOnly && l.hasChords:
          children.add(
            _ChordLyricLine(
              line: l,
              formatter: options.formatter,
              lyricStyle: style.lyricsFor(format, inChorus: chorus),
              chordStyle: style.chordFor(format),
            ),
          );
        case final LyricLine l:
          children.add(
            Text.rich(
              markupSpan(l.text, style.lyricsFor(format, inChorus: chorus)),
            ),
          );
        case final CommentLine c:
          children.add(
            _Comment(
              comment: c,
              textStyle: style.lyricsFor(format),
              colors: style.colors,
            ),
          );
        case final RawLine r:
          children.add(
            Text(r.text, style: style.tabFor(format), softWrap: false),
          );
        case final GridLine g:
          final text = style.gridFor(format);
          final chordStyle = style.gridChordFor(format);
          grid ??= _gridGeometry(context, block.lines, text, chordStyle);
          children.add(
            GridRowView(
              row: g.row,
              geometry: grid,
              formatter: options.formatter,
              textStyle: text,
              chordStyle: chordStyle,
              barColor: style.colors.outline,
            ),
          );
        case final ImageLine i when _image(i) != null:
          final (file, box) = _image(i)!;
          children.add(
            SongImageView(box: box, fontSize: style.fontSize, file: file),
          );
        case final ImageLine i:
          children.add(
            _Placeholder(
              icon: Icons.image_outlined,
              text: i.src ?? '',
              style: style.labelFor(format),
              size: style.fontSize,
            ),
          );
        case final ChordDiagramLine c:
          final data = options.diagramResolver?.forDefinition(c.definition);
          children.add(
            data == null
                ? _Placeholder(
                    icon: Icons.grid_on,
                    text: c.definition.display ?? c.definition.name,
                    style: style.labelFor(format),
                    size: style.fontSize,
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: style.fontSize * SongSpacing.lineItemPadding,
                    ),
                    child: ChordDiagramView(
                      data: data,
                      fontSize: style.fontSize,
                      color: style.colors.onSurfaceVariant,
                      accent: style.colors.primary,
                      nameStyle: style.lyrics,
                    ),
                  ),
          );
        case BreakLine():
          break;
        case EmptyLine():
          children.add(
            SizedBox(height: style.fontSize * SongSpacing.emptyLine),
          );
      }
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: style.fontSize * SongSpacing.blockGap),
      child: chorus
          ? Container(
              padding: EdgeInsets.only(
                left: style.fontSize * SongSpacing.chorusIndent,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: style.colors.primary,
                    width: SongSpacing.chorusBorderPixels,
                  ),
                ),
              ),
              child: content,
            )
          : content,
    );
  }

  (StoredFile, ImageBox)? _image(ImageLine line) =>
      resolveImage(line, options.imageLookup);

  GridGeometry _gridGeometry(
    BuildContext context,
    List<Line> lines,
    TextStyle text,
    TextStyle chordStyle,
  ) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final size = text.fontSize ?? 14;
    final geometry = GridGeometry.of(lines, options.formatter, (
      s, {
      bool chord = false,
    }) {
      painter.text = TextSpan(text: s, style: chord ? chordStyle : text);
      painter.layout();
      return painter.width / size;
    });
    painter.dispose();
    return geometry;
  }
}

/// Images and chord diagrams until they are rendered (ADR-0012, phases 4–5).
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.text,
    required this.style,
    required this.size,
  });

  final IconData icon;
  final String text;
  final TextStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: size * SongSpacing.lineItemPadding),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: style.color),
        SizedBox(width: size * SongSpacing.iconGap),
        Text(text, style: style),
      ],
    ),
  );
}

class _Comment extends StatelessWidget {
  const _Comment({
    required this.comment,
    required this.textStyle,
    required this.colors,
  });

  final CommentLine comment;
  final TextStyle textStyle;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final size = textStyle.fontSize ?? 14;
    final style = textStyle.copyWith(
      fontSize: size * SongSpacing.smallText,
      fontStyle: comment.style == CommentStyle.italic ? FontStyle.italic : null,
    );
    return Container(
      margin: EdgeInsets.symmetric(vertical: size * SongSpacing.commentMargin),
      padding: EdgeInsets.symmetric(
        horizontal: size * SongSpacing.commentPaddingHorizontal,
        vertical: size * SongSpacing.commentPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: comment.style == CommentStyle.box
            ? null
            : colors.surfaceContainerHighest,
        border: comment.style == CommentStyle.box
            ? Border.all(color: colors.outline)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text.rich(markupSpan(comment.text, style)),
    );
  }
}

class _ChordLyricLine extends StatelessWidget {
  const _ChordLyricLine({
    required this.line,
    required this.formatter,
    required this.lyricStyle,
    required this.chordStyle,
  });

  final LyricLine line;
  final ChordFormatter formatter;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;

  @override
  Widget build(BuildContext context) {
    final size = lyricStyle.fontSize ?? 14;
    return Padding(
      padding: EdgeInsets.only(top: size * SongSpacing.chordLineTop),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final piece in chordLinePieces(line, formatter))
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right: piece.chord == null
                        ? 0
                        : size * SongSpacing.chordGap,
                  ),
                  child: ChordText(
                    piece.chordParts ?? const [ChordPart(' ')],
                    style: applyMarkupStyle(chordStyle, piece.chordMarkup),
                  ),
                ),
                if (piece.runs.isEmpty)
                  Text(' ', style: lyricStyle)
                else
                  Text.rich(
                    TextSpan(
                      style: lyricStyle,
                      children: [
                        for (final run in piece.runs)
                          runSpan(run, lyricStyle, (s) => s, false),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
