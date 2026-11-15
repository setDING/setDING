import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import '../../settings/display_options.dart';
export '../../settings/display_options.dart' show DiagramsPosition;

/// Combines the device setting with the song's `{diagrams}` directive,
/// which wins (`off`, `on`, or a position; `right`/`below` are shown at
/// the bottom on screen).
DiagramsPosition diagramsPosition(
  String? directive,
  DiagramsPosition setting,
) => switch (directive) {
  'off' => DiagramsPosition.off,
  'top' => DiagramsPosition.top,
  'bottom' || 'right' || 'below' => DiagramsPosition.bottom,
  'on' => setting == DiagramsPosition.off ? DiagramsPosition.bottom : setting,
  _ => setting,
};

/// Instrument family for chord diagrams (from the instrument setting).
enum DiagramInstrument { guitar, ukulele, bass, keyboard, none }

/// Maps the free-text instrument setting to a diagram instrument.
DiagramInstrument diagramInstrumentFor(String instrument) {
  final i = instrument.trim().toLowerCase();
  if (i.contains('uke') || i.contains('ukulele')) {
    return DiagramInstrument.ukulele;
  }
  if (i.contains('bass')) return DiagramInstrument.bass;
  if (const [
    'keyboard',
    'piano',
    'keys',
    'organ',
    'synth',
    'klavier',
    'orgel',
  ].any(i.contains)) {
    return DiagramInstrument.keyboard;
  }
  if (i.contains('guitar') || i.contains('gitarre')) {
    return DiagramInstrument.guitar;
  }
  return DiagramInstrument.none;
}

StringInstrument? _stringInstrument(DiagramInstrument instrument) =>
    switch (instrument) {
      DiagramInstrument.guitar => StringInstrument.guitar,
      DiagramInstrument.ukulele => StringInstrument.ukulele,
      DiagramInstrument.bass => StringInstrument.bass,
      _ => null,
    };

/// What one chord diagram shows.
class DiagramData {
  const DiagramData.strings(this.name, ChordDefinition this.shape)
    : keys = null;

  const DiagramData.keyboard(this.name, List<int> this.keys) : shape = null;

  /// Chord name shown above the diagram.
  final String name;

  /// Fretted instrument: frets relative to the base fret.
  final ChordDefinition? shape;

  /// Keyboard: MIDI notes to highlight.
  final List<int>? keys;

  static const nameHeight = 1.1;
  static const stringGap = 0.55;
  static const fretHeight = 0.6;
  static const frets = 4;

  /// Width in units of the font size.
  double get widthUnits {
    final s = shape;
    if (s != null) return ((s.frets?.length ?? 6) - 1) * stringGap + 1.2;
    return _whiteKeys(keys!).length * 0.42 + 0.2;
  }

  /// Height in units of the font size.
  double get heightUnits => shape != null
      ? nameHeight + 0.6 + frets * fretHeight + 0.2
      : nameHeight + 2.0;
}

/// MIDI white keys spanning [notes] (whole octaves from C).
List<int> _whiteKeys(List<int> notes) {
  final low = notes.reduce(math.min) ~/ 12 * 12;
  final high = (notes.reduce(math.max) ~/ 12 + 1) * 12 - 1;
  return [
    for (var n = low; n <= high; n++)
      if (!_isBlack(n)) n,
  ];
}

bool _isBlack(int midi) => const {1, 3, 6, 8, 10}.contains(midi % 12);

/// Resolves diagrams for chords: `{define}` of the song first, otherwise a
/// generated fingering for the instrument (ADR-0012).
class DiagramResolver {
  DiagramResolver(this.song, this.formatter, this.instrument);

  final Song song;
  final ChordFormatter formatter;
  final DiagramInstrument instrument;

