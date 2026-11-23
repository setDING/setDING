import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// Personal freehand annotations (ADR-0032): the model of one stroke or
/// stamp, its JSON form (as synced) and the geometry that does not depend on
/// the UI.
///
/// Coordinates are normalized to the **page width** on both axes (so shapes
/// keep their proportions): x = 0…1 across the page, y = 0… down the page.
/// For a ChordPro song the page is a page of live mode (or the scrolled
/// body), for a PDF attachment a page of the PDF.

/// What draws a stroke.
enum AnnotationTool {
  /// Opaque line, width follows the stylus pressure.
  pen,

  /// Translucent wide line, drawn behind the text.
  highlighter,

  /// A symbol from [AnnotationStamp], placed with a tap.
  stamp,

  /// Text typed with the keyboard, placed with a tap (#570). Its one point
  /// is the top left corner of the text, its width the font size.
  text,
}

/// Most characters of a text annotation.
const annotationTextMaxLength = 500;

/// Symbols that are placed with a tap (ADR-0032).
enum AnnotationStamp {
  // Music marks.
  fermata,
  breath,
  crescendo,
  decrescendo,
  ritardando,
  accent,
  // Repeats.
  repeat2,
  repeat3,
  repeat4,
  repeatStart,
  repeatEnd,
  coda,
  segno,
  // Cues.
  glasses,
  stop,
  eye,
  exclamation,
  star;

  static AnnotationStamp? byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Number of colours of the annotation palette; a stroke stores the index,
/// the UI maps it to a shade per appearance (light, dark, stage).
const annotationColorCount = 6;

/// A rendered line a ChordPro stroke falls back to on another layout: the
/// line's source line number, a fingerprint of its text and which
/// repetition of the line it is (a chorus shown twice), and the offset of
/// the stroke's first point from the line's top left corner in units of the
/// font size ([font] at the time of drawing, in logical pixels).
@immutable
class LineAnchor {
  const LineAnchor({
    required this.line,
    required this.hash,
    this.repeat = 0,
    required this.dx,
    required this.dy,
    required this.font,
  });

  final int line;
  final int hash;
  final int repeat;
  final double dx;
  final double dy;
  final double font;

  Map<String, Object> toJson() => {
    'line': line,
    'hash': hash,
    if (repeat != 0) 'repeat': repeat,
    'dx': _round(dx),
    'dy': _round(dy),
    'font': _round(font),
  };

