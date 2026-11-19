/// Abstract syntax tree of a parsed ChordPro song.
library;

import 'chord.dart';
import 'diagrams.dart';
import 'grid.dart';
import 'links.dart';
import 'markup.dart';
import 'meter.dart';
import 'section_heading.dart';
import 'sequence.dart';

/// Kind of a song section.
enum SectionKind { none, verse, chorus, bridge, tab, grid, custom }

/// A parsed ChordPro song.
class Song {
  Song({
    required this.meta,
    required this.elements,
    this.definitions = const [],
    this.columns,
    this.diagrams,
    this.leadingTranspose = 0,
  });

  /// Meta data by name (lower case), e.g. `title`, `artist`, `key`.
  /// Every item can have several values.
  final Map<String, List<String>> meta;

  /// Sections, chorus recalls and delegated environments in document order.
  final List<SongElement> elements;

  /// Chord definitions from `{define}` (ADR-0012).
  final List<ChordDefinition> definitions;

  /// `{columns}`: requested number of columns, if any.
  final int? columns;

  /// `{diagrams}`: `on`, `off`, or a position (`bottom`, `top`, `right`,
  /// `below`). Null if not specified.
  final String? diagrams;

  /// `{transpose}` in effect where the song content starts; applies to the
  /// displayed key in the header.
  final int leadingTranspose;

  String? metaValue(String name) {
    final values = meta[name];
    return values == null || values.isEmpty ? null : values.first;
  }

  String? get title => metaValue('title');
  String? get subtitle => metaValue('subtitle');
  String? get artist => metaValue('artist');
  String? get keyName => metaValue('key');
  String? get capo => metaValue('capo');
  String? get time => metaValue('time');
  String? get duration => metaValue('duration');
  String? get sortTitle => metaValue('sorttitle');
  String? get sortArtist => metaValue('sortartist');
  List<String> get tags => meta['tag'] ?? const [];

  /// Song sequence from the custom directive `{x_sequence: …}`.
  List<SequenceItem> get sequence {
    final value = metaValue('x_sequence');
    return value == null ? const [] : parseSequence(value);
  }

  /// Grouping of an odd meter from the custom directive
  /// `{x_time_grouping: 2+2+3}` (ADR-0026).
  String? get timeGrouping => metaValue('x_time_grouping');

  /// Sources of the song from the custom directive `{x_link: URL | Label}`,
  /// in document order; values without a usable URL are skipped.
  List<SongLink> get links => [
    for (final value in meta['x_link'] ?? const <String>[])
      ?parseSongLink(value),
  ];

  /// The meter from `{time}` and `{x_time_grouping}`; 4/4 when `{time}` is
  /// missing or unreadable (ADR-0026).
  Meter get meter =>
      Meter.tryParse(time, grouping: timeGrouping) ?? Meter.common;

  int? get tempo {
    final value = metaValue('tempo');
    return value == null ? null : int.tryParse(value.trim());
  }

  /// Capo from `{capo}`: the chords are written as shapes for this fret.
  int get capoFret => int.tryParse(capo?.trim() ?? '') ?? 0;

  Key? get key {
    final name = keyName;
    return name == null ? null : Key.tryParse(name);
  }

  /// All sections, including the implicit ones.
  Iterable<Section> get sections => elements.whereType<Section>();

  /// Whether the song has any lyrics, chords or comments to display.
  bool get hasContent =>
      sections.any((s) => s.lines.isNotEmpty) ||
      elements.any((e) => e is DelegateSection);
}

/// Top-level element of a song.
sealed class SongElement {
  const SongElement();
}

/// A section such as a verse or chorus.
class Section extends SongElement {
  Section({
    required this.kind,
    this.label,
    this.name,
    this.attributes = const {},
    this.gridShape,
    List<Line>? lines,
  }) : lines = lines ?? [];

  final SectionKind kind;

  /// Explicit label, e.g. "Verse 1". Null if none was given.
  final String? label;

  /// Environment name, e.g. `verse` or `outro` for `{start_of_outro}`.
  final String? name;

  /// Attributes of the start directive.
  final Map<String, String> attributes;

  /// Shape of a grid section.
  final GridShape? gridShape;

  final List<Line> lines;

  /// Whether lines are preformatted (tab).
  bool get isPreformatted => kind == SectionKind.tab;

  /// Musical role, derived from the name (ADR-0033).
  SectionRole get role => sectionRoleOf(this);
}

/// `{chorus}` – repeats the most recent chorus.
class ChorusRecall extends SongElement {
  const ChorusRecall({this.label, this.chorus});

  final String? label;

  /// The chorus being recalled, if one was defined before.
  final Section? chorus;
}

/// Type of a delegated environment.
enum DelegateType { abc, ly, svg, textblock }

