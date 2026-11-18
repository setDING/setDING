/// Line and chord editing commands of the ChordPro editor (#361).
///
/// Pure functions on the source text and the selection, so the editor only
/// applies their result. Each command returns null when it changes nothing.
library;

import 'ccli_grid.dart';
import 'chords_over_lyrics.dart';
import 'highlight.dart';

/// Text and selection after an editing command. [base] and [extent] are
/// the selection ends as in Flutter's `TextSelection`.
class SourceEdit {
  const SourceEdit(this.text, this.base, this.extent);

  final String text;
  final int base;
  final int extent;

  @override
  bool operator ==(Object other) =>
      other is SourceEdit &&
      other.text == text &&
      other.base == base &&
      other.extent == extent;

  @override
  int get hashCode => Object.hash(text, base, extent);

  @override
  String toString() => 'SourceEdit(${text.length} chars, $base, $extent)';
}

/// The lines touched by the selection `[base, extent]`: start of the first
/// line and end of the last line (before its line break). A selection that
/// ends at the start of a line does not include that line.
(int, int) _lineBlock(String text, int base, int extent) {
  var start = base < extent ? base : extent;
  var end = base < extent ? extent : base;
  start = start.clamp(0, text.length);
  end = end.clamp(0, text.length);
  if (end > start && text[end - 1] == '\n') end--;
  final blockStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final nl = text.indexOf('\n', end);
  return (blockStart, nl < 0 ? text.length : nl);
}

/// Moves the lines touched by the selection one line up ([up]) or down,
/// swapping them with the neighbouring line. The selection moves along.
SourceEdit? moveLines(String text, int base, int extent, {required bool up}) {
  final (start, end) = _lineBlock(text, base, extent);
  final block = text.substring(start, end);
  if (up) {
    if (start == 0) return null;
    final prevStart = start == 1 ? 0 : text.lastIndexOf('\n', start - 2) + 1;
    final prev = text.substring(prevStart, start - 1);
    final shift = -(prev.length + 1);
    return SourceEdit(
      text.replaceRange(prevStart, end, '$block\n$prev'),
      base + shift,
      extent + shift,
    );
  }
  if (end >= text.length) return null;
  final nextEnd = _lineEnd(text, end + 1);
  final next = text.substring(end + 1, nextEnd);
  final shift = next.length + 1;
  return SourceEdit(
    text.replaceRange(start, nextEnd, '$next\n$block'),
    base + shift,
    extent + shift,
  );
}

int _lineEnd(String text, int from) {
  final nl = text.indexOf('\n', from);
  return nl < 0 ? text.length : nl;
}

/// Inserts a copy of the lines touched by the selection below them; the
/// selection moves to the copy.
SourceEdit duplicateLines(String text, int base, int extent) {
  final (start, end) = _lineBlock(text, base, extent);
  final block = text.substring(start, end);
  final shift = block.length + 1;
  return SourceEdit(
    text.replaceRange(end, end, '\n$block'),
    base + shift,
    extent + shift,
  );
}

/// Deletes the lines touched by the selection; the cursor ends up at the
/// start of the line that follows them.
SourceEdit? deleteLines(String text, int base, int extent) {
  if (text.isEmpty) return null;
  final (start, end) = _lineBlock(text, base, extent);
  if (end < text.length) {
    return SourceEdit(text.replaceRange(start, end + 1, ''), start, start);
  }
  // The last line: also remove the line break before it.
  final from = start > 0 ? start - 1 : start;
  final cursor = from == 0 ? 0 : text.lastIndexOf('\n', from - 1) + 1;
  return SourceEdit(text.replaceRange(from, end, ''), cursor, cursor);
}

final _commentPrefix = RegExp(r'^([ \t]*)# ?');

/// Turns the lines touched by the selection into `#` comment lines, or
/// back into normal lines when all of them are comments already. Empty
/// lines stay as they are.
SourceEdit? toggleComment(String text, int base, int extent) {
  final (start, end) = _lineBlock(text, base, extent);
  final lines = text.substring(start, end).split('\n');
  final filled = lines.where((l) => l.trim().isNotEmpty).toList();
  if (filled.isEmpty) return null;
  final uncomment = filled.every(_commentPrefix.hasMatch);
  // Edits as (offset, removed length, inserted text), in text order.
  final edits = <(int, int, String)>[];
  var lineStart = start;
  for (final line in lines) {
    if (line.trim().isNotEmpty) {
      if (uncomment) {
        final m = _commentPrefix.firstMatch(line)!;
        final indent = m.group(1)!.length;
        edits.add((lineStart + indent, m.end - indent, ''));
      } else {
        edits.add((lineStart, 0, '# '));
      }
    }
    lineStart += line.length + 1;
  }
  var result = text;
  for (final (at, removed, inserted) in edits.reversed) {
    result = result.replaceRange(at, at + removed, inserted);
  }
  int map(int offset) {
    var shift = 0;
    for (final (at, removed, inserted) in edits) {
      if (offset < at) break;
      if (offset < at + removed) return at + shift;
      shift += inserted.length - removed;
    }
    return offset + shift;
  }

  return SourceEdit(result, map(base), map(extent));
}

