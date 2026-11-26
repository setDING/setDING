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

/// The name `ccli` or `footer` of a `{ccli}` or `{footer}` directive
/// (group 1 is everything before, group 2 the name).
final _renamed = RegExp(
  '($_start)'
  r'(ccli|footer)(?=[ \t:}])',
  multiLine: true,
  caseSensitive: false,
);

/// How many `{ccli}`, `{footer}` and `{ccli_license}` directives [source]
/// has, which
/// [normalizeSongSelectDirectives] changes. Songs saved before #777 keep
/// them; the editor offers the conversion.
int countSongSelectDirectives(String source) =>
    _licenseLine.allMatches(source).length + _renamed.allMatches(source).length;

/// [source] with the three directives of CCLI SongSelect files that the
/// ChordPro specification does not define made standard-conforming:
///
/// - `{ccli: 1234}` becomes the setDING custom directive `{x_ccli: 1234}`
///   (custom directives start with `x_`, ADR-0012);
/// - `{footer: …}`, the SongSelect terms-of-use line, becomes
///   `{x_ccli_footer: …}`;
/// - `{ccli_license: …}` is removed with its line: it is the licence
///   number of the church that downloaded the song, not song data.
///
/// The `{meta: ccli …}` and `{meta: footer …}` forms are handled the same way. Everything else
/// stays as written.
String normalizeSongSelectDirectives(String source) => source
    .replaceAll(_licenseLine, '')
    .replaceAllMapped(
      _renamed,
      (m) =>
          '${m.group(1)}'
          '${m.group(2)!.toLowerCase() == 'ccli' ? 'x_ccli' : 'x_ccli_footer'}',
    );