/// A delegated environment (`{start_of_abc}` …), rendered by other means
/// than lyrics and chords.
class DelegateSection extends SongElement {
  DelegateSection({
    required this.type,
    this.label,
    this.attributes = const {},
    List<String>? lines,
  }) : lines = lines ?? [];

  final DelegateType type;
  final String? label;
  final Map<String, String> attributes;

  /// The raw content lines.
  final List<String> lines;

  String get content => lines.join('\n');
}

/// A line inside a section.
sealed class Line {
  const Line();
}

/// A line of lyrics with inline chords.
class LyricLine extends Line {
  const LyricLine(this.segments);

  final List<Segment> segments;

  bool get hasChords => segments.any((s) => s.chord != null);

  /// The lyrics without chords (markup included, see [plainText]).
  String get text => segments.map((s) => s.text).join();

  /// The lyrics without chords and without markup.
  String get plainText => stripMarkup(text);
}

/// The matching lines of several verses that share their chords, stacked
/// (#521, see `stackVerses`): the chords once, then one row per verse
/// with its words under the same chords. Never parsed from ChordPro; built
/// for a person's display only.
class StackedLine extends Line {
  StackedLine(this.chords, this.rows);

  /// The chord of each column; null for the text before the first chord.
  final List<ChordToken?> chords;

  /// One row per verse, in verse order.
  final List<StackedRow> rows;
}

/// A verse's line in a [StackedLine].
class StackedRow {
  const StackedRow(this.verse, this.line, this.cells);

  /// Number of the verse in the song (1 = first verse).
  final int verse;

  /// The verse's own line (for its source line and text).
  final LyricLine line;

  /// The text under each chord of [StackedLine.chords] (markup included);
  /// null for a verse without chords, whose text stays in one piece.
  final List<String>? cells;
}

/// A piece of lyrics preceded by an optional chord.
class Segment {
  const Segment({this.chord, this.text = ''});

  final ChordToken? chord;
  final String text;
}

/// A chord as written in the source, parsed if possible.
class ChordToken {
  ChordToken(this.raw, {this.transpose = 0, this.preferFlats, this.key})
    : parenthesized = _optional.hasMatch(stripMarkup(raw)),
      chord = Chord.tryParse(
        _optional.firstMatch(stripMarkup(raw))?.group(1) ?? stripMarkup(raw),
      );

  static final _optional = RegExp(r'^\((.+)\)$');

  /// Text between the brackets.
  final String raw;

  /// Parsed chord, or null for annotations like `N.C.` or `*Riff`.
  final Chord? chord;

  /// Optional chord written in parentheses, e.g. `[(Bb/D)]` (SongSelect).
  final bool parenthesized;

  /// `{transpose}` in effect where the chord appears (semitones).
  final int transpose;

  /// Accidentals requested by `{transpose}`: true = flats, false = sharps.
  final bool? preferFlats;

  /// `{key}` in effect where the chord appears (as written).
  final Key? key;

  /// Annotations (`[*text]`) are displayed as written.
  bool get isAnnotation => raw.startsWith('*');

  String get annotationText => isAnnotation ? raw.substring(1) : raw;
}

/// Comment style.
enum CommentStyle { normal, italic, box }

/// `{comment: …}` and variants. Metadata references are already substituted.
class CommentLine extends Line {
  const CommentLine(this.text, {this.style = CommentStyle.normal});

  final String text;
  final CommentStyle style;
}

/// A preformatted line in a tab section.
class RawLine extends Line {
  const RawLine(this.text);

  final String text;
}

/// A line in a grid section.
class GridLine extends Line {
  const GridLine(this.row);

  final GridRow row;
}

/// An empty line (paragraph break).
class EmptyLine extends Line {
  const EmptyLine();
}

/// `{image: …}`.
class ImageLine extends Line {
  const ImageLine(this.attributes);

  /// Attributes; the file name is in `src`.
  final Map<String, String> attributes;

  String? get src => attributes['src'];
}

/// `{chord: …}`: shows a chord diagram at this position.
class ChordDiagramLine extends Line {
  const ChordDiagramLine(this.definition);

  final ChordDefinition definition;
}

/// Kind of break requested by an output directive.
enum BreakKind { column, page }

/// `{column_break}`, `{new_page}`, `{new_physical_page}`.
class BreakLine extends Line {
  const BreakLine(this.kind);

  final BreakKind kind;
}

/// Items whose appearance can be changed by font/size/colour directives.
enum FormatTarget { text, chord, chorus, label, tab, grid, title, footer, toc }

/// Property changed by a font/size/colour directive.
enum FormatProperty { font, size, colour }

/// `{textfont: …}`, `{chordsize: …}`, `{textcolour: …}` and friends.
/// A null value restores the previous/default value.
class FormatLine extends Line {
  const FormatLine(this.target, this.property, this.value);

  final FormatTarget target;
  final FormatProperty property;
  final String? value;
}
