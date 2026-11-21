/// ChordPro parsing, transposition and chord formatting for setDING.
///
/// Pure Dart, no Flutter dependency (see ADR-0002, ADR-0003, ADR-0012).
library;

export 'src/abc.dart';
export 'src/auto_close.dart';
export 'src/brackets.dart';
export 'src/ccli_grid.dart';
export 'src/chord.dart';
export 'src/chord_tones.dart';
export 'src/chords_over_lyrics.dart';
export 'src/completion.dart';
export 'src/diagrams.dart';
export 'src/editing.dart';
export 'src/fingering.dart';
export 'src/directive.dart' show SelectorContext;
export 'src/format.dart';
export 'src/formatter.dart';
export 'src/grid.dart';
export 'src/lilypond.dart';
export 'src/highlight.dart';
export 'src/links.dart';
export 'src/markup.dart';
export 'src/metadata.dart';
export 'src/meter.dart';
export 'src/notation.dart';
export 'src/parser.dart' hide copySourceLine;
export 'src/section_labels.dart';
export 'src/section_heading.dart'
    show SectionRole, sectionRoleOf, sectionRoleOfName;
export 'src/sequence.dart';
export 'src/song.dart';
export 'src/songselect.dart';
export 'src/stacked_verses.dart';
export 'src/source_metadata.dart';
export 'src/source_sections.dart';
export 'src/validation.dart';
export 'src/verse_chords.dart';
