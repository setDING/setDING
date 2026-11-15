import 'dart:io';
import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

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

/// Renders the body of a ChordPro song: sections with chords above lyrics,
/// arranged in [SongRenderOptions.columns] columns. Column breaks in the
/// song (`{column_break}`) start new columns when more than one column is
/// used.
class SongBody extends StatelessWidget {
  const SongBody({super.key, required this.song, required this.options});

  final Song song;
  final SongRenderOptions options;

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
    Widget render(SongBlock b) => b.delegate != null
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

    final columns = forcedColumns(blocks) != null && options.columns > 1
        ? forcedColumns(blocks)!
        : math.min(options.columns, blocks.length);
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

/// Diagrams of all chords of the song.
class _DiagramsBlock extends StatelessWidget {
  const _DiagramsBlock({required this.diagrams, required this.style});

  final List<DiagramData> diagrams;
  final SongTextStyles style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: style.fontSize * 0.2),
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
      padding: EdgeInsets.only(bottom: style.fontSize * 0.8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: style.fontSize * 0.9,
            color: labelStyle.color,
          ),
          SizedBox(width: style.fontSize * 0.3),
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
        case FormatLine l:
          format.apply(l);
        case LyricLine l when !options.lyricsOnly && l.hasChords:
          children.add(
            _ChordLyricLine(
              line: l,
              formatter: options.formatter,
              lyricStyle: style.lyricsFor(format, inChorus: chorus),
              chordStyle: style.chordFor(format),
            ),
          );
        case LyricLine l:
          children.add(
            Text.rich(
              markupSpan(l.text, style.lyricsFor(format, inChorus: chorus)),
            ),
          );
        case CommentLine c:
          children.add(
            _Comment(
              comment: c,
              textStyle: style.lyricsFor(format),
              colors: style.colors,
            ),
          );
        case RawLine r:
          children.add(
            Text(r.text, style: style.tabFor(format), softWrap: false),
          );
        case GridLine g:
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
        case ImageLine i when _image(i) != null:
          final (file, box) = _image(i)!;
          children.add(
            SongImageView(box: box, fontSize: style.fontSize, file: file),
          );
        case ImageLine i:
          children.add(
            _Placeholder(
              icon: Icons.image_outlined,
              text: i.src ?? '',
              style: style.labelFor(format),
              size: style.fontSize,
            ),
          );
        case ChordDiagramLine c:
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
                      vertical: style.fontSize * 0.15,
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
          children.add(SizedBox(height: style.fontSize * 0.6));
      }
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: style.fontSize * 0.8),
      child: chorus
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

  (File, ImageBox)? _image(ImageLine line) =>
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
    padding: EdgeInsets.symmetric(vertical: size * 0.15),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: style.color),
        SizedBox(width: size * 0.3),
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
      fontSize: size * 0.85,
      fontStyle: comment.style == CommentStyle.italic ? FontStyle.italic : null,
    );
    return Container(
      margin: EdgeInsets.symmetric(vertical: size * 0.15),
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.4,
        vertical: size * 0.1,
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
      padding: EdgeInsets.only(top: size * 0.1),
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
                    right: piece.chord == null ? 0 : size * 0.35,
                  ),
                  child: Text(
                    piece.chord ?? ' ',
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
