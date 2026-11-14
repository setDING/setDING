/// State of font/size/colour directives while reading a song (ADR-0012).
library;

import 'markup.dart';
import 'song.dart';

/// Font, size and colour in effect for one item (text, chord, …).
class FormatValues {
  const FormatValues({this.font, this.size, this.colour});

  /// Font family as written (`serif`, `sans`, `monospace`, a font name).
  final String? font;

  /// Size relative to the default ([MarkupSize.factor]) or absolute in
  /// points ([MarkupSize.points]).
  final MarkupSize? size;

  /// Colour as written (`red`, `#4491ff`).
  final String? colour;

  bool get isDefault => font == null && size == null && colour == null;
}

/// Tracks the font/size/colour directives in document order.
///
/// Setting a value pushes it; a directive without value (`{textcolour}`)
/// restores the previous value. `{textfont: sans 13}` sets font and size,
/// and `{textfont}` resets both.
class FormatState {
  FormatState();

  FormatState._copy(FormatState other) {
    for (final e in other._stacks.entries) {
      _stacks[e.key] = [...e.value];
    }
  }

  final _stacks = <(FormatTarget, FormatProperty), List<_Entry>>{};

  FormatState copy() => FormatState._copy(this);

  bool get isEmpty => _stacks.values.every((s) => s.isEmpty);

  /// Applies a format directive.
  void apply(FormatLine line) {
    final key = (line.target, line.property);
    final stack = _stacks.putIfAbsent(key, () => []);
    final value = line.value;
    if (value == null) {
      if (stack.isNotEmpty) {
        final removed = stack.removeLast();
        if (removed.alsoSetSize) {
          final sizes = _stacks[(line.target, FormatProperty.size)];
          if (sizes != null && sizes.isNotEmpty) sizes.removeLast();
        }
      }
      return;
    }
    if (line.property == FormatProperty.font) {
      // "sans 13": family and size.
      final m = RegExp(r'^(.*?)\s+(\d+(?:\.\d+)?%?)$').firstMatch(value);
      if (m != null) {
        stack.add(_Entry(m.group(1)!, alsoSetSize: true));
        _stacks
            .putIfAbsent((line.target, FormatProperty.size), () => [])
            .add(_Entry(m.group(2)!));
        return;
      }
    }
    stack.add(_Entry(value));
  }

  /// Values in effect for [target].
  FormatValues valuesFor(FormatTarget target) {
    final fonts = _stacks[(target, FormatProperty.font)];
    final colours = _stacks[(target, FormatProperty.colour)];
    final sizes = _stacks[(target, FormatProperty.size)];
    MarkupSize? size;
    for (final entry in sizes ?? const <_Entry>[]) {
      final parsed = parseMarkupSize(entry.value);
      if (parsed != null) size = parsed.combine(size);
    }
    return FormatValues(
      font: fonts == null || fonts.isEmpty ? null : fonts.last.value,
      size: size,
      colour: colours == null || colours.isEmpty ? null : colours.last.value,
    );
  }

  /// Values for lyrics: chorus settings override text settings inside a
  /// chorus.
  FormatValues lyricsValues({bool inChorus = false}) {
    final text = valuesFor(FormatTarget.text);
    if (!inChorus) return text;
    final chorus = valuesFor(FormatTarget.chorus);
    return FormatValues(
      font: chorus.font ?? text.font,
      size: chorus.size ?? text.size,
      colour: chorus.colour ?? text.colour,
    );
  }
}

class _Entry {
  const _Entry(this.value, {this.alsoSetSize = false});

  final String value;
  final bool alsoSetSize;
}

/// Applies all format directives in [lines] to [state].
void applyFormatLines(FormatState state, Iterable<Line> lines) {
  for (final line in lines) {
    if (line is FormatLine) state.apply(line);
  }
}
