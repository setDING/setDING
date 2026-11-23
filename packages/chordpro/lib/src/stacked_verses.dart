import 'parser.dart' show copySourceLine;
import 'section_heading.dart';
import 'song.dart';

/// [song] with verses that share their chords stacked line by line (#521,
/// a personal adjustment, ADR-0006), the way hymnals print them: each line
/// of chords once, below it the matching line of every verse.
///
/// Verses are the sections with the verse role (ADR-0033). Consecutive
/// verses form a group with the first one, which has chords, when they have
/// the same lines (lyrics and empty lines) with the same chords, line by
/// line; a verse without any chords joins when its lines match the lyric
/// lines of the first one. Other sections in between stay where they are.
/// The group is shown in place of its first verse as one section of
/// [StackedLine]s; the later verses of the group are left out. A verse with
/// the same text as an earlier one of its group adds no row (#953). Lines
/// of chords only stay single lines. Verses with other content (comments,
/// tabs, images …) are never stacked.
///
/// The rows keep their verses' lines with their source lines, so freehand
/// annotations stay anchored to them (ADR-0032). Returns [song] itself when no verses can be stacked.
Song stackVerses(Song song) => stackSections(song, SectionRole.verse);

/// [song] with its choruses stacked like the verses of [stackVerses]
/// (#953): choruses whose lyrics change, e.g. a last chorus with other
/// words. Repeats with the same text (and `{chorus}` recalls) add no row,
/// so a song whose choruses are all the same stays as it is.
Song stackChoruses(Song song) => stackSections(song, SectionRole.chorus);

/// [song] with the sections of [role] stacked as [stackVerses] describes
/// for verses.
Song stackSections(Song song, SectionRole role) {
  final verses = <Section>[];
  for (final s in song.sections) {
    if (s.role == role && !verses.any((v) => identical(v, s))) {
      verses.add(s);
    }
  }
  if (verses.length < 2) return song;

  // Groups of consecutive sections, keyed by their first one.
  final groups = <List<(int, Section)>>[];
  final repeats = <Section, List<(int, Section)>>{};
  List<(int, Section)>? current;
  _Shape? shape;
  for (final (i, verse) in verses.indexed) {
    final number = _verseNumber(verse) ?? i + 1;
    if (current != null && shape!.matches(verse)) {
      // The same text as an earlier section of the group adds no row.
      if (current.any((e) => _sameText(e.$2, verse))) {
        repeats[verse] = current;
      } else {
        current.add((number, verse));
      }
      continue;
    }
    current = null;
    shape = _Shape.of(verse);
    if (shape != null) {
      current = [(number, verse)];
      groups.add(current);
    }
  }
  groups.removeWhere((g) => g.length < 2);
  if (groups.isEmpty) return song;

  final stacked = <Section, Section>{};
  final dropped = <Section>{};
  for (final group in groups) {
    stacked[group.first.$2] = _stack(group);
    dropped.addAll(group.skip(1).map((e) => e.$2));
  }
  // Repeats of a stacked group are left out with it.
  for (final MapEntry(key: repeat, value: group) in repeats.entries) {
    if (groups.any((g) => identical(g, group))) dropped.add(repeat);
  }
  final elements = <SongElement>[
    for (final e in song.elements)
      if (e is Section && stacked.containsKey(e))
        stacked[e]!
      else if (e is! Section || !dropped.contains(e))
        e,
  ];
  return Song(
    meta: song.meta,
    elements: elements,
    definitions: song.definitions,
    columns: song.columns,
    diagrams: song.diagrams,
    leadingTranspose: song.leadingTranspose,
  );
}

/// Whether [a] and [b] have the same lyrics line by line.
bool _sameText(Section a, Section b) {
  final la = [
    for (final l in a.lines)
      if (l is LyricLine) l.plainText.trim(),
  ];
  final lb = [
    for (final l in b.lines)
      if (l is LyricLine) l.plainText.trim(),
  ];
  if (la.length != lb.length) return false;
  for (var i = 0; i < la.length; i++) {
    if (la[i] != lb[i]) return false;
  }
  return true;
}

/// The lines of a verse that can lead a group: lyrics and empty lines only,
/// with chords somewhere.
class _Shape {
  _Shape(this.lines);

  final List<Line> lines;

  static _Shape? of(Section verse) {
    if (!verse.lines.every((l) => l is LyricLine || l is EmptyLine)) {
      return null;
    }
    if (!verse.lines.any((l) => l is LyricLine && l.hasChords)) return null;
    return _Shape(verse.lines);
  }

