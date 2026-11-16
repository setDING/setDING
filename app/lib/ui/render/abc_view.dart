import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';

import 'song_image.dart';

/// Staff space (distance between two staff lines) relative to the font
/// size.
const abcStaffSpace = 0.5;

/// Horizontal and vertical layout of one ABC staff line, in staff spaces.
class AbcLineLayout {
  AbcLineLayout._(
    this.line,
    this.items,
    this.width,
    this.top,
    this.bottom,
    this.key,
    this.meter,
  );

  final AbcLine line;
  final List<AbcPlaced> items;

  /// Total width in staff spaces.
  final double width;

  /// Space above the top staff line and below the bottom staff line.
  final double top;
  final double bottom;

  /// Key signature at the start of the line.
  final AbcKey key;

  /// Meter shown at the start of the line (first line only).
  final String? meter;

  double get height => top + 4 + bottom;

  /// Size and placement as an image box (shrinks to the column width).
  ImageBox get box => ImageBox(
    widthUnits: width * abcStaffSpace,
    aspect: width / height,
    alignment: Alignment.centerLeft,
  );
}

/// An element placed on a staff line.
class AbcPlaced {
  AbcPlaced(this.element, this.x, {this.accidentalSpace = 0});

  final AbcElement element;

  /// x of the note head (or bar) in staff spaces.
  final double x;
  final double accidentalSpace;
}

/// y of a pitch in staff spaces (0 = top line, 4 = bottom line).
double _pitchY(AbcPitch p, bool bass) =>
    bass ? 4 - (p.step + 10) * 0.5 : 4 - (p.step - 2) * 0.5;

const _baseDurations = [1.0, 0.5, 0.25, 0.125, 0.0625, 0.03125];

/// Base duration and dots of [duration] (whole note = 1).
(double, int) _noteValue(double duration) {
  for (final base in _baseDurations) {
    if ((duration - base).abs() < 1e-6) return (base, 0);
    if ((duration - base * 1.5).abs() < 1e-6) return (base, 1);
    if ((duration - base * 1.75).abs() < 1e-6) return (base, 2);
  }
  // Tuplets and odd values: nearest smaller base.
  for (final base in _baseDurations) {
    if (duration >= base * 0.6) return (base, 0);
  }
  return (_baseDurations.last, 0);
}

/// The tune of an ABC delegate, transposed by [semitones].
AbcTune abcTuneOf(DelegateSection d, int semitones) {
  final tune = parseAbc(d.content);
  return semitones == 0 ? tune : transposeAbc(tune, semitones);
}

/// Height in pixels of [tune] laid out at [fontSize] in [columnWidth].
double abcHeight(AbcTune tune, double fontSize, double columnWidth) {
  final staffSpace = fontSize * abcStaffSpace;
  var height = 0.0;
  for (final row in layoutAbc(tune, maxWidth: columnWidth / staffSpace)) {
    height += row.box.height(fontSize, columnWidth);
  }
  return height;
}

/// Lays out [tune] line by line. With [maxWidth] (in staff spaces), lines
/// that are too long are broken at bar lines.
List<AbcLineLayout> layoutAbc(AbcTune tune, {double? maxWidth}) {
  final result = <AbcLineLayout>[];
  var key = tune.key;
  String? meter = tune.meter.isEmpty || tune.meter == 'none'
      ? null
      : tune.meter;

  AbcKey keyAfter(AbcKey start, List<AbcElement> elements) {
    var k = start;
    for (final e in elements) {
      if (e is AbcKeyChange) k = e.key;
    }
    return k;
  }

  void emit(List<AbcElement> row) {
    if (row.isEmpty) return;
    result.add(_layoutRow(row, key, meter, tune.bassClef));
    key = keyAfter(key, row);
    meter = null;
  }

  for (final line in tune.lines) {
    // Measures: split after each bar line.
    final chunks = <List<AbcElement>>[];
    var chunk = <AbcElement>[];
    for (final e in line.elements) {
      // A bar starting a volta begins the next measure, so the bracket is
      // drawn over it even after a line break.
      if (e is AbcBar && e.volta != null && chunk.any((x) => x is! AbcBar)) {
        chunks.add(chunk);
        chunk = [e];
        continue;
      }
      chunk.add(e);
      // A bar ends a measure, but a chunk with only bars (e.g. a leading
      // repeat sign) stays with the following measure.
      if (e is AbcBar && e.volta == null && chunk.any((x) => x is! AbcBar)) {
        chunks.add(chunk);
        chunk = [];
      }
    }
    if (chunk.isNotEmpty) chunks.add(chunk);

    var row = <AbcElement>[];
    for (final c in chunks) {
      final candidate = [...row, ...c];
      if (row.isNotEmpty &&
          maxWidth != null &&
          _layoutRow(candidate, key, meter, tune.bassClef).width > maxWidth) {
        emit(row);
        row = [...c];
      } else {
        row = candidate;
      }
    }
    emit(row);
  }
  return result;
}

