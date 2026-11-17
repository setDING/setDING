/// Section environments in the ChordPro source, for the editor (#371).
library;

import 'directive_names.dart';
import 'highlight.dart';

/// A section environment in the source: from the start of the line of its
/// start directive to the end of the line of its end directive (or up to
/// the next section or the end of the text when it is not closed).
class SourceSection {
  const SourceSection(this.start, this.end, this.type);

  final int start;
  final int end;

  /// Environment name: `verse`, `chorus`, `bridge`, `tab`, `grid`, `abc`,
  /// or any other name of `{start_of_…}`.
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

final _directiveName = RegExp(r'^\{?\s*([A-Za-z_]+)');

/// The section environments of [source], in order and without overlaps.
/// [tokens] are the highlighting tokens of [source], if already known.
List<SourceSection> sourceSections(String source, {List<SourceToken>? tokens}) {
  tokens ??= highlightChordPro(source);
  final out = <SourceSection>[];
  int? openStart;
  String? openType;
  int lineStart(int at) => at == 0 ? 0 : source.lastIndexOf('\n', at - 1) + 1;
  int lineEnd(int at) {
    final nl = source.indexOf('\n', at);
    return nl < 0 ? source.length : nl;
  }

  void close(int end) {
    if (openStart != null) {
      out.add(SourceSection(openStart!, end, openType!));
      openStart = null;
      openType = null;
    }
  }

  for (final token in tokens) {
    if (token.kind != SourceTokenKind.sectionDirective) continue;
    final match = _directiveName.firstMatch(
      source.substring(token.start, token.end),
    );
    if (match == null) continue;
    final name = match.group(1)!.toLowerCase();
    final startType = name.startsWith('start_of_')
        ? name.substring('start_of_'.length)
        : shortSectionStarts[name];
    final endType = name.startsWith('end_of_')
        ? name.substring('end_of_'.length)
        : shortSectionEnds[name];
    if (startType != null && startType.isNotEmpty) {
      // An unclosed section ends before the next one.
      final start = lineStart(token.start);
      close(start > 0 ? start - 1 : 0);
      openStart = start;
      openType = startType;
    } else if (endType != null && openStart != null) {
      close(lineEnd(token.end));
    }
  }
  close(source.length);
  return out;
}
