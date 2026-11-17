/// Converts "chords over lyrics" text to ChordPro (#362).
///
/// Songs copied from the web usually come as a line of chords above the
/// line of lyrics they belong to, aligned by column:
///
/// ```text
/// [Verse 1]
/// C         G
/// Hello my friend
/// ```
///
/// becomes
///
/// ```text
/// {comment: Verse 1}
/// [C]Hello my [G]friend
/// ```
library;

import 'chord.dart';

/// Chord-like tokens that are not chords: bar lines and repeat marks.
const _chordLineExtras = {'|', '||', '/', '-', '%', 'n.c.', 'n.c', 'nc'};

final _tokenPattern = RegExp(r'\S+');
final _repeat = RegExp(r'^\(?x\d+\)?$', caseSensitive: false);
final _header = RegExp(r'^\s*\[([^\]]+)\]\s*:?\s*$');

bool _isChord(String token) {
  final optional = RegExp(r'^\((.+)\)$').firstMatch(token);
  final chord = optional?.group(1) ?? token;
  // Strict: the suffix must be understood, so that words such as "Chorus"
  // or "Dad" are no chords, although the editor accepts them in brackets.
  return Chord.tryParse(chord)?.parsedSuffix != null;
}

/// Whether [line] contains only chords (and bar lines or repeat marks),
/// with at least one chord.
bool isChordLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('{') || trimmed.startsWith('#')) {
    return false;
  }
  var chords = 0;
  for (final m in _tokenPattern.allMatches(line)) {
    final token = m.group(0)!;
    if (_isChord(token)) {
      chords++;
    } else if (!_chordLineExtras.contains(token.toLowerCase()) &&
        !_repeat.hasMatch(token)) {
      return false;
    }
  }
  return chords > 0;
}

/// A line that ChordPro already understands or that is no lyrics.
bool _isSpecial(String line) {
  final trimmed = line.trimLeft();
  return trimmed.isEmpty ||
      trimmed.startsWith('{') ||
      trimmed.startsWith('#') ||
      line.contains('[');
}

/// Whether [text] has at least one chord line directly above a lyrics
/// line, so that [convertChordsOverLyrics] would merge something.
bool looksLikeChordsOverLyrics(String text) {
  final lines = text.split('\n');
  for (var i = 0; i + 1 < lines.length; i++) {
    if (isChordLine(lines[i]) &&
        !isChordLine(lines[i + 1]) &&
        !_isSpecial(lines[i + 1])) {
      return true;
    }
  }
  return false;
}

/// Converts chords-over-lyrics [text] to ChordPro:
///
/// - a chord line above a lyrics line is merged into it, each chord at its
///   column (lyrics shorter than the chords are padded with spaces);
/// - a chord line on its own keeps its spacing, its chords in brackets;
/// - repeat marks (`x2`) become annotations (`[*x2]`);
/// - a header in brackets that is no chord (`[Chorus]`) becomes
///   `{comment: Chorus}`;
/// - everything else, including ChordPro lines, stays as it is.
String convertChordsOverLyrics(String text) {
  final lines = text.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_header.firstMatch(line) case final m? when !_isChord(m.group(1)!)) {
      out.add('{comment: ${m.group(1)!.trim()}}');
      continue;
    }
    if (!isChordLine(line)) {
      out.add(line);
      continue;
    }
    final next = i + 1 < lines.length ? lines[i + 1] : null;
    if (next != null && !isChordLine(next) && !_isSpecial(next)) {
      out.add(_merge(line, next));
      i++;
    } else {
      out.add(line.trimRight().replaceAllMapped(_tokenPattern, _bracket));
    }
  }
  return out.join('\n');
}

String _bracket(Match m) => _inBrackets(m.group(0)!);

/// A token of a chord line in ChordPro: `[C]`, `[|]`, repeat marks as
/// annotation `[*x2]`.
String _inBrackets(String token) =>
    _repeat.hasMatch(token) ? '[*$token]' : '[$token]';

/// [lyrics] with the chords of [chords] inserted at their columns.
String _merge(String chords, String lyrics) {
  final tokens = [
    for (final m in _tokenPattern.allMatches(chords)) (m.start, m.group(0)!),
  ];
  final lastColumn = tokens.isEmpty ? 0 : tokens.last.$1;
  var result = lyrics.trimRight().padRight(lastColumn);
  // From the right, so the columns to the left stay valid.
  for (final (column, chord) in tokens.reversed) {
    result = result.replaceRange(column, column, _inBrackets(chord));
  }
  return result.trimRight();
}
