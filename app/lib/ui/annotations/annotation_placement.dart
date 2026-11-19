import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart';
import '../render/line_marks.dart';

/// A stroke as shown on a page: its points and line width in the page's
/// logical pixels.
@immutable
class PlacedStroke {
  const PlacedStroke({
    required this.stroke,
    required this.points,
    required this.width,
    this.orphan = false,
  });

  final AnnotationStroke stroke;
  final List<Offset> points;
  final double width;

  /// Its line is gone: shown faded while drawing only, to move or delete.
  final bool orphan;

  PlacedStroke moved(Offset by) => PlacedStroke(
    stroke: stroke,
    points: [for (final p in points) p + by],
    width: width,
    orphan: orphan,
  );

  Rect get bounds {
    if (stroke.tool == AnnotationTool.text) {
      return points.first & annotationTextSize(stroke.text ?? '', width);
    }
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    return rect.inflate(width / 2);
  }
}

/// Where the strokes of one page go (ADR-0032): in place on the layout they
/// were drawn on, otherwise at their anchor line; and the way back from
/// what is drawn to a stroke.
class PagePlacement {
  PagePlacement({
    required this.width,
    required this.page,
    this.layout,
    this.lines = const [],
    this.font = 20,
    this.songLines,
  });

  /// Width of the page in logical pixels: the unit of the coordinates.
  final double width;

  /// The page shown: for a ChordPro song the page in live mode (0-based),
  /// for a PDF the page number (1-based).
  final int page;

  /// Layout of a ChordPro page; null for a PDF page.
  final LayoutFingerprint? layout;

  /// The rendered lines of the page.
  final List<RenderedLine> lines;

  /// Font size of the page in logical pixels.
  final double font;

  /// Lines of the whole song: a stroke whose anchor line is in the song but
  /// not on this page belongs to another page; one whose line is gone is
  /// orphaned. Null: no orphans (e.g. the song screen).
  final ({Set<int> lines, Set<int> hashes})? songLines;

  bool get isPdf => layout == null;

  /// The stroke on this page, or null when it belongs to another page (or
  /// is orphaned and [withOrphans] is false).
  PlacedStroke? place(AnnotationStroke s, {bool withOrphans = false}) {
    if (isPdf) {
      return s.page == page ? _inPlace(s, width) : null;
    }
    final drawnOn = s.layout;
    if (drawnOn != null && layout!.matches(drawnOn)) {
      return s.page == page ? _inPlace(s, width) : null;
    }
    final anchor = s.anchor;
    final line = anchor == null ? null : _resolve(anchor);
    if (line != null) return _atLine(s, anchor!, line);
    final known = songLines;
    final orphan =
        anchor == null ||
        (known != null &&
            !known.hashes.contains(anchor.hash) &&
            !known.lines.contains(anchor.line));
    if (!orphan || !withOrphans) return null;
    // Shown where it was drawn, on the page it was drawn on (or the last).
    if (s.page != page) return null;
    final placed = _inPlace(s, width);
    return PlacedStroke(
      stroke: s,
      points: placed.points,
      width: placed.width,
      orphan: true,
    );
  }

  static PlacedStroke _inPlace(AnnotationStroke s, double width) =>
      PlacedStroke(
        stroke: s,
        points: [
          for (var i = 0; i + 1 < s.points.length; i += 2)
            Offset(s.points[i] * width, s.points[i + 1] * width),
        ],
        width: s.width * width,
      );

  /// The rendered line of [anchor]: the same text and repetition nearest
  /// to its old line number, else the same text, else the same line number
  /// (a corrected line).
  RenderedLine? _resolve(LineAnchor anchor) {
    RenderedLine? nearest(bool Function(RenderedLine) test) {
      RenderedLine? best;
      for (final l in lines) {
        if (!test(l)) continue;
        if (best == null ||
            (l.mark.line - anchor.line).abs() <
                (best.mark.line - anchor.line).abs()) {
          best = l;
        }
      }
      return best;
    }

    return nearest(
          (l) => l.mark.hash == anchor.hash && l.repeat == anchor.repeat,
        ) ??
        nearest((l) => l.mark.hash == anchor.hash) ??
        nearest((l) => l.mark.line == anchor.line && l.repeat == anchor.repeat);
  }

