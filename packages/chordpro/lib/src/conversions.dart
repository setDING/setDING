/// The conversions the editor offers for a ChordPro source, counted and
/// applied together (#798): songs that still need one show up in the song
/// list and on the overview, and can be converted all at once.
///
/// Unlike the problems of `validateChordPro`, these places show as
/// intended; converting them only makes the source standard-conforming or
/// tidier:
///
/// - `{ccli}` and `{ccli_license}` of songs saved before #777
///   (`normalizeSongSelectDirectives`);
/// - the plain-text CCLI footer of SongSelect files (`removeCcliFooters`,
///   #785);
/// - CCLI bar lines that become grid sections (`convertCcliGrids`, #481);
/// - section labels in the short form (`convertLegacySectionLabels`, #672).
library;

import 'ccli_footer.dart';
import 'ccli_grid.dart';
import 'section_labels.dart';
import 'songselect.dart';

/// How many places of [source] one of the conversions changes; 0 if
/// [applyChordProConversions] leaves it as it is.
int countChordProConversions(String source) =>
    countSongSelectDirectives(source) +
    findCcliFooters(source).length +
    findCcliGrids(source).length +
    findLegacySectionLabels(source).length;

/// [source] with every conversion applied. The SongSelect directives come
/// first, so the footer sees `{x_ccli}` and does not add a second one.
String applyChordProConversions(String source) {
  var text = normalizeSongSelectDirectives(source);
  text = removeCcliFooters(text);
  text = convertCcliGrids(text);
  return convertLegacySectionLabels(text);
}
