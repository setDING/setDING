/// Converts CCLI SongSelect bar lines to grid sections (#481).
///
/// SongSelect writes instrumental parts as lines of chords and bar lines in
/// brackets, after a comment that names the part:
///
/// ```text
/// {comment: Instrumental}
/// [||:][G/B]  [C2]  [.]  [.][|][D(4)]  [Em7]  [.]  [.][|]
/// [|]   [Am7(4)]          [|][D7sus]               [:||]
/// ```
///
/// becomes
///
/// ```text
/// {start_of_grid shape="2x4" label="Instrumental"}
/// |: G/B C2 . . | D(4) Em7 . . |
/// | Am7(4) . . . | D7sus . . . :|
/// {end_of_grid}
/// ```
library;

import 'directive.dart';
import 'directive_names.dart';

/// A block of CCLI bar lines in a source, with its grid section.
class CcliGrid {
  const CcliGrid({
    required this.start,
    required this.end,
    required this.linesStart,
    required this.line,
    required this.replacement,
  });

  /// Range in the source that [replacement] replaces: the bar lines and,
  /// when it becomes the grid label, the comment before them.
  final int start;
  final int end;

  /// Start of the first bar line (after the comment, if any).
  final int linesStart;

  /// Line number of the first bar line, starting at 1.
  final int line;

  /// The grid section.
  final String replacement;

  @override
  String toString() => 'CcliGrid(line $line, $start–$end)';
}

final _bracketLine = RegExp(r'^[ \t]*(?:\[[^\[\]]*\][ \t]*)+$');
final _bracket = RegExp(r'\[([^\[\]]*)\]');
final _ccliBar = RegExp(r'^(:?)(\|\|?)(:?)$');

/// The grid bar symbol of a CCLI bar token, or null if [token] is no bar.
String? _barSymbol(String token) {
  if (token == '|.' || token == '||.') return '|.';
  final m = _ccliBar.firstMatch(token);
  if (m == null) return null;
  final open = m.group(3)!.isNotEmpty;
  final close = m.group(1)!.isNotEmpty;
  if (open && close) return ':|:';
  if (open) return '|:';
  if (close) return ':|';
  return m.group(2);
}

/// Grid tokens of a CCLI bar line, or null if [line] is none: only
/// bracketed tokens, at least one bar line and one chord or mark.
List<String>? _gridTokens(String line) {
  if (!_bracketLine.hasMatch(line)) return null;
  final tokens = <String>[];
  var bars = 0;
  for (final m in _bracket.allMatches(line)) {
    final token = m.group(1)!.trim();
    if (token.isEmpty || token.contains(RegExp(r'\s'))) return null;
    if (token.startsWith('*')) return null;
    final bar = _barSymbol(token);
    if (bar != null) bars++;
    tokens.add(bar ?? token);
  }
  final cells = tokens.length - bars;
  return bars > 0 && cells > 0 ? tokens : null;
}

bool _isBar(String token) => _barSymbol(token) == token;

/// One grid row: bars and measures of cells.
typedef _Row = List<Object>; // String (bar) or List<String> (measure)

_Row _row(List<String> tokens) {
  final row = <Object>[];
  var measure = <String>[];
  void flush() {
    if (measure.isNotEmpty) row.add(measure);
    measure = <String>[];
  }

  for (final token in tokens) {
    if (_isBar(token)) {
      flush();
      row.add(token);
    } else {
      measure.add(token);
    }
  }
  flush();
  // A grid line starts and ends with a bar line: words before the first
  // bar are its left margin.
  if (row.first is! String) row.insert(0, '|');
  if (row.last is! String) row.add('|');
  return row;
}

/// [cells] filled up to [beats] cells: chords that divide the measure
/// evenly are spread over it (`C G` in 4 → `C . G .`), others are followed
/// by empty cells.
List<String> _fill(List<String> cells, int beats) {
  final n = cells.length;
  if (n >= beats) return cells;
  if (beats % n == 0) {
    final step = beats ~/ n;
    return [
      for (final cell in cells) ...[cell, for (var i = 1; i < step; i++) '.'],
    ];
  }
  return [...cells, for (var i = n; i < beats; i++) '.'];
}