  ChordDefinition? _definition(String name) {
    ChordDefinition? def;
    for (final d in song.definitions) {
      if (d.name == name) def = d;
    }
    if (def != null && def.copy != null && !def.hasShape) {
      final source = _definition(def.copy!);
      if (source != null) {
        return ChordDefinition(
          name: def.name,
          baseFret: source.baseFret,
          frets: source.frets,
          fingers: source.fingers,
          keys: source.keys,
          display: def.display ?? source.display,
          diagram: def.diagram,
        );
      }
    }
    return def;
  }

  /// Diagram for a chord token in the song (as played).
  DiagramData? forToken(ChordToken token) {
    final chord = formatter.playedChord(token);
    if (chord == null) return null;
    final name = formatter.chordName(chord);
    // A {define} applies when the chord is shown as written.
    final written = token.chord;
    final unchanged = written != null && formatter.shift + token.transpose == 0;
    return _resolve(chord, name, unchanged ? stripMarkup(token.raw) : null);
  }

  /// Diagram for a `{chord: …}` directive.
  DiagramData? forDefinition(ChordDefinition def) {
    if (!def.diagram) return null;
    final chord = Chord.tryParse(def.name);
    if (def.transposable && chord != null) {
      final played = formatter.playedChord(ChordToken(def.name));
      if (played != null && formatter.shift != 0) {
        return _resolve(played, formatter.chordName(played), null);
      }
    }
    final name = def.display ?? def.name;
    if (def.hasShape) return _fromDefinition(name, def, chord);
    // {chord: X} without a shape: a {define} of the song, else generated.
    final defined = _definition(def.name);
    if (defined != null && defined.hasShape) {
      if (!defined.diagram) return null;
      return _fromDefinition(
        def.display ?? defined.display ?? def.name,
        defined,
        chord,
      );
    }
    if (chord == null) return null;
    return _resolve(chord, name, def.name);
  }

  DiagramData? _resolve(Chord chord, String name, String? definedName) {
    final def = definedName == null ? null : _definition(definedName);
    if (def != null) {
      if (!def.diagram) return null;
      if (def.hasShape) {
        final data = _fromDefinition(def.display ?? name, def, chord);
        if (data != null) return data;
      }
    }
    final strings = _stringInstrument(instrument);
    if (strings != null) {
      final fingering = fingeringFor(chord, strings);
      return fingering == null
          ? null
          : DiagramData.strings(name, fingering.toDefinition(name));
    }
    if (instrument == DiagramInstrument.keyboard) {
      return DiagramData.keyboard(name, keyboardVoicing(chord));
    }
    return null;
  }

  DiagramData? _fromDefinition(String name, ChordDefinition def, Chord? chord) {
    final frets = def.frets;
    if (frets != null && instrument != DiagramInstrument.keyboard) {
      final strings = _stringInstrument(instrument);
      // Only use a shape made for this number of strings.
      if (strings == null || strings.strings == frets.length) {
        return DiagramData.strings(name, def);
      }
      return null;
    }
    final keys = def.keys;
    if (keys != null && instrument == DiagramInstrument.keyboard) {
      final root = 60 + (chord?.root.pitch ?? 0);
      return DiagramData.keyboard(name, [for (final k in keys) root + k]);
    }
    return null;
  }

  /// Diagrams of all chords used in the song, in order of appearance.
  List<DiagramData> allChords() {
    final seen = <String>{};
    final result = <DiagramData>[];
    void add(ChordToken token) {
      final data = forToken(token);
      if (data != null && seen.add(data.name)) result.add(data);
    }

    for (final section in song.sections) {
      for (final line in section.lines) {
        switch (line) {
          case final LyricLine l:
            for (final s in l.segments) {
              if (s.chord != null) add(s.chord!);
            }
          case final GridLine g:
            for (final t in g.row.tokens) {
              if (t is GridChords) t.chords.forEach(add);
            }
          default:
            break;
        }
      }
    }
    return result;
  }
}

/// A chord diagram for a fretted instrument or a keyboard.
class ChordDiagramView extends StatelessWidget {
  const ChordDiagramView({
    super.key,
    required this.data,
    required this.fontSize,
    required this.color,
    required this.accent,
    this.nameStyle,
  });