AbcLineLayout _layoutRow(
  List<AbcElement> elements,
  AbcKey startKey,
  String? meter,
  bool bass,
) {
  final items = <AbcPlaced>[];
  var key = startKey;
  var x = 0.5 + 3.2; // clef
  x += key.signatureLetters.length * 1.0 + 0.5;
  if (meter != null) x += 2.4;
  var hasChords = false;
  var hasLyrics = false;
  var highest = 0.0; // smallest y
  var lowest = 4.0; // largest y
  for (final e in elements) {
    switch (e) {
      case final AbcNote n:
        final accidentals = n.shownAccidentals.whereType<int>().length;
        final accSpace = accidentals == 0 ? 0.0 : 1.3;
        x += accSpace;
        items.add(AbcPlaced(e, x, accidentalSpace: accSpace));
        var width = 1.8 + 7 * n.duration;
        if (n.chordSymbol != null) {
          hasChords = true;
          width = math.max(width, n.chordSymbol!.length * 1.15 + 0.6);
        }
        if (n.lyric != null) {
          hasLyrics = true;
          width = math.max(width, n.lyric!.length * 1.0 + 0.6);
        }
        if (_noteValue(n.duration).$2 > 0) width += 0.6;
        for (final p in n.pitches) {
          final y = _pitchY(p, bass);
          highest = math.min(highest, y - 3.5);
          lowest = math.max(lowest, y + 3.5);
        }
        x += width;
      case final AbcRest r:
        if (r.chordSymbol != null) hasChords = true;
        items.add(AbcPlaced(e, x));
        x += 1.8 + 7 * r.duration;
      case final AbcBar b:
        x += 0.3;
        items.add(AbcPlaced(e, x));
        x += switch (b.type) {
          '|:' || '::' || ':|:' => 2.6,
          _ when b.type.length > 1 => 2.0,
          _ => 1.2,
        };
      case final AbcKeyChange k:
        key = k.key;
        items.add(AbcPlaced(e, x));
        x += k.key.signatureLetters.length * 1.0 + 1.0;
      case AbcMeterChange():
        items.add(AbcPlaced(e, x));
        x += 2.4;
    }
  }
  final top = math.max(1.5, -highest + 0.5) + (hasChords ? 2.6 : 0);
  final bottom = math.max(1.5, lowest - 4 + 0.5) + (hasLyrics ? 2.4 : 0);
  return AbcLineLayout._(
    AbcLine(elements),
    items,
    x + 0.5,
    top,
    bottom,
    startKey,
    meter,
  );
}

/// Renders an ABC tune as staff notation. Lines longer than the column are
/// broken at bar lines.
class AbcView extends StatelessWidget {
  const AbcView({
    super.key,
    required this.tune,
    required this.fontSize,
    required this.color,
    required this.accent,
    this.textStyle,
  });

  final AbcTune tune;
  final double fontSize;
  final Color color;
  final Color accent;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final staffSpace = fontSize * abcStaffSpace;
      final rows = layoutAbc(tune, maxWidth: constraints.maxWidth / staffSpace);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            () {
              // A single measure wider than the column is shrunk.
              final width = row.box.width(fontSize, constraints.maxWidth);
              return SizedBox(
                width: width,
                height: width / row.box.aspect,
                child: CustomPaint(
                  painter: _AbcPainter(
                    layout: row,
                    bass: tune.bassClef,
                    color: color,
                    accent: accent,
                    textStyle: textStyle ?? const TextStyle(),
                  ),
                ),
              );
            }(),
        ],
      );
    },
  );
}

