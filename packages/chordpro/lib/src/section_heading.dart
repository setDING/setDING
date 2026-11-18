/// Section headings written as comments, e.g. `{comment: Verse 1}` (#463).
library;

import 'song.dart';

final _heading = RegExp(
  r'^(pre[\s-]?chorus|pre[\s-]?refrain|post[\s-]?chorus|chorus|refrain|'
  r'verse|vers|strophe|bridge|intro|outro|tag|interlude|instrumental|'
  r'zwischenspiel|ending|schluss|coda|solo|vamp|turnaround)'
  r'(\s*\d+[a-z]?)?(\s*\(.*\))?\s*:?$',
  caseSensitive: false,
);

/// The section kind of a comment [text] that is a section heading, such
/// as `Chorus 1` or `Strophe 2:`, or null if it is not one.
///
/// SongSelect and other sources mark sections with a comment heading
/// instead of `{start_of_…}`; the parser turns such an implicit section
/// into a labelled one and the editor colours it the same way.
SectionKind? headingSectionKind(String text) {
  final match = _heading.firstMatch(text.trim());
  if (match == null) return null;
  return switch (match.group(1)!.toLowerCase()) {
    'chorus' || 'refrain' => SectionKind.chorus,
    'verse' || 'vers' || 'strophe' => SectionKind.verse,
    'bridge' => SectionKind.bridge,
    _ => SectionKind.custom,
  };
}
