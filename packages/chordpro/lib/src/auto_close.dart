/// Typing aids of the ChordPro editor (#747): closing brackets and section
/// blocks as in a code editor.
///
/// Pure functions on the text before and after a keystroke, so the editor
/// only applies their result (as a text input formatter, for hardware and
/// software keyboards alike).
library;

import 'directive.dart';
import 'directive_names.dart';
import 'editing.dart';
import 'source_sections.dart';

const _pairs = {'[': ']', '{': '}'};

/// Sections whose content is not ChordPro: brackets there are plain text.
const _rawSections = {'tab', 'abc', 'ly', 'svg', 'textblock'};

/// Adjusts the edit from [before] (selection [start]..[end]) to [after]
/// (cursor [cursor]) made by one keystroke; null keeps it as it is.
///
/// - `[` / `{` also inserts `]` / `}` after the cursor, or wraps a
///   selection within one line.
/// - `]` / `}` right before the same character steps over it.
/// - Backspace in an empty pair `[]` / `{}` deletes both.
/// - Enter at the end of an open section start (`{start_of_verse}`) adds
///   an empty line and the end directive, see [closeSectionBlock].
///
/// Brackets are left alone in comment lines, after `\` and in tab and
/// delegate sections (abc, ly, svg, textblock).
SourceEdit? autoClose(
  String before,
  int start,
  int end,
  String after,
  int cursor,
) {
  if (start > end) (start, end) = (end, start);
  if (start < 0 || end > before.length) return null;
  final prefix = before.substring(0, start);
  final suffix = before.substring(end);

  // Backspace right after the opening bracket of an empty pair.
  if (start == end &&
      start > 0 &&
      start < before.length &&
      cursor == start - 1 &&
      after == before.replaceRange(start - 1, start, '') &&
      _pairs[before[start - 1]] == before[start] &&
      _bracketsAllowed(before, start - 1)) {
    return SourceEdit(
      before.replaceRange(start - 1, start + 1, ''),
      cursor,
      cursor,
    );
  }

  if (after.length < prefix.length + suffix.length ||
      !after.startsWith(prefix) ||
      !after.endsWith(suffix)) {
    return null;
  }
  final typed = after.substring(prefix.length, after.length - suffix.length);
  if (cursor != start + typed.length) return null;

  if (typed == '\n' && start == end) return closeSectionBlock(before, start);

  if (typed == ']' || typed == '}') {
    // Step over the closing bracket that is already there.
    if (start == end && start < before.length && before[start] == typed) {
      return SourceEdit(before, start + 1, start + 1);
    }
    return null;
  }

  final close = _pairs[typed];
  if (close == null || !_bracketsAllowed(before, start)) return null;
  if (start != end) {
    final selected = before.substring(start, end);
    if (selected.contains('\n')) return null;
    return SourceEdit(
      '$prefix$typed$selected$close$suffix',
      start + 1,
      end + 1,
    );
  }
  // Not before a closing bracket without its opening one, e.g. when the
  // `[` of `[Am]` was deleted and is typed again.
  if (_unmatchedClose(_restOfLine(before, start), typed, close)) return null;
  return SourceEdit('$prefix$typed$close$suffix', start + 1, start + 1);
}

/// Inserts a line break at [cursor] when it is at the end of the line of a
/// section start directive (`{start_of_verse}`, `{soc}`,
/// `{start_of_chorus label="Refrain"}`) and the section is not closed yet:
/// then also an empty line and the end directive, with the cursor on the
/// empty line. Null otherwise.
///
/// The section counts as closed when the next section directive below is
/// its end directive; sections do not nest (ADR-0012).
SourceEdit? closeSectionBlock(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
  final lineEnd = _lineEnd(text, cursor);
  if (text.substring(cursor, lineEnd).trim().isNotEmpty) return null;
  final line = text.substring(lineStart, cursor);
  final trimmed = line.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;
  final name = parseDirective(trimmed)?.name;
  if (name == null) return null;
  final short = shortSectionStarts[name];
  final type = short ?? _after(name, 'start_of_');
  if (type == null || type.isEmpty) return null;
  if (_isClosed(text, lineEnd, type)) return null;

  final indent = RegExp(r'^[ \t]*').stringMatch(line)!;
  final endDirective = short != null
      ? '{e${name.substring(1)}}'
      : '{end_of_$type}';
  final inserted = '\n$indent\n$indent$endDirective';
  final at = cursor + 1 + indent.length;
  return SourceEdit(text.replaceRange(cursor, cursor, inserted), at, at);
}

/// Whether the next section directive after [from] ends a section of
/// [type].
bool _isClosed(String text, int from, String type) {
  var lineStart = from + 1;
  while (lineStart <= text.length) {
    final lineEnd = _lineEnd(text, lineStart);
    final trimmed = text.substring(lineStart, lineEnd).trim();
    final name = trimmed.startsWith('{') ? parseDirective(trimmed)?.name : null;
    if (name != null) {
      final endType = shortSectionEnds[name] ?? _after(name, 'end_of_');
      if (endType != null) return endType == type;
      if (shortSectionStarts.containsKey(name) ||
          _after(name, 'start_of_') != null) {
        return false;
      }
    }
    lineStart = lineEnd + 1;
  }
  return false;
}

/// Whether brackets typed at [offset] are ChordPro syntax.
bool _bracketsAllowed(String text, int offset) {
  if (offset > 0 && text[offset - 1] == r'\') return false;
  final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  if (text.substring(lineStart, offset).trimLeft().startsWith('#')) {
    return false;
  }
  for (final section in sourceSections(text)) {
    if (section.start > offset) break;
    if (!_rawSections.contains(section.type) || offset > section.end) continue;
    // The start and end directive lines are ChordPro, the lines between not.
    final firstLineEnd = _lineEnd(text, section.start);
    if (offset <= firstLineEnd) continue;
    final lastLineStart = text.lastIndexOf('\n', section.end - 1) + 1;
    if (lastLineStart > firstLineEnd &&
        offset >= lastLineStart &&
        _isEndDirective(text.substring(lastLineStart, section.end))) {
      continue;
    }
    return false;
  }
  return true;
}

bool _isEndDirective(String line) {
  final trimmed = line.trim();
  final name = trimmed.startsWith('{') ? parseDirective(trimmed)?.name : null;
  return name != null &&
      (shortSectionEnds.containsKey(name) || name.startsWith('end_of_'));
}

/// Whether [rest] has a [close] bracket before any [open] one.
bool _unmatchedClose(String rest, String open, String close) {
  var depth = 0;
  for (var i = 0; i < rest.length; i++) {
    final c = rest[i];
    if (c == open) depth++;
    if (c == close) {
      if (depth == 0) return true;
      depth--;
    }
  }
  return false;
}

String _restOfLine(String text, int from) =>
    text.substring(from, _lineEnd(text, from));

int _lineEnd(String text, int from) {
  final nl = text.indexOf('\n', from);
  return nl < 0 ? text.length : nl;
}

String? _after(String name, String prefix) =>
    name.startsWith(prefix) ? name.substring(prefix.length) : null;
