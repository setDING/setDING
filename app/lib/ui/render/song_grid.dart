import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

import 'song_style.dart';

/// Measures a text width in units of the grid font size.
typedef GridTextWidth = double Function(String text, {bool chord});

/// Geometry of a grid section, in units of the grid font size. Shared by
/// rendering and layout measurement (ADR-0012).
///
/// The grid is laid out like a table (#484): the n-th element of every row
/// (bar line or cell) is in column n, and each column is as wide as its
/// widest element. Columns that are empty in every row stay narrow.
class GridGeometry {
  const GridGeometry({required this.columns, required this.left});

  /// Width of each column.
  final List<double> columns;

  /// Width of the left margin.
  final double left;

  static const rowHeight = 1.25 + 0.3;
  static const barPadding = 0.3;

  /// Width of a cell with chords or marks, and of an empty cell.
  static const minCell = 1.2;
  static const emptyCell = 0.8;

  /// Space after the text of a cell.
  static const cellPadding = 0.5;

  /// Width of a bar symbol.
  static double barWidth(String symbol, GridTextWidth width) =>
      math.max(0.9, width(symbol) + barPadding);

  /// Width that [token] needs on its own.
  static double tokenWidth(
    GridToken token,
    ChordFormatter formatter,
    GridTextWidth width,
  ) => switch (token) {
    GridBar(:final symbol) => barWidth(symbol, width),
    GridChords(:final chords) => math.max(
      minCell,
      width(chords.map(formatter.format).join(' '), chord: true) + cellPadding,
    ),
    GridMark(symbol: GridSymbol.empty) => emptyCell,
    GridMark(:final symbol) => math.max(
      minCell,
      width(gridMarkText(symbol)) + cellPadding,
    ),
    GridStrum() => math.max(
      emptyCell,
      width(token.symbol, chord: true) + cellPadding,
    ),
  };

  /// Width of the element at [index] of a row.
  double columnWidth(
    int index,
    GridToken token,
    ChordFormatter formatter,
    GridTextWidth width,
  ) => index < columns.length
      ? columns[index]
      : tokenWidth(token, formatter, width);

  /// Width of a whole row.
  double rowWidth(GridRow row, ChordFormatter formatter, GridTextWidth width) {
    var total = row.leftMargin == null && left == 0 ? 0.0 : left;
    for (final (i, token) in row.tokens.indexed) {
      total += columnWidth(i, token, formatter, width);
    }
    final right = row.rightMargin;
    if (right != null) total += 0.5 + width(right);
    return total;
  }

  /// Geometry for the grid lines in [lines].
  static GridGeometry of(
    Iterable<Line> lines,
    ChordFormatter formatter,
    GridTextWidth width,
  ) {
    final columns = <double>[];
    var left = 0.0;
    for (final line in lines) {
      if (line is! GridLine) continue;
      final row = line.row;
      if (row.leftMargin != null) {
        left = math.max(left, width(row.leftMargin!) + 0.6);
      }
      for (final (i, token) in row.tokens.indexed) {
        final w = tokenWidth(token, formatter, width);
        if (i < columns.length) {
          columns[i] = math.max(columns[i], w);
        } else {
          columns.add(w);
        }
      }
    }
    return GridGeometry(columns: columns, left: left);
  }
}

/// A grid cell with one or more chords, as chord parts.
List<ChordPart> gridChordParts(GridChords cell, ChordFormatter formatter) =>
    mergeChordParts([
      for (final (i, chord) in cell.chords.indexed) ...[
        if (i > 0) const ChordPart(' '),
        ...formatter.formatParts(chord),
      ],
    ]);

/// Text of a grid mark.
String gridMarkText(GridSymbol symbol) => switch (symbol) {
  GridSymbol.empty => '',
  GridSymbol.slash => '/',
  GridSymbol.repeat1 => '%',
  GridSymbol.repeat2 => '%%',
};

/// One grid line, laid out in cells.
class GridRowView extends StatelessWidget {
  const GridRowView({
    super.key,
    required this.row,
    required this.geometry,
    this.gridWidth,
    required this.formatter,
    required this.textStyle,
    required this.chordStyle,
    required this.barColor,
  });

  final GridRow row;
  final GridGeometry geometry;

  /// Width of the widest row of the grid, in units of the font size. A
  /// grid wider than the available width is scaled down as a whole, so
  /// that its columns stay aligned (#484).
  final double? gridWidth;

  final ChordFormatter formatter;

  /// Style for margins, bars and marks.
  final TextStyle textStyle;
  final TextStyle chordStyle;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final size = textStyle.fontSize ?? 14;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    );
    double width(String text, {bool chord = false}) {
      painter.text = TextSpan(
        text: text,
        style: chord ? chordStyle : textStyle,
      );
      painter.layout();
      return painter.width / size;
    }

    final children = <Widget>[
      if (geometry.left > 0)
        SizedBox(
          width: geometry.left * size,
          child: Text(
            row.leftMargin ?? '',
            style: textStyle.copyWith(fontStyle: FontStyle.italic),
            softWrap: false,
          ),
        ),
    ];
    for (final (i, token) in row.tokens.indexed) {
      final columnWidth = geometry.columnWidth(i, token, formatter, width);
      switch (token) {
        case final GridBar bar:
          children.add(
            SizedBox(
              width: columnWidth * size,
              child: Text(
                row.hideBars ? '' : bar.symbol,
                textAlign: TextAlign.center,
                style: textStyle.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                ),
                softWrap: false,
              ),
            ),
          );
        case final GridChords cell:
          children.add(
            _cell(
              '',
              chordStyle,
              size,
              columnWidth,
              chord: gridChordParts(cell, formatter),
            ),
          );
        case final GridMark mark:
          children.add(
            _cell(
              gridMarkText(mark.symbol),
              textStyle.copyWith(color: barColor),
              size,
              columnWidth,
            ),
          );
        case final GridStrum strum:
          children.add(_cell(strum.symbol, chordStyle, size, columnWidth));
      }
    }
    if (row.rightMargin != null) {
      children.add(SizedBox(width: 0.5 * size));
      children.add(
        Text(
          row.rightMargin!,
          style: textStyle.copyWith(fontStyle: FontStyle.italic),
          softWrap: false,
        ),
      );
    }
    painter.dispose();
    final view = Padding(
      padding: EdgeInsets.symmetric(vertical: 0.15 * size),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    final full = gridWidth == null ? null : gridWidth! * size;
    if (full == null || full <= 0) return view;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (!available.isFinite || full <= available) return view;
        // Every row of the grid gets the width of the widest one and the
        // same scale, so the cells stay in columns.
        return SizedBox(
          width: available,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: full,
              child: Align(alignment: Alignment.centerLeft, child: view),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(
    String text,
    TextStyle style,
    double size,
    double columnWidth, {
    List<ChordPart>? chord,
  }) => SizedBox(
    width: columnWidth * size,
    child: Padding(
      padding: EdgeInsets.only(left: 0.25 * size),
      child: chord != null
          ? ChordText(chord, style: style)
          : Text(
              text,
              style: style,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
    ),
  );
}