  static LineAnchor? fromJson(Object? json) {
    if (json is! Map) return null;
    final line = json['line'], hash = json['hash'];
    final dx = json['dx'], dy = json['dy'], font = json['font'];
    if (line is! num || hash is! num || dx is! num || dy is! num) return null;
    if (font is! num || font <= 0) return null;
    return LineAnchor(
      line: line.toInt(),
      hash: hash.toInt(),
      repeat: (json['repeat'] as num?)?.toInt() ?? 0,
      dx: dx.toDouble(),
      dy: dy.toDouble(),
      font: font.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LineAnchor &&
      other.line == line &&
      other.hash == hash &&
      other.repeat == repeat &&
      other.dx == dx &&
      other.dy == dy &&
      other.font == font;

  @override
  int get hashCode => Object.hash(line, hash, repeat, dx, dy, font);
}

/// The layout a ChordPro page was drawn on (ADR-0032). Strokes drawn on the
/// same layout are shown exactly where they were drawn; on another one they
/// fall back to their [LineAnchor].
@immutable
class LayoutFingerprint {
  const LayoutFingerprint({
    required this.mode,
    this.pages = 1,
    required this.width,
    required this.height,
    required this.font,
    this.columns = 1,
    this.lyricsOnly = false,
    this.verseChords = 'all',
    this.stackedChoruses = false,
    this.chorusOnce = false,
    required this.content,
    this.sequence = '',
  });

  /// `page` (live mode split into pages), `scroll` (live mode scrolling) or
  /// `screen` (the song screen, never drawn on).
  final String mode;

  /// Pages of the song in live mode.
  final int pages;

  /// Size of the page area and font size, in logical pixels.
  final double width;
  final double height;
  final double font;
  final int columns;
  final bool lyricsOnly;

  /// How verses show their chords (`VerseChords` name): chords in the
  /// first verse only (#518) or stacked verses (#521) change the layout.
  final String verseChords;

  /// Choruses stacked (#953) change the layout, too.
  final bool stackedChoruses;

  /// Whether choruses written out again are left out (#955).
  final bool chorusOnce;

  /// [textHash] of the ChordPro text.
  final int content;

  /// Sequence shown (set, band arrangement or song), empty for all parts.
  final String sequence;

  /// Relative difference of size and font size still taken as the same
  /// layout, e.g. when a system bar comes or goes.
  static const tolerance = 0.05;

  /// Whether a stroke drawn on [other] can be shown in place on this layout.
  bool matches(LayoutFingerprint other) {
    bool near(double a, double b) =>
        a > 0 && b > 0 && (a - b).abs() / math.max(a, b) <= tolerance;
    return mode == other.mode &&
        mode != 'screen' &&
        pages == other.pages &&
        columns == other.columns &&
        lyricsOnly == other.lyricsOnly &&
        verseChords == other.verseChords &&
        stackedChoruses == other.stackedChoruses &&
        chorusOnce == other.chorusOnce &&
        content == other.content &&
        sequence == other.sequence &&
        near(width, other.width) &&
        (mode == 'scroll' || near(height, other.height)) &&
        near(font, other.font);
  }

  /// Whether this is a landscape layout (for the hint on another layout).
  bool get landscape => width > height;

  Map<String, Object> toJson() => {
    'mode': mode,
    'pages': pages,
    'w': _round(width),
    'h': _round(height),
    'font': _round(font),
    'cols': columns,
    if (lyricsOnly) 'lyrics': true,
    if (verseChords != 'all') 'verses': verseChords,
    if (stackedChoruses) 'choruses': true,
    if (chorusOnce) 'chorus1': true,
    'content': content,
    if (sequence.isNotEmpty) 'seq': sequence,
  };

  static LayoutFingerprint? fromJson(Object? json) {
    if (json is! Map) return null;
    final mode = json['mode'], w = json['w'], h = json['h'];
    final font = json['font'], content = json['content'];
    if (mode is! String || w is! num || h is! num || font is! num) return null;
    if (content is! num) return null;
    return LayoutFingerprint(
      mode: mode,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      width: w.toDouble(),
      height: h.toDouble(),
      font: font.toDouble(),
      columns: (json['cols'] as num?)?.toInt() ?? 1,
      lyricsOnly: json['lyrics'] == true,
      // `verse1` was the boolean of #518 before #521.
      verseChords:
          json['verses'] as String? ??
          (json['verse1'] == true ? 'first' : 'all'),
      stackedChoruses: json['choruses'] == true,
      chorusOnce: json['chorus1'] == true,
      content: content.toInt(),
      sequence: json['seq'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LayoutFingerprint &&
      other.mode == mode &&
      other.pages == pages &&
      other.width == width &&
      other.height == height &&
      other.font == font &&
      other.columns == columns &&
      other.lyricsOnly == lyricsOnly &&
      other.verseChords == verseChords &&
      other.stackedChoruses == stackedChoruses &&
      other.chorusOnce == chorusOnce &&
      other.content == content &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(
    mode,
    pages,
    width,
    height,
    font,
    columns,
    lyricsOnly,
    verseChords,
    stackedChoruses,
    chorusOnce,
    content,
    sequence,
  );
}

/// One stroke or stamp (ADR-0032).
@immutable
class AnnotationStroke {
  const AnnotationStroke({
    required this.id,
    required this.tool,
    this.color = 0,
    required this.width,
    required this.points,
    this.pressure,
    this.stamp,
    this.text,
    this.page = 0,
    this.layout,
    this.anchor,
  });

  /// UUID, the key of the stroke in the synced record.
  final String id;
  final AnnotationTool tool;

  /// Index into the palette (0 … [annotationColorCount] − 1).
  final int color;

  /// Line width (stamp size, font size of a text) as a share of the page
  /// width.
  final double width;

  /// x0, y0, x1, y1, … normalized to the page width. A stamp has one point,
  /// its centre; a text one point, its top left corner.
  final List<double> points;

  /// Stylus pressure per point (0 … 1); null without pressure.
  final List<double>? pressure;

  /// The symbol of a [AnnotationTool.stamp].
  final AnnotationStamp? stamp;

  /// The text of an [AnnotationTool.text] (lines separated by `\n`).
  final String? text;

  /// Page: for a ChordPro song the page in live mode (0-based), for a PDF
  /// the page number (1-based).
  final int page;

  /// Layout drawn on; null for a PDF.
  final LayoutFingerprint? layout;

  /// Fallback for another layout; null for a PDF or when no line was near.
  final LineAnchor? anchor;

  int get pointCount => points.length ~/ 2;

  AnnotationStroke copyWith({
    String? id,
    int? color,
    double? width,
    List<double>? points,
    List<double>? pressure,
    String? text,
    int? page,
    LayoutFingerprint? layout,
    LineAnchor? anchor,
    bool clearAnchor = false,
  }) => AnnotationStroke(
    id: id ?? this.id,
    tool: tool,
    color: color ?? this.color,
    width: width ?? this.width,
    points: points ?? this.points,
    pressure: pressure ?? this.pressure,
    stamp: stamp,
    text: text ?? this.text,
    page: page ?? this.page,
    layout: layout ?? this.layout,
    anchor: clearAnchor ? null : anchor ?? this.anchor,
  );

  /// Bounding box (left, top, right, bottom) of the points.
  (double, double, double, double) get bounds {
    var l = double.infinity, t = double.infinity;
    var r = double.negativeInfinity, b = double.negativeInfinity;
    for (var i = 0; i + 1 < points.length; i += 2) {
      l = math.min(l, points[i]);
      r = math.max(r, points[i]);
      t = math.min(t, points[i + 1]);
      b = math.max(b, points[i + 1]);
    }
    return (l, t, r, b);
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'tool': tool.name,
    'color': color,
    'width': _round(width),
    'pts': encodePoints(points),
    if (pressure case final p?) 'pr': encodePressure(p),
    if (stamp case final s?) 'stamp': s.name,
    'text': ?text,
    'page': page,
    if (layout case final l?) 'layout': l.toJson(),
    if (anchor case final a?) 'anchor': a.toJson(),
  };

  /// A stroke from its JSON form; null for a tombstone, an unknown tool
  /// (from a newer app version) or broken data.
  static AnnotationStroke? fromJson(String id, Object? json) {
    if (json is! Map || json['deleted'] == true) return null;
    final tool = AnnotationTool.values
        .where((t) => t.name == json['tool'])
        .firstOrNull;
    final width = json['width'], pts = json['pts'];
    if (tool == null || width is! num || pts is! String) return null;
    final points = decodePoints(pts);
    if (points == null || points.length < 2) return null;
    final stamp = AnnotationStamp.byName(json['stamp'] as String?);
    if (tool == AnnotationTool.stamp && stamp == null) return null;
    final text = json['text'];
    if (tool == AnnotationTool.text &&
        (text is! String || text.trim().isEmpty)) {
      return null;
    }
    final pressure = switch (json['pr']) {
      final String p => decodePressure(p),
      _ => null,
    };
    return AnnotationStroke(
      id: id,
      tool: tool,
      color: ((json['color'] as num?)?.toInt() ?? 0).clamp(
        0,
        annotationColorCount - 1,
      ),
      width: width.toDouble(),
      points: points,
      pressure: pressure?.length == points.length ~/ 2 ? pressure : null,
      stamp: stamp,
      text: tool == AnnotationTool.text ? text as String : null,
      page: (json['page'] as num?)?.toInt() ?? 0,
      layout: LayoutFingerprint.fromJson(json['layout']),
      anchor: LineAnchor.fromJson(json['anchor']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnnotationStroke &&
      jsonEncode(toJson()) == jsonEncode(other.toJson()) &&
      other.id == id;

  @override
  int get hashCode => Object.hash(id, jsonEncode(toJson()));
}

/// Tombstone of an erased stroke in the synced record; the server prunes it
/// after 90 days ([t] = time of the erase in ms).
Map<String, Object> annotationTombstone(int t) => {'deleted': true, 't': t};

// Encoding ---------------------------------------------------------------------

const _scale = 10000;

double _round(double v) => (v * 1000).roundToDouble() / 1000;

/// Points as base64 of little-endian 32-bit integers (1/10000 of the page
/// width).
String encodePoints(List<double> points) {
  final data = ByteData(points.length * 4);
  for (final (i, p) in points.indexed) {
    data.setInt32(i * 4, (p * _scale).round(), Endian.little);
  }
  return base64Encode(data.buffer.asUint8List());
}

List<double>? decodePoints(String encoded) {
  try {
    final bytes = base64Decode(encoded);
    if (bytes.length % 8 != 0) return null;
    final data = ByteData.sublistView(bytes);
    return [
      for (var i = 0; i < bytes.length; i += 4)
        data.getInt32(i, Endian.little) / _scale,
    ];
  } on FormatException {
    return null;
  }
}

/// Pressure as base64 of one byte per point.
String encodePressure(List<double> pressure) => base64Encode(
  Uint8List.fromList([
    for (final p in pressure) (p.clamp(0.0, 1.0) * 255).round(),
  ]),
);

List<double>? decodePressure(String encoded) {
  try {
    return [for (final b in base64Decode(encoded)) b / 255];
  } on FormatException {
    return null;
  }
}

/// A stable 32-bit hash (FNV-1a) of [text], the same on every platform and
/// app run (unlike [String.hashCode]).
int textHash(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

// Geometry ---------------------------------------------------------------------

/// Simplifies a polyline (x0, y0, x1, y1, …) with Ramer–Douglas–Peucker:
/// points closer than [epsilon] to the simplified line are dropped. Returns
/// the indices of the kept points (first and last always).
List<int> simplifyIndices(List<double> points, double epsilon) {
  final n = points.length ~/ 2;
  if (n <= 2) return [for (var i = 0; i < n; i++) i];
  final keep = List<bool>.filled(n, false)
    ..[0] = true
    ..[n - 1] = true;
  final stack = <(int, int)>[(0, n - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var maxD = 0.0;
    var index = -1;
    for (var i = a + 1; i < b; i++) {
      final d = _segmentDistance(points, i, a, b);
      if (d > maxD) {
        maxD = d;
        index = i;
      }
    }
    if (index >= 0 && maxD > epsilon) {
      keep[index] = true;
      stack
        ..add((a, index))
        ..add((index, b));
    }
  }
  return [
    for (var i = 0; i < n; i++)
      if (keep[i]) i,
  ];
}

double _segmentDistance(List<double> p, int i, int a, int b) => pointToSegment(
  p[2 * i],
  p[2 * i + 1],
  p[2 * a],
  p[2 * a + 1],
  p[2 * b],
  p[2 * b + 1],
);

/// Distance of (px, py) to the segment (ax, ay)–(bx, by).
double pointToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final len = dx * dx + dy * dy;
  var t = len == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len;
  t = t.clamp(0.0, 1.0);
  final x = ax + t * dx - px, y = ay + t * dy - py;
  return math.sqrt(x * x + y * y);
}

/// Whether (x, y) lies inside the closed [polygon] (x0, y0, x1, y1, …).
bool pointInPolygon(double x, double y, List<double> polygon) {
  var inside = false;
  final n = polygon.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = polygon[2 * i], yi = polygon[2 * i + 1];
    final xj = polygon[2 * j], yj = polygon[2 * j + 1];
    if ((yi > y) != (yj > y) &&
        x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// Splits the stroke [points] where they come within [radius] of (x, y)
/// (partial eraser): the pieces outside, each with at least two points, as
/// lists of point indices. Null when nothing is erased.
List<List<int>>? eraseAround(
  List<double> points,
  double x,
  double y,
  double radius,
) {
  final n = points.length ~/ 2;
  final pieces = <List<int>>[];
  var current = <int>[];
  var erased = false;
  for (var i = 0; i < n; i++) {
    final dx = points[2 * i] - x, dy = points[2 * i + 1] - y;
    final near = dx * dx + dy * dy <= radius * radius;
    // A segment passing through the eraser counts too.
    final crossing =
        !near &&
        i > 0 &&
        pointToSegment(
              x,
              y,
              points[2 * i - 2],
              points[2 * i - 1],
              points[2 * i],
              points[2 * i + 1],
            ) <=
            radius &&
        current.isNotEmpty;
    if (near || crossing) {
      erased = true;
      if (current.length >= 2) pieces.add(current);
      current = near ? <int>[] : <int>[i];
    } else {
      current.add(i);
    }
  }
  if (!erased) return null;
  if (current.length >= 2) pieces.add(current);
  return pieces;
}

/// Whether the stroke [points] come within [radius] of (x, y).
bool strokeNear(List<double> points, double x, double y, double radius) {
  final n = points.length ~/ 2;
  if (n == 1) {
    final dx = points[0] - x, dy = points[1] - y;
    return dx * dx + dy * dy <= radius * radius;
  }
  for (var i = 1; i < n; i++) {
    if (pointToSegment(
          x,
          y,
          points[2 * i - 2],
          points[2 * i - 1],
          points[2 * i],
          points[2 * i + 1],
        ) <=
        radius) {
      return true;
    }
  }
  return false;
}

/// Most stroke data the server keeps per song and target (the `data` field
/// of an `annotations` record, ADR-0032), in bytes.
const annotationMaxBytes = 1000000;

/// From this share of [annotationMaxBytes] on, drawing mode warns.
const annotationWarnShare = 0.8;

/// New strokes would make the annotations of a song and target larger than
/// [annotationMaxBytes]: they are not stored.
class AnnotationsFullException implements Exception {
  const AnnotationsFullException();

  @override
  String toString() => 'AnnotationsFullException';
}
