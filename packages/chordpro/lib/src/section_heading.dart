/// Section headings written as comments, e.g. `{comment: Verse 1}` (#463),
/// and the musical role of a section (ADR-0033).
library;

import 'song.dart';

const _names =
    r'(pre[\s_-]?chorus|pre[\s_-]?refrain|post[\s_-]?chorus|chorus|refrain|'
    r'verse|vers|strophe|bridge|intro|outro|tag|interlude|instrumental|'
    r'zwischenspiel|ending|schluss|coda|solo|vamp|turnaround)';

final _heading = RegExp(
  '^$_names'
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

/// The environment a comment heading [text] becomes (#963): `verse`,
/// `chorus` or `bridge`, or the heading's own name for the others
/// (`Pre-Chorus 2` → `pre_chorus`), so the section keeps its kind
/// ([SectionKind.custom]) and its role. Null if [text] is no heading.
String? headingEnvironment(String text) {
  final kind = headingSectionKind(text);
  if (kind == null) return null;
  return switch (kind) {
    SectionKind.verse => 'verse',
    SectionKind.chorus => 'chorus',
    SectionKind.bridge => 'bridge',
    _ =>
      _heading
          .firstMatch(text.trim())!
          .group(1)!
          .toLowerCase()
          .replaceAll(RegExp(r'[\s_-]+'), '_'),
  };
}

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
  final word = match.group(1)!.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  return switch (word) {
    'intro' => SectionRole.intro,
    'verse' || 'vers' || 'strophe' => SectionRole.verse,
    'prechorus' || 'prerefrain' => SectionRole.preChorus,
    'chorus' || 'refrain' => SectionRole.chorus,
    'bridge' => SectionRole.bridge,
    'interlude' ||
    'instrumental' ||
    'zwischenspiel' ||
    'solo' ||
    'vamp' ||
    'turnaround' => SectionRole.interlude,
    'outro' || 'ending' || 'schluss' || 'coda' || 'tag' => SectionRole.outro,
    _ => SectionRole.standard,
  };
}

/// Role of [section]: verse, chorus and bridge environments keep their
/// kind; a custom environment or a comment heading is matched by its
/// environment name, then by its label. Tabs, grids and unlabelled
/// sections are [SectionRole.standard].
SectionRole sectionRoleOf(Section section) => switch (section.kind) {
  SectionKind.verse => SectionRole.verse,
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