const _chordKinds = {
  SourceTokenKind.chord,
  SourceTokenKind.annotation,
  SourceTokenKind.unknownChord,
};

/// Moves chords one character to the right ([right]) or left within the
/// lyrics: the chord at the cursor (inside or right next to it), or all
/// chords in the selection. A chord swaps places with the character next
/// to it; at the end of a line a space is added. Chords right next to each
/// other move together. [tokens] are the highlighting tokens of [text], if
/// already known.
SourceEdit? moveChords(
  String text,
  int base,
  int extent, {
  required bool right,
  List<SourceToken>? tokens,
}) {
  tokens ??= highlightChordPro(text);
  final from = base < extent ? base : extent;
  final to = base < extent ? extent : base;
  final chords = [
    for (final t in tokens)
      if (_chordKinds.contains(t.kind) &&
          (from == to
              ? t.start <= from && from <= t.end
              : t.start < to && from < t.end))
        (t.start, t.end),
  ];
  if (chords.isEmpty) return null;
  var result = text;
  var newBase = base;
  var newExtent = extent;
  var moved = false;
  // From the far end, so that a chord can move into the place the chord
  // next to it just left, and offsets of the remaining chords stay valid.
  for (final (start, end) in right ? chords.reversed : chords) {
    if (right) {
      final next = end < result.length ? result[end] : '\n';
      if (next == '[') continue;
      final inserted = next == '\n';
      final chord = result.substring(start, end);
      result = inserted
          ? result.replaceRange(start, end, ' $chord')
          : result.replaceRange(start, end + 1, '$next$chord');
      int map(int o) =>
          (o >= start && o <= end) || (inserted && o > end) ? o + 1 : o;
      newBase = map(newBase);
      newExtent = map(newExtent);
    } else {
      if (start == 0) continue;
      final prev = result[start - 1];
      if (prev == '\n' || prev == ']') continue;
      final chord = result.substring(start, end);
      result = result.replaceRange(start - 1, end, '$chord$prev');
      int map(int o) => o >= start && o <= end ? o - 1 : o;
      newBase = map(newBase);
      newExtent = map(newExtent);
    }
    moved = true;
  }
  return moved ? SourceEdit(result, newBase, newExtent) : null;
}

/// Ranges `(start, end)` of all occurrences of [query] in [text], without
/// overlaps (#368); ignoring case unless [caseSensitive] (#379). Empty for
/// an empty query.
List<(int, int)> findInSource(
  String text,
  String query, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return const [];
  final haystack = caseSensitive ? text : text.toLowerCase();
  final needle = caseSensitive ? query : query.toLowerCase();
  // Lower-casing keeps the length for the scripts of song texts; if it
  // does not, fall back to a case-insensitive pattern.
  if (haystack.length != text.length || needle.length != query.length) {
    return [
      for (final m in RegExp(
        RegExp.escape(query),
        caseSensitive: false,
      ).allMatches(text))
        (m.start, m.end),
    ];
  }
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final at = haystack.indexOf(needle, from);
    if (at < 0) return out;
    out.add((at, at + needle.length));
    from = at + needle.length;
  }
}

/// Converts chords-over-lyrics text to ChordPro (#362): the lines touched
/// by the selection, which is then the converted block, or the whole text
/// when nothing is selected.
SourceEdit? convertChordsOverLyricsIn(String text, int base, int extent) {
  if (base == extent) {
    final converted = convertChordsOverLyrics(text);
    if (converted == text) return null;
    final cursor = base.clamp(0, converted.length);
    return SourceEdit(converted, cursor, cursor);
  }
  final (start, end) = _lineBlock(text, base, extent);
  final block = text.substring(start, end);
  final converted = convertChordsOverLyrics(block);
  if (converted == block) return null;
  return SourceEdit(
    text.replaceRange(start, end, converted),
    start,
    start + converted.length,
  );
}

