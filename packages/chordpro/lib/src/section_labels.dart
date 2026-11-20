/// Section labels in the short form `{start_of_verse: Verse 1}` and their
/// conversion to the attribute form `{start_of_verse: label="Verse 1"}`
/// (#672).
///
/// The ChordPro specification prefers the attribute form; the parser reads
/// both. The short form is no problem (`validateChordPro` ignores it), the
/// editor and the import only offer to convert it.
library;

import 'directive.dart';
import 'directive_names.dart';
import 'grid.dart';

/// A section start with its label as plain argument.
class LegacySectionLabel {
  const LegacySectionLabel({
    required this.start,
    required this.end,
    required this.line,
    required this.replacement,
  });

  /// Range of the directive, from `{` to `}`.
  final int start;
  final int end;

  /// Line number, starting at 1.
  final int line;

  /// The directive in the attribute form.
  final String replacement;

  @override
  String toString() => 'LegacySectionLabel(line $line: $replacement)';
}

final _sectionStart = RegExp(
  r'^(\{\s*([A-Za-z_][A-Za-z0-9_]*)(?:-[A-Za-z0-9_.]+!?)?)(?:\s*:\s*|\s+)(.*?)\s*\}$',
);

/// Section starts in [source] whose label is a plain argument, in source
/// order. Lines inside `{start_of_abc}` and the other delegated
/// environments are not directives and are skipped.
List<LegacySectionLabel> findLegacySectionLabels(String source) {
  final found = <LegacySectionLabel>[];
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
      } else if (section != null) {
        if (delegateSectionNames.containsKey(section)) open = section;
        final replacement = _convert(trimmed, d, grid: section == 'grid');
        if (replacement != null) {
          final start = lineStart + raw.indexOf('{');
          found.add(
            LegacySectionLabel(
              start: start,
              end: start + trimmed.length,
              line: lineNumber,
              replacement: replacement,
            ),
          );
        }
      }
    }
    lineStart = lineEnd + 1;
    lineNumber++;
  }
  return found;
}

/// [directive] in the attribute form, or null if it already is (or has no
/// label) or the label cannot be quoted.
String? _convert(String directive, Directive d, {required bool grid}) {
  if (d.argument.isEmpty || d.attributes.isNotEmpty) return null;
  final m = _sectionStart.firstMatch(directive);
  if (m == null) return null;
  var label = m.group(3)!;
  final attributes = <String>[];
  if (grid) {
    // Legacy grid argument: shape, then the label (`1+4x2+4 Intro`).
    final legacy = RegExp(r'^(\S+)\s*(.*)$').firstMatch(label);
    if (legacy != null && GridShape.tryParse(legacy.group(1)) != null) {
      attributes.add('shape="${legacy.group(1)}"');
      label = legacy.group(2)!;
    }
  }
  if (label.isNotEmpty) {
    final quoted = _quote(label);
    if (quoted == null) return null;
    attributes.add('label=$quoted');
  }
  return '${m.group(1)}: ${attributes.join(' ')}}';
}

/// [value] in quotes the attribute syntax can read back, or null if it
/// contains both kinds of quotes.
String? _quote(String value) {
  if (!value.contains('"')) return '"$value"';
  if (!value.contains("'")) return "'$value'";
  return null;
}

/// [source] with every section label in the attribute form.
String convertLegacySectionLabels(String source) {
  // From the end, so the offsets of earlier labels stay valid.
  for (final label in findLegacySectionLabels(source).reversed) {
    source = source.replaceRange(label.start, label.end, label.replacement);
  }
  return source;
}
