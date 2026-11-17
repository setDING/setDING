/// Source positions for syntax highlighting in the ChordPro editor
/// (ADR-0003). The rules follow the parser, so the editor and the parser
/// agree on what is a directive, a chord or a section.
library;

import 'chord.dart';
import 'directive.dart';
import 'directive_names.dart';
import 'grid.dart';
import 'markup.dart';

/// Kind of a [SourceToken].
enum SourceTokenKind {
  /// Lyrics, whitespace and line breaks.
  text,

  /// `[Am7]`, including special chords such as `[N.C.]`.
  chord,

  /// `[*Riff]`.
  annotation,

  /// `[Xyz]`: brackets with something that is not a chord.
  unknownChord,

  /// Name of a section directive: `{start_of_chorus}`, `{soc}`, `{chorus}`.
  sectionDirective,

  /// Name of a meta-data or comment directive: `{title: …}`, `{c: …}`.
  metaDirective,

  /// Name of a format or other directive: `{textsize: 12}`, `{define: …}`.
  otherDirective,

  /// Name of a setDING directive (`x_` prefix): `{x_sequence: …}`.
  customDirective,

  /// Plain argument of a directive.
  directiveValue,

  /// Selector of a conditional directive: `-alto`, `-guitar!`.
  selector,

  /// Key of an attribute: `label` in `label="Verse 1"`.
  attributeName,

  /// Value of an attribute, including `=` and quotes.
  attributeValue,

  /// Comment line starting with `#`.
  comment,

  /// Markup tag in lyrics: `<b>`, `</span>`.
  markup,

  /// Content of a tab section.
  tab,

  /// Content of a grid section (cells and margins).
  grid,

  /// Bar line in a grid section: `|`, `||`, `|:`, `:|2>`.
  gridBar,

  /// Content of a delegated environment (abc, ly, svg, textblock); it is
  /// not analysed.
  delegate,

  /// Incomplete input: an unclosed `{` or `[`.
  error,
}

/// A range `[start, end)` of the source with one [kind].
class SourceToken {
  const SourceToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final SourceTokenKind kind;

  @override
  bool operator ==(Object other) =>
      other is SourceToken &&
      other.start == start &&
      other.end == end &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'SourceToken($start, $end, ${kind.name})';
}

/// Special chords that are valid although they are not real chords.
const _specialChords = {'n.c.', 'n.c', 'nc', 'x', '/', '-', '%', ''};

/// The kind of the name of directive [name] (lower case).
SourceTokenKind directiveKind(String name) {
  if (name.startsWith('x_')) return SourceTokenKind.customDirective;
  if (name.startsWith('start_of_') ||
      name.startsWith('end_of_') ||
      shortSectionStarts.containsKey(name) ||
      shortSectionEnds.containsKey(name) ||
      name == 'chorus') {
    return SourceTokenKind.sectionDirective;
  }
  if (metaDirectiveAliases.containsKey(name) ||
      commentDirectives.containsKey(name) ||
      name == 'meta') {
    return SourceTokenKind.metaDirective;
  }
  return SourceTokenKind.otherDirective;
}

/// The kind of the chord written as [raw] between brackets.
SourceTokenKind chordKind(String raw) {
  final text = stripMarkup(raw).trim();
  if (text.startsWith('*')) return SourceTokenKind.annotation;
  final optional = RegExp(r'^\((.+)\)$').firstMatch(text);
  final chord = optional?.group(1) ?? text;
  if (Chord.tryParse(chord) != null ||
      _specialChords.contains(chord.toLowerCase())) {
    return SourceTokenKind.chord;
  }
  return SourceTokenKind.unknownChord;
}

/// Splits ChordPro [source] into tokens for syntax highlighting.
///
/// The tokens cover the whole text without gaps or overlaps, in order.
/// Line based and tolerant of incomplete input (an unclosed `{` or `[`
/// is an [SourceTokenKind.error] up to the end of the line).
List<SourceToken> highlightChordPro(String source) {
  final out = _TokenWriter(source.length);
  String? delegate;
  String? section;
  var lineStart = 0;
  while (lineStart <= source.length) {
    var lineEnd = source.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = source.length;
    var content = source.substring(lineStart, lineEnd);
    if (content.endsWith('\r')) {
      content = content.substring(0, content.length - 1);
    }
    final trimmed = content.trim();
    final lead = content.length - content.trimLeft().length;
    final d = trimmed.startsWith('{') ? parseDirective(trimmed) : null;

    if (delegate != null) {
      // {new_song} also ends an open environment, as in the parser.
      if (d != null &&
          (d.name == 'end_of_$delegate' ||
              d.name == 'new_song' ||
              d.name == 'ns')) {
        _directive(out, lineStart, content, lead, d);
        delegate = null;
      } else if (lineEnd > lineStart) {
        // Includes the line break, so the block background is continuous.
        out.add(
          lineStart,
          lineEnd < source.length ? lineEnd + 1 : lineEnd,
          SourceTokenKind.delegate,
        );
      }
    } else if (d != null) {
      _directive(out, lineStart, content, lead, d);
      final name = d.name;
      final start = name.startsWith('start_of_')
          ? name.substring(9)
          : shortSectionStarts[name];
      if (name.startsWith('end_of_') ||
          shortSectionEnds.containsKey(name) ||
          name == 'new_song' ||
          name == 'ns') {
        section = null;
      } else if (start != null) {
        if (delegateSectionNames.containsKey(start)) {
          delegate = start;
          section = null;
        } else {
          section = start;
        }
      }
    } else if (splitTrailingText(content) case final t?) {
      // Not a directive by the ChordPro definition (#309): the directive
      // part looks like one, the text after it is the problem.
      final head = parseDirective(t.directive)!;
      _directive(
        out,
        lineStart,
        content.substring(0, t.directiveEnd),
        lead,
        head,
      );
      out.add(
        lineStart + t.textStart,
        lineStart + content.length,
        SourceTokenKind.error,
      );
    } else if (trimmed.startsWith('{') && !trimmed.contains('}')) {
      out.add(
        lineStart + lead,
        lineStart + content.length,
        SourceTokenKind.error,
      );
    } else if (trimmed.startsWith('#')) {
      out.add(
        lineStart + lead,
        lineStart + content.length,
        SourceTokenKind.comment,
      );
    } else if (section == 'tab') {
      if (trimmed.isNotEmpty) {
        out.add(
          lineStart + lead,
          lineStart + content.length,
          SourceTokenKind.tab,
        );
      }
    } else if (section == 'grid') {
      _gridLine(out, lineStart, content);
    } else {
      _lyricLine(out, lineStart, content);
    }
    lineStart = lineEnd + 1;
  }
  return out.finish();
}