  final DiagramData data;
  final double fontSize;
  final Color color;
  final Color accent;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final width = data.widthUnits * fontSize;
    final height = data.heightUnits * fontSize;
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: DiagramData.nameHeight * fontSize,
            child: Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: (nameStyle ?? const TextStyle()).copyWith(
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1.2,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: data.shape != null
                  ? _StringPainter(data.shape!, fontSize, color, accent)
                  : _KeyboardPainter(data.keys!, color, accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _StringPainter extends CustomPainter {
  _StringPainter(this.shape, this.fontSize, this.color, this.accent);

  final ChordDefinition shape;
  final double fontSize;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final frets = shape.frets ?? const [];
    final strings = frets.length;
    if (strings == 0) return;
    final gap = DiagramData.stringGap * fontSize;
    final fretH = DiagramData.fretHeight * fontSize;
    final left = (size.width - (strings - 1) * gap) / 2;
    final top = 0.6 * fontSize;
    final line = Paint()
      ..color = color
      ..strokeWidth = math.max(1, fontSize * 0.05);
    final nut = Paint()
      ..color = color
      ..strokeWidth = math.max(2, fontSize * 0.16);

    // Strings and frets.
    for (var s = 0; s < strings; s++) {
      final x = left + s * gap;
      canvas.drawLine(Offset(x, top), Offset(x, top + 4 * fretH), line);
    }
    for (var f = 0; f <= DiagramData.frets; f++) {
      final y = top + f * fretH;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + (strings - 1) * gap, y),
        f == 0 && shape.baseFret <= 1 ? nut : line,
      );
    }
    if (shape.baseFret > 1) {
      _text(
        canvas,
        '${shape.baseFret}',
        Offset(left - fontSize * 0.25, top + fretH * 0.5),
        fontSize * 0.5,
        color,
        alignRight: true,
      );
    }

    final dot = Paint()..color = accent;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, fontSize * 0.06);
    final radius = gap * 0.36;
    for (var s = 0; s < strings; s++) {
      final x = left + s * gap;
      final f = frets[s];
      if (f == null) {
        final d = radius * 0.8;
        final y = top - fontSize * 0.32;
        canvas.drawLine(Offset(x - d, y - d), Offset(x + d, y + d), ring);
        canvas.drawLine(Offset(x - d, y + d), Offset(x + d, y - d), ring);
      } else if (f == 0) {
        canvas.drawCircle(Offset(x, top - fontSize * 0.32), radius * 0.8, ring);
      } else if (f <= DiagramData.frets) {
        canvas.drawCircle(Offset(x, top + (f - 0.5) * fretH), radius, dot);
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double size,
    Color color, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        alignRight ? at.dx - painter.width : at.dx,
        at.dy - painter.height / 2,
      ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_StringPainter old) =>
      old.shape != shape || old.fontSize != fontSize || old.color != color;
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter(this.notes, this.color, this.accent);

  final List<int> notes;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final whites = _whiteKeys(notes);
    final keyWidth = size.width / whites.length;
    final height = size.height * 0.9;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pressed = Paint()..color = accent;
    final black = Paint()..color = color;
    for (var i = 0; i < whites.length; i++) {
      final rect = Rect.fromLTWH(i * keyWidth, 0, keyWidth, height);
      if (notes.contains(whites[i])) canvas.drawRect(rect, pressed);
      canvas.drawRect(rect, outline);
    }
    for (var i = 0; i < whites.length; i++) {
      final next = whites[i] + 1;
      if (!_isBlack(next)) continue;
      final rect = Rect.fromLTWH(
        (i + 1) * keyWidth - keyWidth * 0.3,
        0,
        keyWidth * 0.6,
        height * 0.6,
      );
      canvas.drawRect(rect, notes.contains(next) ? pressed : black);
    }
  }

  @override
  bool shouldRepaint(_KeyboardPainter old) =>
      old.notes != notes || old.color != color;
}
