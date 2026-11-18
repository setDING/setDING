/// Section environments in the ChordPro source, for the editor (#371).
library;

import 'directive.dart';
import 'directive_names.dart';
import 'section_heading.dart';
import 'song.dart';

/// A section environment in the source: from the start of the line of its
/// start directive to the end of the line of its end directive (or up to
/// the next section or the end of the text when it is not closed).
///
/// A section marked only with a heading comment such as
/// `{comment: Verse 1}` (#463) runs from the comment to the last line of
/// its paragraph, as the parser reads it.
class SourceSection {
  const SourceSection(this.start, this.end, this.type);

  final int start;
  final int end;

  /// Environment name: `verse`, `chorus`, `bridge`, `tab`, `grid`, `abc`,
  /// or any other name of `{start_of_…}`. A heading comment gives
  /// `verse`, `chorus`, `bridge` or `custom`.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is SourceSection &&
      other.start == start &&
      other.end == end &&
      other.type == type;

  @override
  int get hashCode => Object.hash(start, end, type);

  @override
  String toString() => 'SourceSection($start, $end, $type)';
}

/// The section environments of [source], in order and without overlaps.
///
/// Follows the parser: an explicit `{start_of_…}` runs to its end, or
/// before the next section or to the end of the text when it is not
/// closed. Outside an explicit section, a normal comment whose text is a
/// section heading opens a section when only other comments precede it in
/// its paragraph (#465); that section ends with the paragraph (empty line), before
/// the next section or chorus recall, or at an end directive.
List<SourceSection> sourceSections(String source) {
  final out = <SourceSection>[];

  // Explicit section: start offset and type.
  int? explicitStart;
  String? explicitType;

  // Implicit paragraph outside explicit sections: whether a heading can
  // still open in it (only comments so far), and the heading section it
  // opened, if any.
  var headingAllowed = true;
  int? headingStart;
  String? headingType;
  var headingEnd = 0;

  void closeHeading() {
    if (headingStart != null) {
      out.add(SourceSection(headingStart!, headingEnd, headingType!));
      headingStart = null;
      headingType = null;
    }
    headingAllowed = true;
  }

  void closeExplicit(int end) {
    if (explicitStart != null) {
      out.add(SourceSection(explicitStart!, end, explicitType!));
      explicitStart = null;
      explicitType = null;
    }
  }

  var lineStart = 0;
  while (lineStart <= source.length) {
    final nl = source.indexOf('\n', lineStart);
    final lineEnd = nl < 0 ? source.length : nl;
    final trimmed = source.substring(lineStart, lineEnd).trim();
    final d = trimmed.startsWith('{') ? parseDirective(trimmed) : null;

    final name = d?.name;
    final startType = name == null
        ? null
        : name.startsWith('start_of_')
        ? name.substring('start_of_'.length)
        : shortSectionStarts[name];
    final isEnd =
        name != null &&
        (name.startsWith('end_of_') || shortSectionEnds.containsKey(name));

    if (startType != null && startType.isNotEmpty) {
      // A new section closes an unclosed one before it.
      closeHeading();
      closeExplicit(lineStart > 0 ? lineStart - 1 : 0);
      explicitStart = lineStart;
      explicitType = startType;
    } else if (isEnd) {
      if (explicitStart != null) {
        closeExplicit(lineEnd);
      } else {
        if (headingStart != null) headingEnd = lineEnd;
        closeHeading();
      }
    } else if (explicitStart == null) {
      if (trimmed.isEmpty || name == 'chorus') {
        closeHeading();
      } else if (!trimmed.startsWith('#') &&
          (d == null || commentDirectives.containsKey(name))) {
        // Content line of the paragraph: lyrics or a comment.
        if (d == null) {
          headingAllowed = false;
        } else if (headingAllowed &&
            d.selector == null &&
            commentDirectives[name] == CommentStyle.normal) {
          final kind = headingSectionKind(d.argument);
          if (kind != null) {
            headingStart = lineStart;
            headingType = switch (kind) {
              SectionKind.verse => 'verse',
              SectionKind.chorus => 'chorus',
              SectionKind.bridge => 'bridge',
              _ => 'custom',
            };
            headingAllowed = false;
          }
        }
        if (headingStart != null) headingEnd = lineEnd;
      }
    }
    if (nl < 0) break;
    lineStart = nl + 1;
  }
  closeHeading();
  closeExplicit(source.length);
  return out;
}
