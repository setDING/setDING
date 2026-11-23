/// Section headings written as comments, such as `{comment: Verse 1}`, and
/// their conversion to section environments (#963).
///
/// SongSelect and other sources mark sections with a comment heading. The
/// parser already reads them as labelled sections (#463); the conversion
/// makes the source standard ChordPro without changing what is shown.
library;

import 'ccli_grid.dart';
import 'directive.dart';
import 'directive_names.dart';
import 'section_heading.dart';
import 'source_sections.dart';

/// A section marked with a comment heading that can become an environment.
class CommentHeading {
  const CommentHeading({
    required this.start,
    required this.end,
    required this.line,
    required this.replacement,
  });

  /// Range of the section in the source, from the start of the heading
  /// line to the end of its last line (before the line break).
  final int start;
  final int end;

  /// Line number of the heading, starting at 1.
  final int line;

  /// The section as an environment.
  final String replacement;

  @override
  String toString() => 'CommentHeading(line $line: $replacement)';
}

/// Sections in [source] marked with a comment heading, in source order,
/// as the parser reads them (`sourceSections`).
///
/// Left alone: a heading without lines after it (an environment would
/// only be empty), a paragraph with CCLI bar lines (the grid conversion
/// uses the heading as grid label) and a label that cannot be quoted.
List<CommentHeading> findCommentHeadings(String source) {
  final nl = source.contains('\r\n') ? '\r\n' : '\n';
  final grids = findCcliGrids(source);
  final found = <CommentHeading>[];
  for (final section in sourceSections(source)) {
    final headingEnd = _lineEnd(source, section.start);
    final heading = parseDirective(
      source.substring(section.start, headingEnd).trim(),
    );
    if (heading == null || !commentDirectives.containsKey(heading.name)) {
      continue;
    }
    // `sourceSections` ends a line at `\n`, so a `\r` before it is still
    // part of the section.
    var end = section.end;
    if (end > headingEnd && source[end - 1] == '\r') end--;
    if (end <= headingEnd) continue;
    if (grids.any((g) => g.end >= section.start && g.start <= end)) {
      continue;
    }
    final label = _quote(heading.argument.trim());
    final type = headingEnvironment(heading.argument);
    if (label == null || type == null) continue;

    // A stray end directive closed the paragraph (`sourceSections` counts
    // it to the section): it becomes the end of the new environment.
    var body = source.substring(headingEnd, end);
    final lastStart = body.lastIndexOf('\n') + 1;
    final last = parseDirective(body.substring(lastStart).trim());
    if (last != null &&
        (last.name.startsWith('end_of_') ||
            shortSectionEnds.containsKey(last.name))) {
      body = body.substring(0, lastStart == 0 ? 0 : lastStart - 1);
      if (body.endsWith('\r')) body = body.substring(0, body.length - 1);
    }
    if (body.trim().isEmpty) continue;

    found.add(
      CommentHeading(
        start: section.start,
        end: end,
        line: _lineNumber(source, section.start),
        replacement: '{start_of_$type: label=$label}$body$nl{end_of_$type}',
      ),
    );
  }
  return found;
}

/// [source] with [headings] (from [findCommentHeadings], default all)
/// converted to section environments.
String convertCommentHeadings(String source, [List<CommentHeading>? headings]) {
  var result = source;
  for (final h in (headings ?? findCommentHeadings(source)).reversed) {
    result = result.replaceRange(h.start, h.end, h.replacement);
  }
  return result;
}

/// End of the line at [offset], before its line break.
int _lineEnd(String source, int offset) {
  final nl = source.indexOf('\n', offset);
  var end = nl < 0 ? source.length : nl;
  if (end > offset && source[end - 1] == '\r') end--;
  return end;
}

int _lineNumber(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

/// [value] in quotes the attribute syntax can read back, or null if it
/// contains both kinds of quotes.
String? _quote(String value) {
  if (!value.contains('"')) return '"$value"';
  if (!value.contains("'")) return "'$value'";
  return null;
}