class _AbcPainter extends CustomPainter {
  _AbcPainter({
    required this.layout,
    required this.bass,
    required this.color,
    required this.accent,
    required this.textStyle,
  });

  final AbcLineLayout layout;
  final bool bass;

  AbcKey get key => layout.key;
  String? get meter => layout.meter;
  final Color color;
  final Color accent;
  final TextStyle textStyle;

  late double s; // staff space in pixels
  late Canvas c;
  late double top;

  Offset at(double x, double y) => Offset(x * s, (top + y) * s);

  Paint get stroke => Paint()
    ..color = color
    ..strokeWidth = math.max(1, s * 0.1)
    ..style = PaintingStyle.stroke;

  Paint get fill => Paint()..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    s = size.width / layout.width;
    top = layout.top;

    // Staff.
    for (var i = 0; i < 5; i++) {
      c.drawLine(
        at(0.3, i.toDouble()),
        at(layout.width - 0.3, i.toDouble()),
        stroke..strokeWidth = math.max(1, s * 0.08),
      );
    }

    var x = 0.5;
    if (bass) {
      _bassClef(x);
    } else {
      _trebleClef(x);
    }
    x += 3.2;
    x = _keySignature(key, x) + 0.5;
    if (meter != null && meter!.isNotEmpty && meter != 'none') {
      _meter(meter!, x);
    }

    // Notes, rests and bars.
    final items = layout.items;
    final beams = <List<AbcPlaced>>[];
    var group = <AbcPlaced>[];
    void closeGroup() {
      if (group.length > 1) beams.add(group);
      group = [];
    }

    for (final item in items) {
      final e = item.element;
      if (e is AbcNote && e.duration < 0.25 - 1e-9 && !e.spaceBefore) {
        group.add(item);
      } else {
        closeGroup();
        if (e is AbcNote && e.duration < 0.25 - 1e-9) group.add(item);
      }
    }
    closeGroup();
    final beamed = {for (final g in beams) ...g};

