import 'section_heading.dart';
import 'song.dart';

/// [song] without the choruses that repeat an earlier one word for word
/// (#955, a personal adjustment, ADR-0006): sources such as SongSelect write
/// the chorus out every time it is sung, which musicians who know the song
/// do not need to read twice.
///
/// Choruses are the sections with the chorus role (ADR-0033):
/// `{start_of_chorus}` or a heading such as `{comment: Chorus}`. A chorus
/// is left out when an earlier chorus has the same lines (lyrics, chords and
/// everything else, leading and trailing empty lines aside), wherever it
/// is in the song; its label does not matter. `{chorus}` recalls are not
/// sections and stay (they follow the *repeated chorus* setting). Applied
/// after the sequence, so a chorus the sequence leaves out does not hide a
/// later one. Returns [song] itself when nothing is left out.
Song withoutRepeatedChoruses(Song song) {
  final seen = <String>{};
  var changed = false;
  final elements = <SongElement>[];
  for (final e in song.elements) {
    if (e is Section && e.role == SectionRole.chorus) {
      final key = _contentKey(e);
      if (key.isNotEmpty && !seen.add(key)) {
        changed = true;
        continue;
      }
    }
    elements.add(e);
  }
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

/// The lines of [section] as one string, empty for a section without
/// content.
String _contentKey(Section section) {
  final lines = [for (final l in section.lines) _lineKey(l)];
  while (lines.isNotEmpty && lines.first == _empty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last == _empty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

const _empty = 'E';

String _lineKey(Line line) => switch (line) {
  LyricLine(:final segments)
      when segments.every((s) => s.chord == null && s.text.trim().isEmpty) =>
    _empty,
  LyricLine(:final segments) =>
    'L${[for (final s in segments) '${s.chord?.raw ?? ''}\u0000${s.text}'].join('\u0001').trimRight()}',
  StackedLine() => 'S${identityHashCode(line)}',
  CommentLine(:final text, :final style) => 'C${style.name}\u0000$text',
  RawLine(:final text) => 'R${text.trimRight()}',
  GridLine() => 'G${identityHashCode(line)}',
  EmptyLine() => _empty,
  ImageLine(:final attributes) =>
    'I${(attributes.entries.map((a) => '${a.key}=${a.value}').toList()..sort()).join(',')}',
  ChordDiagramLine() => 'D${identityHashCode(line)}',
  BreakLine(:final kind) => 'B${kind.name}',
  FormatLine(:final target, :final property, :final value) =>
    'F${target.name}${property.name}$value',
};
