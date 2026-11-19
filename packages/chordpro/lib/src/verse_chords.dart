import 'parser.dart' show copySourceLine;
import 'section_heading.dart';
import 'song.dart';

/// [song] with chords in its first verse only (#518, a personal adjustment,
/// ADR-0006): verses often share their chords, so later verses show the
/// lyrics alone, which saves room on small screens.
///
/// Verses are the sections with the verse role (ADR-0033): `{start_of_verse}`
/// or a name such as `Verse 2` or `Strophe 2`. In every verse after the
/// first, lyric lines lose their chords and lines that hold only chords are
/// left out; everything else is kept. Lines and sections keep their source
/// lines, so freehand annotations stay anchored (ADR-0032). Returns [song]
/// itself when it has fewer than two verses.
Song firstVerseChordsOnly(Song song) {
  final verses = song.sections.where(_isVerse).toList();
  if (verses.length < 2) return song;
  // Parts of the first verse split by breaks are the same section.
  final first = verses.first;
  var changed = false;
  final elements = <SongElement>[
    for (final e in song.elements)
      if (e is Section && _isVerse(e) && !identical(e, first))
        _withoutChords(e, () => changed = true)
      else
        e,
  ];
  if (!changed) return song;
  return Song(
    meta: song.meta,
    elements: elements,
    definitions: song.definitions,
    columns: song.columns,
    diagrams: song.diagrams,
    leadingTranspose: song.leadingTranspose,
  );
}

bool _isVerse(Section s) => s.role == SectionRole.verse;

Section _withoutChords(Section section, void Function() onChange) {
  if (!section.lines.any((l) => l is LyricLine && l.hasChords)) return section;
  onChange();
  final lines = <Line>[];
  for (final line in section.lines) {
    if (line is! LyricLine || !line.hasChords) {
      lines.add(line);
      continue;
    }
    // A line of chords only (an instrumental bar) has nothing left to show.
    if (line.plainText.trim().isEmpty) continue;
    final plain = LyricLine([Segment(text: line.text)]);
    copySourceLine(line, plain);
    lines.add(plain);
  }
  final copy = Section(
    kind: section.kind,
    label: section.label,
    name: section.name,
    attributes: section.attributes,
    gridShape: section.gridShape,
    lines: lines,
  );
  copySourceLine(section, copy);
  return copy;
}
