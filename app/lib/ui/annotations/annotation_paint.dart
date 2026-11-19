import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/annotation.dart';
import 'annotation_placement.dart';

/// The annotation palette (ADR-0032): one shade per brightness, so a stroke
/// stays readable on the light theme and on the black stage appearance. A
/// stroke stores the index.
const _lightPalette = [
  Color(0xFFD32F2F), // red
  Color(0xFF1565C0), // blue
  Color(0xFF2E7D32), // green
  Color(0xFFEF6C00), // orange
  Color(0xFF7B1FA2), // purple
  Color(0xFF212121), // black
];
const _darkPalette = [
  Color(0xFFFF6E6E),
  Color(0xFF6EB4FF),
  Color(0xFF7BDB7F),
  Color(0xFFFFB04D),
  Color(0xFFD48CFF),
  Color(0xFFF5F5F5), // white
];

/// The colour of palette entry [index] on a background of [brightness].
Color annotationColor(int index, Brightness brightness) {
  final palette = brightness == Brightness.dark ? _darkPalette : _lightPalette;
  return palette[index.clamp(0, palette.length - 1)];
}

/// Opacity of the highlighter.
const highlighterOpacity = 0.35;

/// Paints placed strokes: pens and stamps, or (with [highlighters]) only the
/// highlighter strokes, which go behind the text.
void paintStrokes(
  Canvas canvas,
  Iterable<PlacedStroke> strokes, {
  required Brightness brightness,
  required bool highlighters,
  Set<String> selected = const {},
  Offset selectionOffset = Offset.zero,
}) {
  for (final placed in strokes) {
    final isHighlighter = placed.stroke.tool == AnnotationTool.highlighter;
    if (isHighlighter != highlighters) continue;
    final moved = selected.contains(placed.stroke.id);
    final p = moved && selectionOffset != Offset.zero
        ? placed.moved(selectionOffset)
        : placed;
    var color = annotationColor(p.stroke.color, brightness);
    if (isHighlighter) color = color.withValues(alpha: highlighterOpacity);
    if (p.orphan) color = color.withValues(alpha: color.a * 0.4);
    if (moved) _paintSelection(canvas, p, brightness);
    paintStroke(canvas, p, color);
  }
}

void _paintSelection(Canvas canvas, PlacedStroke p, Brightness brightness) {
  final halo = Paint()
    ..color = (brightness == Brightness.dark ? Colors.white : Colors.black)
        .withValues(alpha: 0.18)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = p.width + 8;
  if (p.stroke.tool == AnnotationTool.stamp) {
    canvas.drawCircle(p.points.first, p.width * 0.65, halo);
  } else if (p.stroke.tool == AnnotationTool.text) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(p.bounds.inflate(4), const Radius.circular(4)),
      Paint()..color = halo.color,
    );
  } else {
    canvas.drawPath(_path(p.points), halo);
  }
}

/// Paints one placed stroke in [color].
void paintStroke(Canvas canvas, PlacedStroke p, Color color) {
  final s = p.stroke;
  if (s.tool == AnnotationTool.stamp) {
    paintStamp(canvas, s.stamp!, p.points.first, p.width, color);
    return;
  }
  if (s.tool == AnnotationTool.text) {
    paintText(canvas, s.text ?? '', p.points.first, p.width, color);
    return;
  }
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = s.tool == AnnotationTool.highlighter
        ? StrokeCap.square
        : StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final points = p.points;
  if (points.length == 1) {
    canvas.drawCircle(points.first, p.width / 2, Paint()..color = color);
    return;
  }
  // Pressure only when it belongs to these points (not to a piece of the
  // stroke while it is being erased).
  final pressure = s.pressure?.length == points.length ? s.pressure : null;
  if (pressure == null || s.tool != AnnotationTool.pen) {
    paint.strokeWidth = p.width;
    canvas.drawPath(_path(points), paint);
    return;
  }
  // Pressure: segments of their own width (0.4 to 1.4 of the width).
  for (var i = 1; i < points.length; i++) {
    final w = (pressure[i - 1] + pressure[i]) / 2;
    paint.strokeWidth = p.width * (0.4 + w);
    canvas.drawLine(points[i - 1], points[i], paint);
  }
}

