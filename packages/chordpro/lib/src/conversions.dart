/// The conversions the editor offers for a ChordPro source, counted and
/// applied together (#798): songs that still need one show up in the song
/// list and on the overview, and can be converted all at once.
///
/// Unlike the problems of `validateChordPro`, these places show as
/// intended; converting them makes the source standard-conforming or
/// tidier:
///
/// - `{ccli}` and `{ccli_license}` of songs saved before #777
///   (`normalizeSongSelectDirectives`);
/// - the plain-text CCLI footer of SongSelect files (`removeCcliFooters`,
///   #785);
/// - CCLI bar lines that become grid sections (`convertCcliGrids`, #481);
/// - section labels in the short form (`convertLegacySectionLabels`, #672);
/// - section headings written as comments, such as `{comment: Verse 1}`,
///   that become section environments (`convertCommentHeadings`, #963);
/// - German section labels such as `Vers 1` or `Schluss`, which become
///   English (`translateSectionLabels`, #1085), since section names are
///   English (ADR-0008). This one also changes what is shown.
library;

import 'ccli_footer.dart';
import 'ccli_grid.dart';
import 'comment_headings.dart';
import 'english_labels.dart';
import 'section_labels.dart';
import 'songselect.dart';

/// How many places of [source] one of the conversions changes; 0 if
/// [applyChordProConversions] leaves it as it is.
int countChordProConversions(String source) =>
    countSongSelectDirectives(source) +
    findCcliFooters(source).length +
    findCcliGrids(source).length +
    findLegacySectionLabels(source).length +
    findCommentHeadings(source).length +
    findGermanSectionLabels(source).length;

/// [source] with every conversion applied. The SongSelect directives come
/// first, so the footer sees `{x_ccli}` and does not add a second one; the
/// grids come before the comment headings, so a heading over bar lines
/// becomes the grid label; the labels are translated last, so the labels
/// of the new environments are English too.
String applyChordProConversions(String source) {
  var text = normalizeSongSelectDirectives(source);
  text = removeCcliFooters(text);
  text = convertCcliGrids(text);
  text = convertLegacySectionLabels(text);
  text = convertCommentHeadings(text);
  return translateSectionLabels(text);
}
