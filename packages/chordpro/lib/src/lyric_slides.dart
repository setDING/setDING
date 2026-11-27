/// Lyrics without chords as slides for projection (ADR-0068): the
/// sections of a song in the order the band plays them, cut into slides
/// of a few lines, optionally paired with a second language version.
library;

import 'sequence.dart';
import 'song.dart';

/// One section of a song's lyrics as projected: chord-free lines of a
/// verse, chorus, bridge or other section, in played order.
class LyricSection {
  const LyricSection({
    required this.section,
    required this.lines,
    this.code,
    this.label,
    this.repeat,
  });

  /// The section of the song the lines come from (several entries share
  /// it when the sequence plays it more than once).
  final Section section;

  /// The lyrics without chords and markup. An empty string is a paragraph
  /// break; there is none at the start or end and never two in a row.
  final List<String> lines;

  /// The part's short code (`V1`, `C`, `Coda`); null for a section that is
  /// no part (no label, plain lyrics).
  final String? code;

  /// The first line of the section's label (`Verse 1`), if it has one.
  final String? label;

  /// Repetitions of the sequence item (`C x2` → 2); not expanded.
  final int? repeat;

  /// The number of lines with text (paragraph breaks not counted).
  int get textLines => lines.where((l) => l.isNotEmpty).length;
}

/// The lyrics of [song] in the order the band plays it (ADR-0068 §5).
///
/// With a [sequence] (the band arrangement's or `{x_sequence}`) that
/// matches the song's parts, its items in order (see [sequenceParts]), so a
/// recalled chorus appears again; repetitions are kept on
/// [LyricSection.repeat], not expanded. Otherwise every section in document
/// order, a chorus recall repeating the chorus.
///
/// Only lyrics are kept: chords, comments, tabs, grids, images, chord
/// diagrams and delegated environments are left out, and so is a section
/// without any lyrics (an intro with chords only).
List<LyricSection> lyricSections(
  Song song, {
  List<SequenceItem> sequence = const [],
}) {
  final played =
      sequenceParts(song, sequence) ??
      _documentOrder(song, playedParts(song, const []));
  return [
    for (final (:part, :section) in played)
      if (section != null) ?_lyricSection(section, part),
  ];
}

/// Every section of [song] in document order with its part from [parts]
/// (null for a section that is no part), a chorus recall repeating the
/// chorus.
List<({SequenceItem? part, Section? section})> _documentOrder(
  Song song,
  List<({SequenceItem part, Section? section})> parts,
) {
  final partOf = {
    for (final p in parts)
      if (p.section != null) p.section!: p.part,
  };
  final result = <({SequenceItem? part, Section? section})>[];
  Section? lastChorus;
  for (final element in song.elements) {
    if (element is Section) {
      if (element.kind == SectionKind.chorus) lastChorus = element;
      result.add((part: partOf[element], section: element));
    } else if (element is ChorusRecall) {
      final chorus = element.chorus ?? lastChorus;
      result.add((
        part: chorus == null ? null : partOf[chorus],
        section: chorus,
      ));
    }
  }
  return result;
}

LyricSection? _lyricSection(Section section, SequenceItem? part) {
  if (section.kind == SectionKind.tab || section.kind == SectionKind.grid) {
    return null;
  }
  final lines = <String>[];
  for (final line in section.lines) {
    if (line is LyricLine) {
      final text = line.plainText.trim();
      if (text.isNotEmpty) lines.add(text);
    } else if (line is EmptyLine && lines.isNotEmpty && lines.last.isNotEmpty) {
      lines.add('');
    }
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return null;
  final label = section.label?.split('\n').first.trim();
  return LyricSection(
    section: section,
    lines: lines,
    code: part?.code,
    label: label == null || label.isEmpty ? null : label,
    repeat: part?.repeat,
  );
}

/// One slide of the projection: a part of a [LyricSection], with the
/// matching part of a second language version when there is one.
class LyricSlide {
  const LyricSlide({
    required this.index,
    required this.source,
    required this.page,
    required this.pages,
    required this.lines,
    this.secondSource,
    this.second,
  });

  /// Position of [source] in the list of sections (0-based).
  final int index;

  /// The section this slide is part of.
  final LyricSection source;

  /// Which slide of its section this is (0-based) and how many it has.
  final int page;
  final int pages;

  /// The lines of this slide (`''` = paragraph break, never at an edge).
  final List<String> lines;

  /// The section of the second language paired with [source], if any.
  final LyricSection? secondSource;

  /// The lines of the second language on this slide; null without one.
  final List<String>? second;
}

/// Cuts [sections] into slides of at most [linesPerSlide] lines of text
/// (ADR-0068 §5): a longer section is split into the fewest slides that
/// fit, of about equal length (the first ones one line longer).
///
/// With [second] (the sections of a linked language version, ADR-0068 §9)
/// the sections are paired by their position: section `i` with section `i`
/// of [second]. A pair is split into the same number of slides, enough for
/// the longer one; a section without a partner shows its language alone,
/// and sections of [second] beyond the end of [sections] are left out.
List<LyricSlide> lyricSlides(
  List<LyricSection> sections, {
  int linesPerSlide = 8,
  List<LyricSection>? second,
}) {
  final max = linesPerSlide < 1 ? 1 : linesPerSlide;
  int slidesFor(LyricSection s) => (s.textLines + max - 1) ~/ max;
  final slides = <LyricSlide>[];
  for (var i = 0; i < sections.length; i++) {
    final source = sections[i];
    final partner = second != null && i < second.length ? second[i] : null;
    var pages = slidesFor(source);
    if (partner != null && slidesFor(partner) > pages) {
      pages = slidesFor(partner);
    }
    final own = _split(source.lines, pages);
    final other = partner == null ? null : _split(partner.lines, pages);
    for (var page = 0; page < pages; page++) {
      slides.add(
        LyricSlide(
          index: i,
          source: source,
          page: page,
          pages: pages,
          lines: own[page],
          secondSource: partner,
          second: other?[page],
        ),
      );
    }
  }
  return slides;
}

/// [lines] in [count] chunks with about the same number of text lines
/// each (the first ones one more); paragraph breaks at a chunk's edge are
/// dropped. A chunk is empty when there are fewer text lines than chunks.
List<List<String>> _split(List<String> lines, int count) {
  final text = lines.where((l) => l.isNotEmpty).length;
  final chunks = <List<String>>[];
  var at = 0;
  for (var c = 0; c < count; c++) {
    final size = text ~/ count + (c < text % count ? 1 : 0);
    final chunk = <String>[];
    var taken = 0;
    while (at < lines.length && taken < size) {
      final line = lines[at++];
      if (line.isEmpty) {
        if (chunk.isNotEmpty) chunk.add(line);
      } else {
        chunk.add(line);
        taken++;
      }
    }
    chunks.add(chunk);
  }
  return chunks;
}