  /// The lyric and empty lines of the group's first verse, without lines of
  /// chords only: what a verse without chords must match.
  late final List<Line> _lyricLines = [
    for (final l in lines)
      if (l is! LyricLine || !_chordsOnly(l)) l,
  ];

  bool matches(Section verse) {
    final other = verse.lines;
    if (!other.every((l) => l is LyricLine || l is EmptyLine)) return false;
    final chorded = other.any((l) => l is LyricLine && l.hasChords);
    final expected = chorded ? lines : _lyricLines;
    if (other.length != expected.length) return false;
    for (var i = 0; i < other.length; i++) {
      final a = expected[i], b = other[i];
      if (a is EmptyLine || b is EmptyLine) {
        if (a.runtimeType != b.runtimeType) return false;
        continue;
      }
      final la = a as LyricLine, lb = b as LyricLine;
      if (!chorded) continue;
      if (_chordsOnly(la) != _chordsOnly(lb)) return false;
      if (!_sameChords(la, lb)) return false;
    }
    return true;
  }
}

bool _chordsOnly(LyricLine l) => l.hasChords && l.plainText.trim().isEmpty;

bool _sameChords(LyricLine a, LyricLine b) {
  final ca = [for (final s in a.segments) ?s.chord?.raw];
  final cb = [for (final s in b.segments) ?s.chord?.raw];
  if (ca.length != cb.length) return false;
  for (var i = 0; i < ca.length; i++) {
    if (ca[i] != cb[i]) return false;
  }
  return true;
}

/// The number at the end of a verse's label (`Verse 2`), if any.
int? _verseNumber(Section verse) {
  final match = _trailingNumber.firstMatch(verse.label ?? '');
  return match == null ? null : int.tryParse(match.group(2)!);
}

final _trailingNumber = RegExp(r'^(.*?)(\d+)\s*$');

/// The label of a group: `Verse 1–3` when the first and last verse are
/// numbered, otherwise the first verse's label.
String? _groupLabel(List<(int, Section)> group) {
  final first = group.first.$2.label;
  final firstMatch = _trailingNumber.firstMatch(first ?? '');
  final lastMatch = _trailingNumber.firstMatch(group.last.$2.label ?? '');
  if (firstMatch == null || lastMatch == null) return first;
  if (firstMatch.group(1) != lastMatch.group(1)) return first;
  return '${firstMatch.group(1)}${firstMatch.group(2)}–${lastMatch.group(2)}';
}

Section _stack(List<(int, Section)> group) {
  final leader = group.first.$2;
  // Each verse's lines without lines of chords only when it has no chords.
  final verseLines = [
    for (final (_, verse) in group)
      verse.lines.any((l) => l is LyricLine && l.hasChords)
          ? verse.lines
          : null,
  ];
  final lines = <Line>[];
  var plainIndex = 0;
  for (final (i, line) in leader.lines.indexed) {
    if (line is! LyricLine || _chordsOnly(line)) {
      // Empty lines and lines of chords only (an instrumental bar) once.
      lines.add(line);
      if (line is EmptyLine) plainIndex++;
      continue;
    }
    final columns = _columns(line);
    final rows = <StackedRow>[];
    for (final (g, (number, _)) in group.indexed) {
      final own = verseLines[g];
      final verseLine =
          (own == null ? group[g].$2.lines[plainIndex] : own[i]) as LyricLine;
      rows.add(
        StackedRow(
          number,
          verseLine,
          own == null ? null : [for (final c in _columns(verseLine)) c.text],
        ),
      );
    }
    // No source line of its own: each row is marked as its verse's line.
    lines.add(StackedLine([for (final c in columns) c.chord], rows));
    plainIndex++;
  }
  final section = Section(
    kind: leader.kind,
    label: _groupLabel(group),
    name: leader.name,
    attributes: leader.attributes,
    gridShape: leader.gridShape,
    lines: lines,
  );
  copySourceLine(leader, section);
  return section;
}

/// The columns of [line]: the text before the first chord (chord null),
/// then each chord with the text up to the next one.
List<Segment> _columns(LyricLine line) {
  final columns = <Segment>[const Segment()];
  for (final s in line.segments) {
    if (s.chord == null) {
      final last = columns.removeLast();
      columns.add(Segment(chord: last.chord, text: last.text + s.text));
    } else {
      columns.add(s);
    }
  }
  return columns;
}
