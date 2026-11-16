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
  final problems = <ChordProProblem>[
    for (final t in tokens ?? highlightChordPro(source))
      if (t.kind == SourceTokenKind.error)
        ChordProProblem(
          source[t.start] == '{'
              ? ChordProProblemKind.unclosedDirective
              : ChordProProblemKind.unclosedChord,
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
