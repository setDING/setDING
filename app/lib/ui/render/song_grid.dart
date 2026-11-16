import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

/// Measures a text width in units of the grid font size.
typedef GridTextWidth = double Function(String text, {bool chord});

/// Geometry of a grid section, in units of the grid font size. Shared by
/// rendering and layout measurement (ADR-0012).
class GridGeometry {
  const GridGeometry({required this.cell, required this.left});

  /// Width of one cell.
  final double cell;

  /// Width of the left margin.
  final double left;

  static const rowHeight = 1.25 + 0.3;
  static const barPadding = 0.3;
  static const minCell = 1.6;

  /// Width of a bar symbol.
  static double barWidth(String symbol, GridTextWidth width) =>
      math.max(0.9, width(symbol) + barPadding);

  /// Width of a whole row.
  double rowWidth(GridRow row, ChordFormatter formatter, GridTextWidth width) {
    var total = row.leftMargin == null && left == 0 ? 0.0 : left;
    for (final token in row.tokens) {
      total += token is GridBar ? barWidth(token.symbol, width) : cell;
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
    var cell = minCell;
    var left = 0.0;
    for (final line in lines) {
      if (line is! GridLine) continue;
      final row = line.row;
      if (row.leftMargin != null) {
        left = math.max(left, width(row.leftMargin!) + 0.6);
      }
      for (final token in row.tokens) {
        if (token is GridChords) {
          // Several chords in one cell may spill into the next cell, so
          // only single chords decide the cell width.
          for (final chord in token.chords) {
            cell = math.max(
              cell,
              width(formatter.format(chord), chord: true) + 0.5,
            );
          }
        }
      }
    }
    return GridGeometry(cell: cell, left: left);
  }
}

/// Text of a grid cell with one or more chords.
String gridChordText(GridChords cell, ChordFormatter formatter) =>
    cell.chords.map(formatter.format).join(' ');

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
    required this.formatter,
    required this.textStyle,
    required this.chordStyle,
    required this.barColor,
  });

  final GridRow row;
  final GridGeometry geometry;
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
    for (final token in row.tokens) {
      switch (token) {
        case final GridBar bar:
          children.add(
            SizedBox(
              width: GridGeometry.barWidth(bar.symbol, width) * size,
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
          children.add(_cell(gridChordText(cell, formatter), chordStyle, size));
        case final GridMark mark:
          children.add(
            _cell(
              gridMarkText(mark.symbol),
              textStyle.copyWith(color: barColor),
              size,
            ),
          );
        case final GridStrum strum:
          children.add(_cell(strum.symbol, chordStyle, size));
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.15 * size),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _cell(String text, TextStyle style, double size) => SizedBox(
    width: geometry.cell * size,
    child: Padding(
      padding: EdgeInsets.only(left: 0.25 * size),
      child: Text(
        text,
        style: style,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    ),
  );
}
