/// German section labels such as `Vers 1` or `Refrain` and their
/// translation to English (`Verse 1`, `Chorus`) (#1036).
///
/// Section names are English (ADR-0008). Labels are shown as written, so
/// unlike the other conversions this changes what the band sees; it is
/// still one of them (`applyChordProConversions`, #1085), and the editor
/// also offers it as a command for the selection.
library;

import 'directive.dart';
import 'directive_names.dart';
import 'section_heading.dart';

/// A German section label in the source with its English replacement.
class GermanSectionLabel {
  const GermanSectionLabel({
    required this.start,
    required this.end,
    required this.line,
    required this.replacement,
  });

  /// Range of the label text alone (without quotes) in the source.
  final int start;
  final int end;

  /// Line number, starting at 1.
  final int line;

  /// The label in English.
  final String replacement;

  @override
  String toString() => 'GermanSectionLabel(line $line: $replacement)';
}

/// [label] in English if it is a German section name such as `Strophe 2`
/// or `Pre-Refrain:` (`germanSectionNames`), otherwise null. Number, a
/// note in brackets and a trailing colon stay; an upper-case label stays
/// upper case.
String? englishSectionLabel(String label) {
  final parts = sectionHeadingParts(label);
  if (parts == null) return null;
  final (word, rest) = parts;
  var english =
      germanSectionNames[word.toLowerCase().replaceAll(RegExp(r'[\s_.-]'), '')];
  if (english == null) return null;
  if (word.length > 1 && word == word.toUpperCase()) {
    english = english.toUpperCase();
  }
  return '$english$rest';
}

final _line = RegExp(
  r'^(\{\s*([A-Za-z_][A-Za-z0-9_]*)(?:-[A-Za-z0-9_.]+!?)?(?:\s*:\s*|\s+))(.*?)\s*\}$',
);

final _labelAttribute = RegExp(
  r'''(?:^|\s)label\s*=\s*(?:"([^"]*)"|'([^']*)')''',
);

/// German labels in [source], in source order: of section starts
/// (`{start_of_verse: label="Vers 1"}`, also the short form), chorus
/// recalls (`{chorus: Refrain}`) and comment headings (`{c: Strophe 2}`).
/// Lines inside `{start_of_abc}` and the other delegated environments are
/// skipped.
List<GermanSectionLabel> findGermanSectionLabels(String source) {
  final found = <GermanSectionLabel>[];
  String? open;
  var lineStart = 0;
  var lineNumber = 1;
  while (lineStart <= source.length) {
    var lineEnd = source.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = source.length;
    var raw = source.substring(lineStart, lineEnd);
    if (raw.endsWith('\r')) raw = raw.substring(0, raw.length - 1);
    final trimmed = raw.trim();
    final d = trimmed.startsWith('{') ? parseDirective(trimmed) : null;
    if (d != null) {
      final section = d.name.startsWith('start_of_')
          ? d.name.substring('start_of_'.length)
          : shortSectionStarts[d.name];
      if (d.name == 'new_song' || d.name == 'ns') {
        open = null;
      } else if (open != null) {
        if (d.name == 'end_of_$open') open = null;
      } else {
        if (section != null && delegateSectionNames.containsKey(section)) {
          open = section;
        }
        final labelled =
            section != null ||
            d.name == 'chorus' ||
            commentDirectives.containsKey(d.name);
        final span = labelled
            ? _labelSpan(
                trimmed,
                comment: commentDirectives.containsKey(d.name),
              )
            : null;
        if (span != null) {
          final (from, to) = span;
          final replacement = englishSectionLabel(trimmed.substring(from, to));
          if (replacement != null) {
            final base = lineStart + raw.indexOf('{');
            found.add(
              GermanSectionLabel(
                start: base + from,
                end: base + to,
                line: lineNumber,
                replacement: replacement,
              ),
            );
          }
        }
      }
    }
    lineStart = lineEnd + 1;
    lineNumber++;
  }
  return found;
}

/// Range of the label in [directive]: the `label` attribute's value, or
/// the plain argument. A comment's argument is always plain text.
(int, int)? _labelSpan(String directive, {required bool comment}) {
  final m = _line.firstMatch(directive);
  if (m == null) return null;
  final argStart = m.group(1)!.length;
  final argument = m.group(3)!;
  if (argument.isEmpty) return null;
  if (!comment) {
    final attr = _labelAttribute.firstMatch(argument);
    if (attr != null) {
      final value = attr.group(1) ?? attr.group(2)!;
      // The value ends right before the closing quote of the match.
      final valueStart = argStart + attr.end - 1 - value.length;
      return _trim(directive, valueStart, valueStart + value.length);
    }
    if (argument.contains('=')) return null;
  }
  return _trim(directive, argStart, argStart + argument.length);
}

(int, int)? _trim(String text, int from, int to) {
  while (from < to && text[from] == ' ') {
    from++;
  }
  while (to > from && text[to - 1] == ' ') {
    to--;
  }
  return from < to ? (from, to) : null;
}

/// [source] with [labels] (from [findGermanSectionLabels], default all)
/// translated to English.
String translateSectionLabels(
  String source, [
  List<GermanSectionLabel>? labels,
]) {
  for (final label in (labels ?? findGermanSectionLabels(source)).reversed) {
    source = source.replaceRange(label.start, label.end, label.replacement);
  }
  return source;
}