String _gridSection(List<_Row> rows, String? label, String nl) {
  var beats = 1;
  var measures = 1;
  for (final row in rows) {
    var count = 0;
    for (final part in row) {
      if (part is List<String>) {
        count++;
        if (part.length > beats) beats = part.length;
      }
    }
    if (count > measures) measures = count;
  }
  final attributes = StringBuffer('shape="${measures}x$beats"');
  if (label != null && label.isNotEmpty) {
    attributes.write(' label="${label.replaceAll('"', "'")}"');
  }
  return [
    '{start_of_grid $attributes}',
    for (final row in rows)
      [
        for (final part in row)
          if (part is List<String>) _fill(part, beats).join(' ') else part,
      ].join(' '),
    '{end_of_grid}',
  ].join(nl);
}

/// The blocks of CCLI bar lines in [source], in source order. Lines inside
/// environments such as `{start_of_grid}` are left alone.
List<CcliGrid> findCcliGrids(String source) {
  final nl = source.contains('\r\n') ? '\r\n' : '\n';
  // Each line: start offset, end offset (without line break) and text.
  final lines = <(int, int, String)>[];
  var offset = 0;
  while (true) {
    var end = source.indexOf('\n', offset);
    final last = end < 0;
    if (last) end = source.length;
    var textEnd = end;
    if (textEnd > offset && source[textEnd - 1] == '\r') textEnd--;
    lines.add((offset, textEnd, source.substring(offset, textEnd)));
    if (last) break;
    offset = end + 1;
  }

  final grids = <CcliGrid>[];
  String? environment;
  var i = 0;
  while (i < lines.length) {
    final text = lines[i].$3;
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      final d = parseDirective(trimmed);
      if (d != null) {
        final name = d.name;
        if (environment == null) {
          if (name.startsWith('start_of_')) {
            environment = name.substring(9);
          } else if (shortSectionStarts[name] case final env?) {
            environment = env;
          }
        } else if (name == 'end_of_$environment' ||
            shortSectionEnds[name] == environment) {
          environment = null;
        }
      }
      i++;
      continue;
    }
    if (environment != null || _gridTokens(text) == null) {
      i++;
      continue;
    }
    final first = i;
    final rows = <_Row>[];
    while (i < lines.length) {
      final tokens = _gridTokens(lines[i].$3);
      if (tokens == null) break;
      rows.add(_row(tokens));
      i++;
    }
    final lastLine = lines[i - 1];

    // The comment before the block names the part; it becomes the grid
    // label unless lyrics follow the block in the same part.
    String? label;
    var start = lines[first].$1;
    if (first > 0) {
      final before = lines[first - 1].$3.trim();
      final d = before.startsWith('{') ? parseDirective(before) : null;
      final after = i < lines.length ? lines[i].$3.trim() : '';
      final partEnds = after.isEmpty || after.startsWith('{');
      if (d != null &&
          d.selector == null &&
          commentDirectives.containsKey(d.name) &&
          d.name != 'highlight' &&
          partEnds) {
        label = d.plainArgument;
        start = lines[first - 1].$1;
      }
    }
    grids.add(
      CcliGrid(
        start: start,
        end: lastLine.$2,
        linesStart: lines[first].$1,
        line: first + 1,
        replacement: _gridSection(rows, label, nl),
      ),
    );
  }
  return grids;
}

/// [source] with [grids] (from [findCcliGrids], default all) replaced by
/// grid sections.
String convertCcliGrids(String source, [List<CcliGrid>? grids]) {
  var result = source;
  for (final grid in (grids ?? findCcliGrids(source)).reversed) {
    result = result.replaceRange(grid.start, grid.end, grid.replacement);
  }
  return result;
}
