/// Checks of the ChordPro source before saving (#109).
library;

import 'directive.dart';
import 'directive_names.dart';
import 'highlight.dart';

/// Kind of a [ChordProProblem].
enum ChordProProblemKind {
  /// A `{` without `}` on its line.
  unclosedDirective,

  /// A `[` without `]` on its line.
  unclosedChord,

  /// `{start_of_abc}` (ly, svg, textblock) without its end: the rest of
  /// the song becomes part of the environment.
  unclosedEnvironment,

  /// Text after a directive on the same line, such as
  /// `{comment: Chorus} (a cappella)`: the whole line is shown as lyrics
  /// (#309). The range is the trailing text. [fixChordProProblem] fixes it.
  textAfterDirective,
}

/// A problem that changes how the source is parsed.
class ChordProProblem {
  const ChordProProblem(
    this.kind, {
    required this.start,
    required this.end,
    required this.line,
  });

  final ChordProProblemKind kind;

  /// Range of the problem in the source.
  final int start;
  final int end;

  /// Line number, starting at 1.
  final int line;

  @override
  bool operator ==(Object other) =>
      other is ChordProProblem &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.line == line;

  @override
  int get hashCode => Object.hash(kind, start, end, line);

  @override
  String toString() => 'ChordProProblem(${kind.name}, line $line, $start–$end)';
}

/// Problems in [source], in source order. The parser is lenient and never
/// fails; these are the places where it probably does not do what the
/// author meant. [tokens] are the highlighting tokens, if already known.
List<ChordProProblem> validateChordPro(
  String source, {
  List<SourceToken>? tokens,
}) {
  int lineOf(int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;
  ChordProProblemKind kindOf(SourceToken t) {
    final (start, end) = _lineAround(source, t.start);
    final trailing = splitTrailingText(source.substring(start, end));
    if (trailing != null && t.start == start + trailing.textStart) {
      return ChordProProblemKind.textAfterDirective;
    }
    return source[t.start] == '{'
        ? ChordProProblemKind.unclosedDirective
        : ChordProProblemKind.unclosedChord;
  }

  final problems = <ChordProProblem>[
    for (final t in tokens ?? highlightChordPro(source))
      if (t.kind == SourceTokenKind.error)
        ChordProProblem(
          kindOf(t),
          start: t.start,
          end: t.end,
          line: lineOf(t.start),
        ),
  ];

  // Delegated environments that are still open at the end of a song.
  String? open;
  var openStart = 0;
  var openEnd = 0;
  void unclosed() {
    if (open == null) return;
    problems.add(
      ChordProProblem(
        ChordProProblemKind.unclosedEnvironment,
        start: openStart,
        end: openEnd,
        line: lineOf(openStart),
      ),
    );
    open = null;
  }

  var lineStart = 0;
  while (lineStart <= source.length) {
    var lineEnd = source.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = source.length;
    final raw = source.substring(lineStart, lineEnd);
    final line = raw.trim();
    final d = line.startsWith('{') ? parseDirective(line) : null;
    if (d == null) {
      // Not a directive.
    } else if (d.name == 'new_song' || d.name == 'ns') {
      unclosed();
    } else if (open != null) {
      if (d.name == 'end_of_$open') open = null;
    } else if (d.name.startsWith('start_of_') &&
        delegateSectionNames.containsKey(d.name.substring(9))) {
      open = d.name.substring(9);
      openStart = lineStart + raw.indexOf('{');
      openEnd = lineStart + raw.trimRight().length;
    }
    lineStart = lineEnd + 1;
  }
  unclosed();
  problems.sort((a, b) => a.start.compareTo(b.start));
  return problems;
}

/// Start and end of the line around [offset], without the line break.
(int, int) _lineAround(String source, int offset) {
  final start = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
  var end = source.indexOf('\n', offset);
  if (end < 0) end = source.length;
  if (end > start && source[end - 1] == '\r') end--;
  return (start, end);
}

/// Whether [fixChordProProblem] can fix [problem].
bool canFixChordProProblem(ChordProProblem problem) =>
    problem.kind == ChordProProblemKind.textAfterDirective;

/// [source] with [problem] fixed, or null if it has no automatic fix.
///
/// Text after a directive (#309) becomes valid ChordPro: plain text turns
/// into an italic comment before the directive, as a note such as
/// "(first time a cappella)" belongs to what follows; chords, directives
/// and remarks move to a line of their own after the directive.
String? fixChordProProblem(String source, ChordProProblem problem) {
  if (!canFixChordProProblem(problem)) return null;
  final (start, end) = _lineAround(source, problem.start);
  final line = source.substring(start, end);
  final trailing = splitTrailingText(line);
  if (trailing == null) return null;
  final lead = line.substring(0, line.indexOf('{'));
  final text = trailing.text;
  final ownLine =
      text.startsWith('{') ||
      text.startsWith('#') ||
      text.contains('[') ||
      text.contains('}');
  final nl = end < source.length && source[end] == '\r' ? '\r\n' : '\n';
  final replacement = ownLine
      ? '$lead${trailing.directive}$nl$text'
      : '$lead{comment_italic: $text}$nl$lead${trailing.directive}';
  return source.replaceRange(start, end, replacement);
}

/// [source] with every problem fixed that [fixChordProProblem] can fix.
String fixChordProProblems(String source) {
  // A fix can reveal another problem, such as a second directive after
  // the first one; a few passes settle it.
  for (var pass = 0; pass < 10; pass++) {
    final fixable = validateChordPro(source).where(canFixChordProProblem);
    if (fixable.isEmpty) break;
    // From the end, so the offsets of earlier problems stay valid.
    for (final p in fixable.toList().reversed) {
      source = fixChordProProblem(source, p) ?? source;
    }
  }
  return source;
}
