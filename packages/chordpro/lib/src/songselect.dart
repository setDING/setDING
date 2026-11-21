/// Clean-up of CCLI SongSelect files on import (ADR-0011, #777).
library;

/// Start of a directive, also in the `{meta: name …}` form.
const _start = r'^[ \t]*\{[ \t]*(?:meta[ \t]*:?[ \t]*)?';

/// A `{ccli_license}` line including its line break.
final _licenseLine = RegExp(
  '$_start'
  r'ccli_license(?=[ \t:}])[^\n]*(?:\n|$)',
  multiLine: true,
  caseSensitive: false,
);

/// The name `ccli` of a `{ccli}` directive (group 1 is everything before).
final _ccliName = RegExp(
  '($_start)'
  r'ccli(?=[ \t:}])',
  multiLine: true,
  caseSensitive: false,
);

/// [source] with the two directives of CCLI SongSelect files that the
/// ChordPro specification does not define made standard-conforming:
///
/// - `{ccli: 1234}` becomes the setDING custom directive `{x_ccli: 1234}`
///   (custom directives start with `x_`, ADR-0012);
/// - `{ccli_license: …}` is removed with its line: it is the licence
///   number of the church that downloaded the song, not song data.
///
/// The `{meta: ccli …}` forms are handled the same way. Everything else
/// stays as written.
String normalizeSongSelectDirectives(String source) => source
    .replaceAll(_licenseLine, '')
    .replaceAllMapped(_ccliName, (m) => '${m.group(1)}x_ccli');
