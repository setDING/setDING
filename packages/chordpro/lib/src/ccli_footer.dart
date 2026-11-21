/// The CCLI footer that SongSelect writes after a song (#785): a plain-text
/// paragraph with song number, copyright, terms of use and licence number,
/// e.g.
///
/// ```text
/// CCLI Song # 6016351
/// © 2011 Atlas Mountain Songs | Thankyou Music Ltd
/// For use solely with the SongSelect® Terms of Use. All rights reserved. www.ccli.com
/// CCLI License # 1375063
/// ```
///
/// It would be shown as lyrics. The import removes it, the editor offers to;
/// song number and copyright go into `{x_ccli}` (ADR-0011, #777) and
/// `{copyright}` if the song does not have them yet. The licence number belongs to the church, not to
/// the song, and is dropped.
library;

import 'source_metadata.dart';

/// A CCLI footer found in the source.
class CcliFooter {
  const CcliFooter({
    required this.start,
    required this.end,
    required this.line,
    this.songNumber,
    this.copyright,
  });

  /// Range of the footer lines, from the start of the first line to the end
  /// of the last one (including its line break).
  final int start;
  final int end;

  /// Line number of the first footer line, starting at 1.
  final int line;

  /// CCLI song number and copyright, if written.
  final String? songNumber;
  final String? copyright;

  @override
  String toString() => 'CcliFooter(line $line, $start–$end)';
}

// `CCLI Song # 6016351`, `CCLI-Liednummer 6016351`, `CCLI Song No. 1`.
final _songNumber = RegExp(
  r'^CCLI[\s-]*(?:Song|Lied)(?:[\s-]*(?:nummer|number))?\s*'
  r'(?:#|Nr\.?|No\.?)?\s*:?\s*(\d+)\s*$',
  caseSensitive: false,
);

// `CCLI License # 1375063`, `CCLI-Lizenznummer 1375063`.
final _license = RegExp(
  r'^CCLI[\s-]*(?:Licen[cs]e|Lizenz)(?:[\s-]*(?:nummer|number))?\s*'
  r'(?:#|Nr\.?|No\.?)?\s*:?\s*(\d+)\s*$',
  caseSensitive: false,
);

// `© 2011 …`, `Copyright 2011 …`, `(c) 2011 …`.
final _copyright = RegExp(r'^(?:©|\(c\)|copyright\b)\s*', caseSensitive: false);

// The terms of use line, in any language.
final _terms = RegExp(r'SongSelect|ccli\.com', caseSensitive: false);

final _newSong = RegExp(r'^\{\s*(?:new_song|ns)\s*\}$');

/// A line of [source] without its line break.
typedef _Line = ({int start, int end, int next, String text});

Iterable<_Line> _lines(String source, [int from = 0, int? to]) sync* {
  final limit = to ?? source.length;
  var pos = from;
  while (pos < limit) {
    var lineEnd = source.indexOf('\n', pos);
    if (lineEnd < 0 || lineEnd > limit) lineEnd = limit;
    final next = lineEnd < limit ? lineEnd + 1 : limit;
    var end = lineEnd;
    if (end > pos && source[end - 1] == '\r') end--;
    yield (start: pos, end: end, next: next, text: source.substring(pos, end));
    pos = next;
  }
}

bool _isFooterLine(String line) =>
    _songNumber.hasMatch(line) ||
    _license.hasMatch(line) ||
    _copyright.hasMatch(line) ||
    (_terms.hasMatch(line) && !line.startsWith('{'));

/// CCLI footers in [source], in source order: runs of consecutive lines
/// that are all footer lines (song number, licence number, copyright,
/// terms of use) with at least a song or licence number.
List<CcliFooter> findCcliFooters(String source) {
  final found = <CcliFooter>[];
  final run = <_Line>[];
  var lineNumber = 0;
  var runLine = 0;

  void flush() {
    if (run.isEmpty) return;
    String? number;
    var license = false;
    String? copyright;
    for (final l in run) {
      final text = l.text.trim();
      number ??= _songNumber.firstMatch(text)?.group(1);
      license = license || _license.hasMatch(text);
      final c = _copyright.firstMatch(text);
      if (c != null) copyright ??= text.substring(c.end).trim();
    }
    if (number != null || license) {
      found.add(
        CcliFooter(
          start: run.first.start,
          end: run.last.next,
          line: runLine,
          songNumber: number,
          copyright: copyright == null || copyright.isEmpty ? null : copyright,
        ),
      );
    }
    run.clear();
  }

  for (final l in _lines(source)) {
    lineNumber++;
    if (_isFooterLine(l.text.trim())) {
      if (run.isEmpty) runLine = lineNumber;
      run.add(l);
    } else {
      flush();
    }
  }
  flush();
  return found;
}

/// [source] without its CCLI footers. Song number and copyright are kept
/// as `{x_ccli}` and `{copyright}` where the song has none yet (also no
/// `{ccli}` of a song saved before #777); with several songs (`{new_song}`), each song
/// gets the values of its own footer.
String removeCcliFooters(String source) {
  // Songs from the end, so the offsets of earlier songs stay valid.
  final songStarts = [0];
  for (final l in _lines(source)) {
    if (l.start > 0 && _newSong.hasMatch(l.text.trim())) {
      songStarts.add(l.next);
    }
  }
  for (var i = songStarts.length - 1; i >= 0; i--) {
    final start = songStarts[i];
    final end = i + 1 < songStarts.length
        ? _lineStartBefore(source, songStarts[i + 1])
        : source.length;
    final song = source.substring(start, end);
    final cleaned = _removeFromSong(song);
    if (cleaned != song) source = source.replaceRange(start, end, cleaned);
  }
  return source;
}

/// Start of the line that ends right before [offset] (the `{new_song}`
/// line).
int _lineStartBefore(String source, int offset) {
  final lineEnd = offset - 1;
  return lineEnd <= 0 ? 0 : source.lastIndexOf('\n', lineEnd - 1) + 1;
}

String _removeFromSong(String song) {
  final footers = findCcliFooters(song);
  if (footers.isEmpty) return song;
  for (final f in footers.reversed) {
    var from = f.start;
    final after = song.substring(f.end);
    final followedByBlank =
        after.trim().isEmpty || RegExp(r'^[ \t]*\r?\n').hasMatch(after);
    if (followedByBlank) {
      // Also the empty lines before the footer, so one separation stays.
      while (from > 0) {
        final prevStart = from < 2 ? 0 : song.lastIndexOf('\n', from - 2) + 1;
        if (song.substring(prevStart, from).trim().isNotEmpty) break;
        from = prevStart;
      }
    }
    song = song.replaceRange(from, f.end, '');
  }
  final number = footers.map((f) => f.songNumber).nonNulls.firstOrNull;
  if (number != null &&
      sourceMetadata(song, 'x_ccli') == null &&
      sourceMetadata(song, 'ccli') == null) {
    song = setSourceMetadata(song, 'x_ccli', number);
  }
  final copyright = footers.map((f) => f.copyright).nonNulls.firstOrNull;
  if (copyright != null && sourceMetadata(song, 'copyright') == null) {
    song = setSourceMetadata(song, 'copyright', copyright);
  }
  return song;
}