  PlacedStroke _atLine(AnnotationStroke s, LineAnchor a, RenderedLine line) {
    // Drawn at a width of [drawnWidth]; scaled by the font size.
    final drawnWidth = s.layout?.width ?? width;
    final k = font / a.font;
    final start = Offset(s.points[0] * drawnWidth, s.points[1] * drawnWidth);
    final at = line.rect.topLeft + Offset(a.dx, a.dy) * font;
    return PlacedStroke(
      stroke: s,
      points: [
        for (var i = 0; i + 1 < s.points.length; i += 2)
          at +
              (Offset(s.points[i] * drawnWidth, s.points[i + 1] * drawnWidth) -
                      start) *
                  k,
      ],
      width: s.width * drawnWidth * k,
    );
  }

  /// The anchor of a stroke starting at [p]: the line under it, else the
  /// nearest one; null without lines (e.g. a PDF).
  LineAnchor? anchorAt(Offset p) {
    if (isPdf || lines.isEmpty) return null;
    RenderedLine? best;
    var bestDistance = double.infinity;
    for (final l in lines) {
      final dx = p.dx < l.rect.left
          ? l.rect.left - p.dx
          : p.dx > l.rect.right
          ? p.dx - l.rect.right
          : 0.0;
      final dy = p.dy < l.rect.top
          ? l.rect.top - p.dy
          : p.dy > l.rect.bottom
          ? p.dy - l.rect.bottom
          : 0.0;
      // Vertical distance counts more: a mark beside a line belongs to it.
      final d = dy * 4 + dx;
      if (d < bestDistance) {
        bestDistance = d;
        best = l;
      }
    }
    final line = best!;
    return LineAnchor(
      line: line.mark.line,
      hash: line.mark.hash,
      repeat: line.repeat,
      dx: (p.dx - line.rect.left) / font,
      dy: (p.dy - line.rect.top) / font,
      font: font,
    );
  }

  /// A stroke as drawn on this page: [points] and [lineWidth] in logical
  /// pixels, stored for this page and layout with a new anchor.
  AnnotationStroke toStroke({
    required String id,
    required AnnotationTool tool,
    required int color,
    required List<Offset> points,
    required double lineWidth,
    List<double>? pressure,
    AnnotationStamp? stamp,
    String? text,
  }) => AnnotationStroke(
    id: id,
    tool: tool,
    color: color,
    width: lineWidth / width,
    points: [
      for (final p in points) ...[p.dx / width, p.dy / width],
    ],
    pressure: pressure,
    stamp: stamp,
    text: text,
    page: page,
    layout: layout,
    anchor: anchorAt(points.first),
  );

  /// [placed] after an edit on this page (moved, resized, recoloured,
  /// erased in part): stored for this page and layout, anchored anew.
  AnnotationStroke restore(
    PlacedStroke placed, {
    String? id,
    List<Offset>? points,
    double? lineWidth,
    int? color,
    List<double>? pressure,
    String? text,
  }) {
    final s = placed.stroke;
    return toStroke(
      id: id ?? s.id,
      tool: s.tool,
      color: color ?? s.color,
      points: points ?? placed.points,
      lineWidth: lineWidth ?? placed.width,
      pressure: points == null ? s.pressure : pressure,
      stamp: s.stamp,
      text: text ?? s.text,
    );
  }
}

/// Simplifies a drawn line (in logical pixels) for storage; [pressure]
/// follows the kept points.
(List<Offset>, List<double>?) simplifyStroke(
  List<Offset> points,
  List<double>? pressure, {
  double tolerance = 0.6,
}) {
  final flat = [
    for (final p in points) ...[p.dx, p.dy],
  ];
  final keep = simplifyIndices(flat, tolerance);
  return (
    [for (final i in keep) points[i]],
    pressure == null ? null : [for (final i in keep) pressure[i]],
  );
}

/// Scales [points] by [factor] around [center].
List<Offset> scaleAround(List<Offset> points, Offset center, double factor) => [
  for (final p in points) center + (p - center) * factor,
];

/// Size of a stamp drawn with [lineWidth]: stamps are larger than lines.
double stampSize(double lineWidth) => math.max(lineWidth * 8, 16);

/// Style of a text annotation at [fontSize] (#570); its colour comes from
/// the palette.
TextStyle annotationTextStyle(double fontSize, {Color? color}) => TextStyle(
  color: color,
  fontSize: fontSize,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

/// Size of [text] as a text annotation at [fontSize] (lines are not
/// wrapped).
Size annotationTextSize(String text, double fontSize) {
  final key = (text, fontSize);
  final cached = _textSizes[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    text: TextSpan(text: text, style: annotationTextStyle(fontSize)),
    textDirection: TextDirection.ltr,
  )..layout();
  final size = painter.size;
  painter.dispose();
  if (_textSizes.length > 200) _textSizes.clear();
  return _textSizes[key] = size;
}

final _textSizes = <(String, double), Size>{};
