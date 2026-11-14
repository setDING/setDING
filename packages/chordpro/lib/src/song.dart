/// Abstract syntax tree of a parsed ChordPro song.
library;

import 'chord.dart';

/// Kind of a song section.
enum SectionKind { none, verse, chorus, bridge, tab, grid, custom }

/// A parsed ChordPro song.
class Song {
  Song({required this.meta, required this.elements});

  /// Meta data by directive name (lower case), e.g. `title`, `artist`, `key`.
  final Map<String, List<String>> meta;

  /// Sections and chorus recalls in document order.
  final List<SongElement> elements;

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

  int? get tempo {
    final value = metaValue('tempo');
    return value == null ? null : int.tryParse(value.trim());
  }

  Key? get key {
    final name = keyName;
    return name == null ? null : Key.tryParse(name);
  }

  /// All sections, including the implicit ones.
  Iterable<Section> get sections => elements.whereType<Section>();

  /// Whether the song has any lyrics, chords or comments to display.
  bool get hasContent => sections.any((s) => s.lines.isNotEmpty);
}

/// Top-level element of a song.
sealed class SongElement {
  const SongElement();
}

/// A section such as a verse or chorus.
class Section extends SongElement {
  Section({required this.kind, this.label, List<Line>? lines})
    : lines = lines ?? [];

  final SectionKind kind;

  /// Explicit label, e.g. "Verse 1". Null if none was given.
  final String? label;

  final List<Line> lines;

  /// Whether lines are preformatted (tab, grid).
  bool get isPreformatted =>
      kind == SectionKind.tab || kind == SectionKind.grid;
}

/// `{chorus}` – repeats the most recent chorus.
class ChorusRecall extends SongElement {
  const ChorusRecall({this.label, this.chorus});

  final String? label;

  /// The chorus being recalled, if one was defined before.
  final Section? chorus;
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

  /// The lyrics without chords.
  String get text => segments.map((s) => s.text).join();
}

/// A piece of lyrics preceded by an optional chord.
class Segment {
  const Segment({this.chord, this.text = ''});

  final ChordToken? chord;
  final String text;
}

/// A chord as written in the source, parsed if possible.
class ChordToken {
  ChordToken(this.raw) : chord = Chord.tryParse(raw);

  /// Text between the brackets.
  final String raw;

  /// Parsed chord, or null for annotations like `N.C.` or `*Riff`.
  final Chord? chord;

  /// Annotations (`[*text]`) are displayed as written.
  bool get isAnnotation => raw.startsWith('*');

  String get annotationText => isAnnotation ? raw.substring(1) : raw;
}

/// Comment style.
enum CommentStyle { normal, italic, box }

/// `{comment: …}` and variants.
class CommentLine extends Line {
  const CommentLine(this.text, {this.style = CommentStyle.normal});

  final String text;
  final CommentStyle style;
}

/// A preformatted line in a tab or grid section.
class RawLine extends Line {
  const RawLine(this.text);

  final String text;
}

/// An empty line (paragraph break).
class EmptyLine extends Line {
  const EmptyLine();
}
