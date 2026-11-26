/// Section headings written as comments, e.g. `{comment: Verse 1}` (#463),
/// and the musical role of a section (ADR-0033).
library;

import 'song.dart';

/// German (and Swiss) section names and their English names (#1036,
/// #1085), keyed by the name in lower case without spaces, hyphens,
/// underscores and dots. Section names are English (ADR-0008); the
/// conversions translate these.
const germanSectionNames = {
  'strophe': 'Verse',
  'vers': 'Verse',
  'refrain': 'Chorus',
  'ref': 'Chorus',
  'kehrvers': 'Chorus',
  'prerefrain': 'Pre-Chorus',
  'vorrefrain': 'Pre-Chorus',
  'postrefrain': 'Post-Chorus',
  'nachrefrain': 'Post-Chorus',
  'brücke': 'Bridge',
  'zwischenteil': 'Bridge',
  'mittelteil': 'Bridge',
  'zwischenspiel': 'Interlude',
  'überleitung': 'Interlude',
  'vorspiel': 'Intro',
  'einleitung': 'Intro',
  'schluss': 'Outro',
  'schluß': 'Outro',
  'nachspiel': 'Outro',
  'abschluss': 'Outro',
  'abschluß': 'Outro',
  'ausklang': 'Outro',
  'ende': 'Ending',
};

const _names =
    r'(pre[\s_-]?chorus|pre[\s_-]?refrain|vor[\s_-]?refrain|'
    r'post[\s_-]?chorus|post[\s_-]?refrain|nach[\s_-]?refrain|chorus|'
    r'refrain|ref\.|ref|kehrvers|verse|vers|strophe|bridge|brücke|'
    r'zwischenteil|mittelteil|intro|vorspiel|einleitung|outro|tag|interlude|'
    r'instrumental|zwischenspiel|überleitung|ending|ende|schluss|schluß|'
    r'nachspiel|abschluss|abschluß|ausklang|coda|solo|vamp|turnaround)';

final _heading = RegExp(
  '^$_names'
  r'(\s*\d+[a-z]?)?(\s*\(.*\))?\s*:?$',
  caseSensitive: false,
  unicode: true,
);

/// A section name such as `Pre-Refrain` in lower case without spaces,
/// hyphens, underscores and dots: `prerefrain`.
String _key(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[\s_.-]'), '');

/// The name of a section heading [text] (`Strophe 2:` → `Strophe`) and
/// the rest after it (` 2:`), or null if it is not a section heading.
(String, String)? sectionHeadingParts(String text) {
  final match = _heading.firstMatch(text);
  if (match == null) return null;
  // The name starts the match.
  final name = match.group(1)!;
  return (name, text.substring(name.length));
}

/// The English key of a section name: `strophe` → `verse`,
/// `Pre-Refrain` → `prechorus`, `Chorus` → `chorus`.
String _englishKey(String name) {
  final key = _key(name);
  final english = germanSectionNames[key];
  return english == null ? key : _key(english);
}

/// The section kind of a comment [text] that is a section heading, such
/// as `Chorus 1` or `Strophe 2:`, or null if it is not one.
///
/// SongSelect and other sources mark sections with a comment heading
/// instead of `{start_of_…}`; the parser turns such an implicit section
/// into a labelled one and the editor colours it the same way.
SectionKind? headingSectionKind(String text) {
  final match = _heading.firstMatch(text.trim());
  if (match == null) return null;
  return switch (_englishKey(match.group(1)!)) {
    'chorus' => SectionKind.chorus,
    'verse' => SectionKind.verse,
    'bridge' => SectionKind.bridge,
    _ => SectionKind.custom,
  };
}

/// The environment a comment heading [text] becomes (#963): `chorus` or
/// `bridge` for those, `verse` for all others (`Intro`, `Interlude`,
/// `Solo 2`), like the editor's section menu; the label then gives the
/// verse its role (#1093). Null if [text] is no heading.
String? headingEnvironment(String text) => switch (headingSectionKind(text)) {
  null => null,
  SectionKind.chorus => 'chorus',
  SectionKind.bridge => 'bridge',
  _ => 'verse',
};

/// Musical role of a section, used to style it (ADR-0033). Unlike
/// [SectionKind], which follows the ChordPro environments, the role is
/// derived from the section name, so `{start_of_intro}` and a comment
/// heading `{c: Solo 2}` get a role of their own.
enum SectionRole {
  /// Not recognised: unlabelled lyrics, tabs, grids, post-chorus and any
  /// other name.
  standard,
  intro,
  verse,
  preChorus,
  chorus,
  bridge,
  interlude,
  outro,
}

/// Role of a section [name] such as `intro`, `pre_chorus` or `Solo 2:`, or
/// null if the name is not one of the known synonyms.
SectionRole? sectionRoleOfName(String name) {
  final match = _heading.firstMatch(name.trim());
  if (match == null) return null;
  return switch (_englishKey(match.group(1)!)) {
    'intro' => SectionRole.intro,
    'verse' => SectionRole.verse,
    'prechorus' => SectionRole.preChorus,
    'chorus' => SectionRole.chorus,
    'bridge' => SectionRole.bridge,
    'interlude' ||
    'instrumental' ||
    'solo' ||
    'vamp' ||
    'turnaround' => SectionRole.interlude,
    'outro' || 'ending' || 'coda' || 'tag' => SectionRole.outro,
    _ => SectionRole.standard,
  };
}

/// Role of [section]: chorus and bridge environments keep their kind; a
/// verse environment takes the role of a recognised label (the editor
/// inserts Intro, Interlude, Solo … as `{start_of_verse: label="…"}`,
/// #1093) and is a verse otherwise; a custom environment or a comment
/// heading is matched by its environment name, then by its label. Tabs,
/// grids and unlabelled sections are [SectionRole.standard].
SectionRole sectionRoleOf(Section section) => switch (section.kind) {
  SectionKind.verse => switch (_roleOf(section.label)) {
    null || SectionRole.standard => SectionRole.verse,
    final role => role,
  },
  SectionKind.chorus => SectionRole.chorus,
  SectionKind.bridge => SectionRole.bridge,
  SectionKind.tab ||
  SectionKind.grid ||
  SectionKind.none => SectionRole.standard,
  SectionKind.custom =>
    _roleOf(section.name) ?? _roleOf(section.label) ?? SectionRole.standard,
};

SectionRole? _roleOf(String? name) {
  if (name == null) return null;
  // A label may span several lines ("Intro\nDrums only").
  return sectionRoleOfName(name.split('\n').first);
}