bool _isSpace(String c) => c == ' ' || c == '\t';

bool _isNameChar(String c, {bool dot = false}) {
  final u = c.codeUnitAt(0);
  return (u >= 0x30 && u <= 0x39) ||
      (u >= 0x41 && u <= 0x5a) ||
      (u >= 0x61 && u <= 0x7a) ||
      c == '_' ||
      (dot && c == '.');
}

/// A directive line that [parseDirective] accepted.
void _directive(
  _TokenWriter out,
  int base,
  String line,
  int lead,
  Directive d,
) {
  final kind = directiveKind(d.name);
  final close = line.lastIndexOf('}');
  var i = lead + 1;
  while (i < close && _isSpace(line[i])) {
    i++;
  }
  while (i < close && _isNameChar(line[i])) {
    i++;
  }
  out.add(base + lead, base + i, kind);
  if (i < close && line[i] == '-') {
    final start = i++;
    while (i < close && _isNameChar(line[i], dot: true)) {
      i++;
    }
    if (i < close && line[i] == '!') i++;
    out.add(base + start, base + i, SourceTokenKind.selector);
  }
  final separator = i;
  while (i < close && _isSpace(line[i])) {
    i++;
  }
  if (i < close && line[i] == ':') {
    i++;
    while (i < close && _isSpace(line[i])) {
      i++;
    }
  }
  out.add(base + separator, base + i, kind);

  if (d.attributes.isNotEmpty) {
    final argument = line.substring(i, close);
    var pos = 0;
    for (final m in attributeMatches(argument)) {
      out.add(
        base + i + pos,
        base + i + m.start,
        SourceTokenKind.directiveValue,
      );
      final key = m.group(1)!;
      out.add(
        base + i + m.start,
        base + i + m.start + key.length,
        SourceTokenKind.attributeName,
      );
      out.add(
        base + i + m.start + key.length,
        base + i + m.end,
        SourceTokenKind.attributeValue,
      );
      pos = m.end;
    }
    out.add(base + i + pos, base + close, SourceTokenKind.directiveValue);
  } else {
    out.add(base + i, base + close, SourceTokenKind.directiveValue);
  }
  out.add(base + close, base + line.length, kind);
}

void _gridLine(_TokenWriter out, int base, String line) {
  for (final m in RegExp(r'\S+').allMatches(line)) {
    out.add(
      base + m.start,
      base + m.end,
      isGridBar(m.group(0)!) ? SourceTokenKind.gridBar : SourceTokenKind.grid,
    );
  }
}

final _markupTag = RegExp(r'</?[a-zA-Z][^<>\n]*>');

void _lyricLine(_TokenWriter out, int base, String line) {
  var i = 0;
  while (i < line.length) {
    final c = line[i];
    if (c == r'\' && i + 1 < line.length && '[]{}'.contains(line[i + 1])) {
      i += 2;
      continue;
    }
    if (c == '[') {
      final end = line.indexOf(']', i + 1);
      if (end < 0) {
        out.add(base + i, base + line.length, SourceTokenKind.error);
        return;
      }
      out.add(base + i, base + end + 1, chordKind(line.substring(i + 1, end)));
      i = end + 1;
      continue;
    }
    if (c == '<') {
      final m = _markupTag.matchAsPrefix(line, i);
      if (m != null) {
        out.add(base + i, base + m.end, SourceTokenKind.markup);
        i = m.end;
        continue;
      }
    }
    i++;
  }
}

/// Collects tokens in order, fills gaps with [SourceTokenKind.text] and
/// merges neighbours of the same kind.
class _TokenWriter {
  _TokenWriter(this.length);

  final int length;
  final tokens = <SourceToken>[];
  int _end = 0;

  void add(int start, int end, SourceTokenKind kind) {
    if (end <= start) return;
    assert(start >= _end, 'tokens must not overlap');
    if (start > _end) _push(_end, start, SourceTokenKind.text);
    _push(start, end, kind);
  }

  void _push(int start, int end, SourceTokenKind kind) {
    final last = tokens.lastOrNull;
    if (last != null && last.kind == kind && last.end == start) {
      tokens[tokens.length - 1] = SourceToken(last.start, end, kind);
    } else {
      tokens.add(SourceToken(start, end, kind));
    }
    _end = end;
  }

  List<SourceToken> finish() {
    if (_end < length) _push(_end, length, SourceTokenKind.text);
    return tokens;
  }
}
