/// Bracket matching for the ChordPro editor (#37).
library;

import 'highlight.dart';

/// A bracket next to the cursor and its partner.
class BracketMatch {
  const BracketMatch(this.bracket, this.partner);

  /// Offset of the bracket next to the cursor.
  final int bracket;

  /// Offset of the matching bracket, or null if the bracket is unmatched.
  final int? partner;

  bool get matched => partner != null;

  @override
  bool operator ==(Object other) =>
      other is BracketMatch &&
      other.bracket == bracket &&
      other.partner == partner;

  @override
  int get hashCode => Object.hash(bracket, partner);

  @override
  String toString() => 'BracketMatch($bracket, $partner)';
}

const _pairs = {'[': ']', '{': '}'};
const _closers = {']': '[', '}': '{'};

/// Finds the bracket (`{`, `}`, `[`, `]`) next to [cursor] in [source] and
/// its partner. The bracket before the cursor wins over the one after it.
///
/// ChordPro brackets do not span lines, so matching is per line. Escaped
/// brackets (`\[`) and brackets in comment lines and delegated environments
/// (abc, ly, svg, textblock) are ignored. [tokens] are the highlighting
/// tokens of [source], if already known.
BracketMatch? matchBracket(
  String source,
  int cursor, {
  List<SourceToken>? tokens,
}) {
  if (cursor < 0 || cursor > source.length) return null;
  final candidates = [cursor - 1, cursor];
  final pairs = <int, int?>{};
  var analysed = -1;
  for (final at in candidates) {
    if (at < 0 || at >= source.length) continue;
    final char = source[at];
    if (!_pairs.containsKey(char) && !_closers.containsKey(char)) continue;
    final lineStart = source.lastIndexOf('\n', at) + 1;
    if (analysed != lineStart) {
      analysed = lineStart;
      tokens ??= highlightChordPro(source);
      pairs
        ..clear()
        ..addAll(_matchLine(source, lineStart, tokens));
    }
    if (pairs.containsKey(at)) return BracketMatch(at, pairs[at]);
  }
  return null;
}

/// All brackets of the line starting at [lineStart] with their partners.
Map<int, int?> _matchLine(
  String source,
  int lineStart,
  List<SourceToken> tokens,
) {
  var lineEnd = source.indexOf('\n', lineStart);
  if (lineEnd < 0) lineEnd = source.length;
  final kind = _kindAt(tokens, lineStart, lineEnd);
  if (kind == SourceTokenKind.delegate || kind == SourceTokenKind.comment) {
    return const {};
  }
  final result = <int, int?>{};
  final open = <int>[];
  for (var i = lineStart; i < lineEnd; i++) {
    final char = source[i];
    if (char == r'\' && i + 1 < lineEnd && '[]{}'.contains(source[i + 1])) {
      i++;
      continue;
    }
    if (_pairs.containsKey(char)) {
      open.add(i);
      result[i] = null;
    } else if (_closers.containsKey(char)) {
      if (open.isNotEmpty && source[open.last] == _closers[char]) {
        final start = open.removeLast();
        result[start] = i;
        result[i] = start;
      } else {
        result[i] = null;
      }
    }
  }
  return result;
}

/// The kind of the first non-text token of a line, if any.
SourceTokenKind? _kindAt(List<SourceToken> tokens, int start, int end) {
  // Binary search for the token containing [start].
  var lo = 0;
  var hi = tokens.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (tokens[mid].end <= start) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  for (var i = lo; i < tokens.length && tokens[i].start < end; i++) {
    if (tokens[i].kind != SourceTokenKind.text) return tokens[i].kind;
  }
  return null;
}