/// Converts CCLI bar lines to grid sections (#481): the blocks touched by
/// the selection, which then covers the converted sections, or all blocks
/// when nothing is selected; the cursor then moves to the first section.
SourceEdit? convertCcliGridsIn(String text, int base, int extent) {
  var grids = findCcliGrids(text);
  if (base != extent) {
    final (start, end) = _lineBlock(text, base, extent);
    grids = [
      for (final g in grids)
        if (g.linesStart <= end && g.end >= start) g,
    ];
  }
  if (grids.isEmpty) return null;
  final converted = convertCcliGrids(text, grids);
  final first = grids.first.start;
  if (base == extent) return SourceEdit(converted, first, first);
  final last = grids.last;
  final end = last.end + converted.length - text.length;
  return SourceEdit(converted, first, end);
}

/// [text] with every range of [matches] (sorted, without overlaps, e.g.
/// from [findInSource]) replaced by [replacement] (#375).
String replaceInSource(
  String text,
  List<(int, int)> matches,
  String replacement,
) {
  final out = StringBuffer();
  var last = 0;
  for (final (start, end) in matches) {
    out
      ..write(text.substring(last, start))
      ..write(replacement);
    last = end;
  }
  out.write(text.substring(last));
  return out.toString();
}

/// Moves the text `[start, end)` to [drop] (an offset in the original
/// text), or copies it there when [copy] is set; the moved text is then
/// selected (#377). A selection of whole lines is dropped between lines:
/// [drop] snaps to the start of its line, or to the end of the text when it
/// is on the end of the last line. Returns null when nothing changes, e.g.
/// when the text is dropped inside itself.
SourceEdit? dropText(
  String text,
  int start,
  int end, {
  required int drop,
  bool copy = false,
}) {
  if (start > end) (start, end) = (end, start);
  if (start == end) return null;
  drop = drop.clamp(0, text.length);
  final atLineStart = start == 0 || text[start - 1] == '\n';
  final wholeLines =
      atLineStart && (text[end - 1] == '\n' || end == text.length);
  var removeStart = start;
  var moved = text.substring(start, end);
  if (wholeLines) {
    if (!moved.endsWith('\n')) {
      // The last line has no line break: take the one before it along.
      moved = '$moved\n';
      if (start > 0 && !copy) removeStart = start - 1;
    }
    final dropLineStart = drop == 0 ? 0 : text.lastIndexOf('\n', drop - 1) + 1;
    final onLastLineEnd =
        drop == text.length && !text.endsWith('\n') && dropLineStart < drop;
    if (onLastLineEnd) {
      // After the last line, which has no line break.
      moved = '\n${moved.substring(0, moved.length - 1)}';
    } else {
      drop = dropLineStart;
    }
  }
  // The selection leaves out the line break added in front of the text.
  final lead = wholeLines && moved.startsWith('\n') ? 1 : 0;
  if (copy) {
    return SourceEdit(
      text.replaceRange(drop, drop, moved),
      drop + lead,
      drop + moved.length,
    );
  }
  if (drop >= removeStart && drop <= end) return null;
  final without = text.replaceRange(removeStart, end, '');
  final at = drop > end ? drop - (end - removeStart) : drop;
  return SourceEdit(
    without.replaceRange(at, at, moved),
    at + lead,
    at + moved.length,
  );
}

/// Column in the source [line] of the character [textIndex] of its
/// rendered text, i.e. the text without chords and markup; for a
/// directive line (`{comment: …}`) of the text of its value (#381). With
/// [atChord], the column of the `[` of the chord at that position, if
/// there is one. Indexes past the end give the end of the text.
int sourceColumn(String line, int textIndex, {bool atChord = false}) {
  var start = 0;
  var end = line.length;
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('{')) {
    final colon = line.indexOf(':');
    final close = line.lastIndexOf('}');
    if (close >= 0) end = close;
    start = colon < 0 || colon >= end ? end : colon + 1;
    while (start < end && (line[start] == ' ' || line[start] == '\t')) {
      start++;
    }
  }
  var count = 0;
  var i = start;
  while (i < end) {
    final char = line[i];
    if (char == '[' || char == '<') {
      final close = line.indexOf(char == '[' ? ']' : '>', i);
      if (close < 0) break;
      if (char == '[' && atChord && count == textIndex) return i;
      i = close + 1;
      continue;
    }
    if (count == textIndex) return i;
    count++;
    i++;
  }
  return i.clamp(start, end);
}