    var activeKey = key;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      switch (item.element) {
        case final AbcNote n:
          _note(n, item, beamed.contains(item));
          if (n.tie && i + 1 < items.length) {
            final next = items
                .skip(i + 1)
                .firstWhere((p) => p.element is AbcNote, orElse: () => item);
            if (next != item) _tie(item, next, n);
          }
        case final AbcRest r:
          if (!r.invisible) _rest(r, item.x);
          if (r.chordSymbol != null) _chordSymbol(r.chordSymbol!, item.x);
        case final AbcBar b:
          _bar(b, item.x);
        case final AbcKeyChange k:
          activeKey = k.key;
          _keySignature(activeKey, item.x);
        case final AbcMeterChange m:
          _meter(m.meter, item.x);
      }
    }
    for (final g in beams) {
      _beam(g);
    }
  }

  // Clefs ---------------------------------------------------------------------

  void _trebleClef(double x) {
    final p = Path()
      ..moveTo(at(x + 1.5, 6.2).dx, at(x + 1.5, 6.2).dy)
      ..cubicTo(
        at(x + 1.3, 6.9).dx,
        at(x + 1.3, 6.9).dy,
        at(x + 0.4, 6.7).dx,
        at(x + 0.4, 6.7).dy,
        at(x + 0.6, 6.0).dx,
        at(x + 0.6, 6.0).dy,
      )
      ..lineTo(at(x + 1.6, -1.6).dx, at(x + 1.6, -1.6).dy)
      ..cubicTo(
        at(x + 1.9, -2.6).dx,
        at(x + 1.9, -2.6).dy,
        at(x + 2.6, -1.6).dx,
        at(x + 2.6, -1.6).dy,
        at(x + 1.9, -0.6).dx,
        at(x + 1.9, -0.6).dy,
      )
      ..cubicTo(
        at(x + 0.7, 0.9).dx,
        at(x + 0.7, 0.9).dy,
        at(x + 0.0, 2.3).dx,
        at(x + 0.0, 2.3).dy,
        at(x + 0.5, 3.4).dx,
        at(x + 0.5, 3.4).dy,
      )
      ..cubicTo(
        at(x + 1.0, 4.4).dx,
        at(x + 1.0, 4.4).dy,
        at(x + 2.4, 4.0).dx,
        at(x + 2.4, 4.0).dy,
        at(x + 2.3, 3.1).dx,
        at(x + 2.3, 3.1).dy,
      )
      ..cubicTo(
        at(x + 2.2, 2.2).dx,
        at(x + 2.2, 2.2).dy,
        at(x + 1.0, 2.3).dx,
        at(x + 1.0, 2.3).dy,
        at(x + 1.2, 3.1).dx,
        at(x + 1.2, 3.1).dy,
      );
    c.drawPath(p, stroke..strokeWidth = s * 0.2);
    c.drawCircle(at(x + 1.0, 6.1), s * 0.35, fill);
  }

  void _bassClef(double x) {
    c.drawCircle(at(x + 0.6, 1.0), s * 0.38, fill);
    final p = Path()
      ..moveTo(at(x + 0.4, 1.0).dx, at(x + 0.4, 1.0).dy)
      ..cubicTo(
        at(x + 0.6, -0.3).dx,
        at(x + 0.6, -0.3).dy,
        at(x + 2.4, -0.2).dx,
        at(x + 2.4, -0.2).dy,
        at(x + 2.2, 1.4).dx,
        at(x + 2.2, 1.4).dy,
      )
      ..cubicTo(
        at(x + 2.0, 2.8).dx,
        at(x + 2.0, 2.8).dy,
        at(x + 1.0, 3.6).dx,
        at(x + 1.0, 3.6).dy,
        at(x + 0.2, 4.1).dx,
        at(x + 0.2, 4.1).dy,
      );
    c.drawPath(p, stroke..strokeWidth = s * 0.22);
    c.drawCircle(at(x + 2.8, 0.5), s * 0.16, fill);
    c.drawCircle(at(x + 2.8, 1.5), s * 0.16, fill);
  }

  // Key and meter -------------------------------------------------------------

  static const _sharpSteps = [10, 7, 11, 8, 5, 9, 6]; // F5 C5 G5 D5 A4 E5 B4
  static const _flatSteps = [6, 9, 5, 8, 4, 7, 3]; // B4 E5 A4 D5 G4 C5 F4

  double _keySignature(AbcKey k, double x) {
    final count = k.signatureLetters.length;
    for (var i = 0; i < count; i++) {
      final step =
          (k.fifths > 0 ? _sharpSteps : _flatSteps)[i] - (bass ? 14 : 0);
      final y = _pitchY(AbcPitch(step, 0), bass);
      _accidental(k.fifths > 0 ? 1 : -1, x + i * 1.0 + 0.4, y);
    }
    return x + count * 1.0;
  }

  void _meter(String meter, double x) {
    if (meter == 'C' || meter == 'C|') {
      _text('C', x + 0.4, 2, 3.2, bold: true, center: false);
      if (meter == 'C|') {
        c.drawLine(at(x + 1.1, 0.5), at(x + 1.1, 3.5), stroke);
      }
      return;
    }
    final parts = meter.split('/');
    if (parts.length != 2) {
      _text(meter, x + 0.2, 2, 2.2, bold: true, center: false);
      return;
    }
    _text(parts[0], x + 1.0, 1, 2.4, bold: true);
    _text(parts[1], x + 1.0, 3, 2.4, bold: true);
  }

  // Notes ---------------------------------------------------------------------

  bool _stemUp(AbcNote n) {
    final ys = n.pitches.map((p) => _pitchY(p, bass));
    final avg = ys.reduce((a, b) => a + b) / ys.length;
    return avg >= 2;
  }

  void _note(AbcNote n, AbcPlaced item, bool beamed) {
    final (base, dots) = _noteValue(n.duration);
    final x = item.x;
    final up = _stemUp(n);
    final ys = [for (final p in n.pitches) _pitchY(p, bass)]..sort();

    // Ledger lines.
    for (final y in ys) {
      for (var l = 5.0; l <= y; l += 1) {
        c.drawLine(at(x - 0.9, l), at(x + 0.9, l), stroke);
      }
      for (var l = -1.0; l >= y; l -= 1) {
        c.drawLine(at(x - 0.9, l), at(x + 0.9, l), stroke);
      }
    }
    // Accidentals.
    for (var i = 0; i < n.pitches.length; i++) {
      final shown = i < n.shownAccidentals.length
          ? n.shownAccidentals[i]
          : null;
      if (shown != null) {
        _accidental(
          shown,
          x - item.accidentalSpace + 0.1,
          _pitchY(n.pitches[i], bass),
        );
      }
    }
    // Heads.
    for (final y in ys) {
      _head(x, y, filled: base < 0.5, whole: base >= 1);
      for (var d = 0; d < dots; d++) {
        final dotY = y % 1 == 0 ? y - 0.5 : y;
        c.drawCircle(at(x + 1.1 + d * 0.5, dotY), s * 0.15, fill);
      }
    }
    // Stem and flags.
    if (base < 1) {
      final stemX = up ? x + 0.6 : x - 0.6;
      final from = up ? ys.last : ys.first;
      final to = up ? ys.first - 3.5 : ys.last + 3.5;
      c.drawLine(at(stemX, from), at(stemX, to), stroke);
      if (!beamed && base < 0.25) {
        final flags = base <= 0.0625 ? 2 : 1;
        for (var f = 0; f < flags; f++) {
          final fy = to + (up ? f * 0.8 : -f * 0.8);
          final p = Path()
            ..moveTo(at(stemX, fy).dx, at(stemX, fy).dy)
            ..quadraticBezierTo(
              at(stemX + 1.2, fy + (up ? 1.0 : -1.0)).dx,
              at(stemX + 1.2, fy + (up ? 1.0 : -1.0)).dy,
              at(stemX + 0.9, fy + (up ? 2.4 : -2.4)).dx,
              at(stemX + 0.9, fy + (up ? 2.4 : -2.4)).dy,
            );
          c.drawPath(p, stroke..strokeWidth = s * 0.18);
        }
      }
    }
    if (n.tuplet != null) {
      _text(
        '${n.tuplet}',
        x,
        up ? ys.first - 4.4 : ys.last + 4.4,
        1.4,
        italic: true,
      );
    }
    if (n.chordSymbol != null) _chordSymbol(n.chordSymbol!, x);
    for (final a in n.annotations) {
      _text(a, x, -layout.top + 1.0, 1.3, italic: true);
    }
    if (n.lyric != null) {
      _text(n.lyric!, x, 4 + layout.bottom - 1.2, 1.6);
    }
  }

  void _head(double x, double y, {required bool filled, required bool whole}) {
    c.save();
    c.translate(at(x, y).dx, at(x, y).dy);
    c.rotate(whole ? 0 : -0.35);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: s * (whole ? 1.5 : 1.3),
      height: s * 0.95,
    );
    if (filled) {
      c.drawOval(rect, fill);
    } else {
      c.drawOval(rect, stroke..strokeWidth = s * (whole ? 0.2 : 0.16));
    }
    c.restore();
  }

  void _beam(List<AbcPlaced> group) {
    final notes = [for (final g in group) g.element as AbcNote];
    final ys = [
      for (final n in notes)
        for (final p in n.pitches) _pitchY(p, bass),
    ];
    final up = ys.reduce((a, b) => a + b) / ys.length >= 2;
    final beamY = up ? ys.reduce(math.min) - 3.5 : ys.reduce(math.max) + 3.5;
    final firstX = group.first.x + (up ? 0.6 : -0.6);
    final lastX = group.last.x + (up ? 0.6 : -0.6);
    final paint = fill;
    void bar(double from, double to, double offset) {
      final r = Rect.fromLTRB(
        from * s,
        (top + beamY + offset - (up ? 0 : 0.45)) * s,
        to * s,
        (top + beamY + offset + (up ? 0.45 : 0)) * s,
      );
      c.drawRect(r, paint);
    }

    bar(firstX, lastX, 0);
    for (var i = 0; i < group.length; i++) {
      final n = notes[i];
      final stemX = group[i].x + (up ? 0.6 : -0.6);
      final ny = [for (final p in n.pitches) _pitchY(p, bass)];
      final from = up ? ny.reduce(math.max) : ny.reduce(math.min);
      c.drawLine(at(stemX, from), at(stemX, beamY), stroke);
      // Second beam for sixteenths: to a sixteenth neighbour, otherwise a
      // short stub towards the group.
      if (_noteValue(n.duration).$1 <= 0.0625) {
        final nextShort =
            i + 1 < group.length &&
            _noteValue(notes[i + 1].duration).$1 <= 0.0625;
        final prevShort =
            i > 0 && _noteValue(notes[i - 1].duration).$1 <= 0.0625;
        if (nextShort) {
          final nextX = group[i + 1].x + (up ? 0.6 : -0.6);
          bar(stemX, nextX, up ? 0.8 : -0.8);
        } else if (!prevShort) {
          final toward = i + 1 < group.length ? 1.0 : -1.0;
          final end = stemX + toward;
          bar(math.min(stemX, end), math.max(stemX, end), up ? 0.8 : -0.8);
        }
      }
    }
  }

  void _tie(AbcPlaced a, AbcPlaced b, AbcNote n) {
    final y = _pitchY(n.pitches.first, bass);
    final up = _stemUp(n);
    final dy = up ? 0.8 : -0.8;
    final p = Path()
      ..moveTo(at(a.x + 0.6, y + dy).dx, at(a.x + 0.6, y + dy).dy)
      ..quadraticBezierTo(
        at((a.x + b.x) / 2, y + dy * 2.2).dx,
        at((a.x + b.x) / 2, y + dy * 2.2).dy,
        at(b.x - 0.6, y + dy).dx,
        at(b.x - 0.6, y + dy).dy,
      );
    c.drawPath(p, stroke..strokeWidth = s * 0.12);
  }

  // Rests ---------------------------------------------------------------------

  void _rest(AbcRest r, double x) {
    final (base, dots) = _noteValue(r.duration);
    if (base >= 1) {
      c.drawRect(
        Rect.fromLTWH((x - 0.6) * s, (top + 1) * s, 1.2 * s, 0.5 * s),
        fill,
      );
    } else if (base >= 0.5) {
      c.drawRect(
        Rect.fromLTWH((x - 0.6) * s, (top + 1.5) * s, 1.2 * s, 0.5 * s),
        fill,
      );
    } else if (base >= 0.25) {
      final p = Path()
        ..moveTo(at(x - 0.3, 0.6).dx, at(x - 0.3, 0.6).dy)
        ..lineTo(at(x + 0.4, 1.5).dx, at(x + 0.4, 1.5).dy)
        ..lineTo(at(x - 0.3, 2.3).dx, at(x - 0.3, 2.3).dy)
        ..lineTo(at(x + 0.4, 3.1).dx, at(x + 0.4, 3.1).dy)
        ..quadraticBezierTo(
          at(x - 0.6, 2.9).dx,
          at(x - 0.6, 2.9).dy,
          at(x, 3.8).dx,
          at(x, 3.8).dy,
        );
      c.drawPath(p, stroke..strokeWidth = s * 0.25);
    } else {
      final flags = base <= 0.0625 ? 2 : 1;
      for (var f = 0; f < flags; f++) {
        final y = 1.5 + f * 1.0;
        c.drawCircle(at(x - 0.3 - f * 0.2, y), s * 0.25, fill);
        c.drawLine(at(x - 0.3 - f * 0.2, y), at(x + 0.5, y - 0.3), stroke);
      }
      c.drawLine(
        at(x + 0.5, 1.2),
        at(x - 0.2, 3.5),
        stroke..strokeWidth = s * 0.14,
      );
    }
    for (var d = 0; d < dots; d++) {
      c.drawCircle(at(x + 1.0 + d * 0.5, 1.5), s * 0.15, fill);
    }
  }

  // Bars ----------------------------------------------------------------------

  void _bar(AbcBar b, double x) {
    final thin = stroke..strokeWidth = math.max(1, s * 0.12);
    final thick = Paint()
      ..color = color
      ..strokeWidth = s * 0.45;
    void line(double at0, Paint p) => c.drawLine(at(at0, 0), at(at0, 4), p);
    void dots(double at0) {
      c.drawCircle(at(at0, 1.5), s * 0.2, fill);
      c.drawCircle(at(at0, 2.5), s * 0.2, fill);
    }

    switch (b.type) {
      case '||':
        line(x, thin);
        line(x + 0.5, thin);
      case '|]':
        line(x, thin);
        line(x + 0.6, thick);
      case '[|':
        line(x, thick);
        line(x + 0.6, thin);
      case '|:':
        line(x, thick);
        line(x + 0.6, thin);
        dots(x + 1.1);
      case ':|' || ':|]':
        dots(x - 0.5);
        line(x, thin);
        line(x + 0.6, thick);
      case '::' || ':|:':
        dots(x - 0.5);
        line(x, thin);
        line(x + 0.5, thin);
        dots(x + 1.0);
      case '':
        break;
      default:
        line(x, thin);
    }
    final volta = b.volta;
    if (volta != null) {
      final y = -layout.top + 0.4;
      c.drawLine(at(x + 0.3, y + 1.2), at(x + 0.3, y), thin);
      c.drawLine(at(x + 0.3, y), at(x + 6, y), thin);
      _text('$volta.', x + 0.9, y + 0.7, 1.2, center: false);
    }
  }

  // Glyphs --------------------------------------------------------------------

  void _accidental(int alter, double x, double y) {
    final p = stroke..strokeWidth = s * 0.12;
    if (alter == 0) {
      c.drawLine(at(x - 0.25, y - 1.3), at(x - 0.25, y + 0.6), p);
      c.drawLine(at(x + 0.25, y - 0.6), at(x + 0.25, y + 1.3), p);
      c.drawLine(
        at(x - 0.25, y - 0.3),
        at(x + 0.25, y - 0.5),
        p..strokeWidth = s * 0.25,
      );
      c.drawLine(at(x - 0.25, y + 0.5), at(x + 0.25, y + 0.3), p);
    } else if (alter > 0) {
      c.drawLine(at(x - 0.2, y - 1.4), at(x - 0.2, y + 1.3), p);
      c.drawLine(at(x + 0.2, y - 1.5), at(x + 0.2, y + 1.2), p);
      final bar = Paint()
        ..color = color
        ..strokeWidth = s * 0.25;
      c.drawLine(at(x - 0.5, y - 0.3), at(x + 0.5, y - 0.6), bar);
      c.drawLine(at(x - 0.5, y + 0.5), at(x + 0.5, y + 0.2), bar);
      if (alter > 1) c.drawCircle(at(x + 0.9, y), s * 0.2, fill);
    } else {
      c.drawLine(at(x - 0.3, y - 1.8), at(x - 0.3, y + 0.5), p);
      final bowl = Path()
        ..moveTo(at(x - 0.3, y - 0.1).dx, at(x - 0.3, y - 0.1).dy)
        ..quadraticBezierTo(
          at(x + 0.7, y - 0.8).dx,
          at(x + 0.7, y - 0.8).dy,
          at(x - 0.3, y + 0.5).dx,
          at(x - 0.3, y + 0.5).dy,
        );
      c.drawPath(bowl, p..strokeWidth = s * 0.18);
      if (alter < -1) {
        c.drawLine(at(x - 0.9, y - 1.8), at(x - 0.9, y + 0.5), p);
      }
    }
  }

  void _chordSymbol(String symbol, double x) {
    _text(
      symbol,
      x - 0.4,
      -layout.top + (layout.top > 4 ? 2.2 : 1.4),
      1.6,
      bold: true,
      colour: accent,
      center: false,
    );
  }

  void _text(
    String text,
    double x,
    double y,
    double size, {
    bool bold = false,
    bool italic = false,
    bool center = true,
    Color? colour,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          fontSize: size * s,
          height: 1,
          color: colour ?? color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = at(x, y);
    painter.paint(
      c,
      Offset(
        center ? o.dx - painter.width / 2 : o.dx,
        o.dy - painter.height / 2,
      ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_AbcPainter old) =>
      old.layout != layout || old.color != color;
}