/// Paints a text annotation: [text] with its top left corner at [at] in
/// [fontSize].
void paintText(
  Canvas canvas,
  String text,
  Offset at,
  double fontSize,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: annotationTextStyle(fontSize, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
  painter.dispose();
}

/// A smooth path through [points] (quadratic curves through the midpoints).
Path _path(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) {
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }
  for (var i = 1; i < points.length - 1; i++) {
    final mid = (points[i] + points[i + 1]) / 2;
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

/// Paints [stamp] centred on [center], [size] wide.
void paintStamp(
  Canvas canvas,
  AnnotationStamp stamp,
  Offset center,
  double size,
  Color color,
) {
  final s = size / 2;
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, size * 0.07)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..color = color;
  final c = center;
  void text(String t, {double scale = 0.75, FontWeight? weight}) {
    final painter = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: color,
          fontSize: size * scale,
          fontWeight: weight ?? FontWeight.bold,
          fontStyle: FontStyle.italic,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, c - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  void icon(IconData data) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(data.codePoint),
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: data.fontFamily,
          package: data.fontPackage,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, c - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  switch (stamp) {
    case AnnotationStamp.fermata:
      canvas.drawArc(
        Rect.fromCircle(center: c + Offset(0, s * 0.35), radius: s * 0.85),
        math.pi,
        math.pi,
        false,
        line,
      );
      canvas.drawCircle(c + Offset(0, s * 0.15), s * 0.14, fill);
    case AnnotationStamp.breath:
      // A comma above the staff.
      canvas.drawCircle(c + Offset(0, -s * 0.25), s * 0.22, fill);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + s * 0.2, c.dy - s * 0.2)
          ..quadraticBezierTo(
            c.dx + s * 0.2,
            c.dy + s * 0.4,
            c.dx - s * 0.25,
            c.dy + s * 0.6,
          ),
        line,
      );
    case AnnotationStamp.crescendo:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + s, c.dy - s * 0.4)
          ..lineTo(c.dx - s, c.dy)
          ..lineTo(c.dx + s, c.dy + s * 0.4),
        line,
      );
    case AnnotationStamp.decrescendo:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - s, c.dy - s * 0.4)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx - s, c.dy + s * 0.4),
        line,
      );
    case AnnotationStamp.ritardando:
      text('rit.', scale: 0.6);
    case AnnotationStamp.accent:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - s * 0.6, c.dy - s * 0.3)
          ..lineTo(c.dx + s * 0.6, c.dy)
          ..lineTo(c.dx - s * 0.6, c.dy + s * 0.3),
        line..strokeWidth = line.strokeWidth * 1.4,
      );
    case AnnotationStamp.repeat2:
      text('×2');
    case AnnotationStamp.repeat3:
      text('×3');
    case AnnotationStamp.repeat4:
      text('×4');
    case AnnotationStamp.repeatStart || AnnotationStamp.repeatEnd:
      // Thick bar, thin bar, two dots (mirrored for the end).
      final dir = stamp == AnnotationStamp.repeatStart ? 1.0 : -1.0;
      final thick = Paint()
        ..color = color
        ..strokeWidth = size * 0.14;
      final x0 = c.dx - dir * s * 0.45;
      canvas.drawLine(Offset(x0, c.dy - s), Offset(x0, c.dy + s), thick);
      final x1 = c.dx - dir * s * 0.1;
      canvas.drawLine(Offset(x1, c.dy - s), Offset(x1, c.dy + s), line);
      final x2 = c.dx + dir * s * 0.3;
      canvas.drawCircle(Offset(x2, c.dy - s * 0.3), s * 0.12, fill);
      canvas.drawCircle(Offset(x2, c.dy + s * 0.3), s * 0.12, fill);
    case AnnotationStamp.coda:
      canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 1.2, height: s * 1.5),
        line,
      );
      canvas.drawLine(c - Offset(s, 0), c + Offset(s, 0), line);
      canvas.drawLine(c - Offset(0, s), c + Offset(0, s), line);
    case AnnotationStamp.segno:
      text('S', scale: 0.95, weight: FontWeight.w400);
      canvas.drawLine(
        c + Offset(-s * 0.6, s * 0.7),
        c + Offset(s * 0.6, -s * 0.7),
        line,
      );
      canvas.drawCircle(c + Offset(-s * 0.55, -s * 0.15), s * 0.1, fill);
      canvas.drawCircle(c + Offset(s * 0.55, s * 0.15), s * 0.1, fill);
    case AnnotationStamp.glasses:
      canvas.drawCircle(c + Offset(-s * 0.45, 0), s * 0.35, line);
      canvas.drawCircle(c + Offset(s * 0.45, 0), s * 0.35, line);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: s * 0.12),
        math.pi,
        math.pi,
        false,
        line,
      );
      canvas.drawLine(c + Offset(-s * 0.8, 0), c + Offset(-s, -s * 0.25), line);
      canvas.drawLine(c + Offset(s * 0.8, 0), c + Offset(s, -s * 0.25), line);
    case AnnotationStamp.stop:
      icon(Icons.front_hand_outlined);
    case AnnotationStamp.eye:
      icon(Icons.visibility_outlined);
    case AnnotationStamp.exclamation:
      icon(Icons.priority_high);
    case AnnotationStamp.star:
      icon(Icons.star_outline);
  }
}
