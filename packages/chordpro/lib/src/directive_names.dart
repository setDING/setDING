/// Names of the directives the parser knows, shared by the parser, the
/// editor highlighting and autocompletion (ADR-0003, ADR-0012).
library;

import 'song.dart';

/// Directive names (long and short) of meta-data items.
const metaDirectiveAliases = {
  't': 'title',
  'title': 'title',
  'sorttitle': 'sorttitle',
  'st': 'subtitle',
  'subtitle': 'subtitle',
  'artist': 'artist',
  'sortartist': 'sortartist',
  'composer': 'composer',
  'lyricist': 'lyricist',
  'arranger': 'arranger',
  'copyright': 'copyright',
  'album': 'album',
  'year': 'year',
  'key': 'key',
  'time': 'time',
  'tempo': 'tempo',
  'duration': 'duration',
  'capo': 'capo',
  'tag': 'tag',
  // Used by CCLI SongSelect files (ADR-0011).
  'ccli': 'ccli',
  'ccli_license': 'ccli_license',
  'footer': 'footer',
};

const commentDirectives = {
  'c': CommentStyle.normal,
  'comment': CommentStyle.normal,
  'highlight': CommentStyle.normal,
  'ci': CommentStyle.italic,
  'comment_italic': CommentStyle.italic,
  'cb': CommentStyle.box,
  'comment_box': CommentStyle.box,
};

/// Short forms of section directives.
const shortSectionStarts = {
  'sov': 'verse',
  'soc': 'chorus',
  'sob': 'bridge',
  'sot': 'tab',
  'sog': 'grid',
};
const shortSectionEnds = {
  'eov': 'verse',
  'eoc': 'chorus',
  'eob': 'bridge',
  'eot': 'tab',
  'eog': 'grid',
};

const sectionKindNames = {
  'verse': SectionKind.verse,
  'chorus': SectionKind.chorus,
  'bridge': SectionKind.bridge,
  'tab': SectionKind.tab,
  'grid': SectionKind.grid,
};

const delegateSectionNames = {
  'abc': DelegateType.abc,
  'ly': DelegateType.ly,
  'svg': DelegateType.svg,
  'textblock': DelegateType.textblock,
};

/// Font/size/colour directives: name → (target, property).
final Map<String, (FormatTarget, FormatProperty)> formatDirectives = {
  for (final target in FormatTarget.values) ...{
    '${target.name}font': (target, FormatProperty.font),
    '${target.name}size': (target, FormatProperty.size),
    '${target.name}colour': (target, FormatProperty.colour),
    '${target.name}color': (target, FormatProperty.colour),
  },
  'cf': (FormatTarget.chord, FormatProperty.font),
  'cs': (FormatTarget.chord, FormatProperty.size),
  'tf': (FormatTarget.text, FormatProperty.font),
  'ts': (FormatTarget.text, FormatProperty.size),
};
