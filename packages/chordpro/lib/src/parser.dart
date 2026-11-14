/// ChordPro parser (subset of ChordPro 6, see ADR-0003).
library;

import 'song.dart';

const _metaAliases = {
  't': 'title',
  'st': 'subtitle',
  'title': 'title',
  'subtitle': 'subtitle',
  'artist': 'artist',
  'composer': 'composer',
  'lyricist': 'lyricist',
  'album': 'album',
  'year': 'year',
  'key': 'key',
  'tempo': 'tempo',
  'time': 'time',
  'capo': 'capo',
  'duration': 'duration',
  'copyright': 'copyright',
};

const _commentAliases = {
  'c': CommentStyle.normal,
  'comment': CommentStyle.normal,
  'highlight': CommentStyle.normal,
  'ci': CommentStyle.italic,
  'comment_italic': CommentStyle.italic,
  'cb': CommentStyle.box,
  'comment_box': CommentStyle.box,
};

const _sectionStart = {
  'sov': SectionKind.verse,
  'start_of_verse': SectionKind.verse,
  'soc': SectionKind.chorus,
  'start_of_chorus': SectionKind.chorus,
  'sob': SectionKind.bridge,
  'start_of_bridge': SectionKind.bridge,
  'sot': SectionKind.tab,
  'start_of_tab': SectionKind.tab,
  'sog': SectionKind.grid,
  'start_of_grid': SectionKind.grid,
};

const _sectionEnd = {
  'eov',
  'end_of_verse',
  'eoc',
  'end_of_chorus',
  'eob',
  'end_of_bridge',
  'eot',
  'end_of_tab',
  'eog',
  'end_of_grid',
};

final _directive = RegExp(
  r'^\{\s*([A-Za-z_][\w-]*)\s*(?:[:\s]\s*(.*?))?\s*\}$',
);
final _labelAttr = RegExp(r'''^label\s*=\s*["'](.*)["']$''');

/// Parses ChordPro [source] into a [Song].
///
/// The parser is lenient: unknown directives are ignored (the source text
/// itself is never modified), unclosed sections are closed implicitly.
Song parseChordPro(String source) {
  final meta = <String, List<String>>{};
  final elements = <SongElement>[];
  Section? current;
  Section? lastChorus;
  var explicitSection = false;

  Section ensureSection() {
    if (current == null) {
      current = Section(kind: SectionKind.none);
      elements.add(current!);
      explicitSection = false;
    }
    return current!;
  }

  void closeSection() {
    final section = current;
    if (section != null) {
      _trimEmptyLines(section.lines);
      if (section.kind == SectionKind.chorus) lastChorus = section;
      if (section.lines.isEmpty && section.label == null && !explicitSection) {
        elements.remove(section);
      }
    }
    current = null;
    explicitSection = false;
  }

  final lines = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();

    if (trimmed.startsWith('#')) continue;

    final match = _directive.firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)!.toLowerCase();
      final value = match.group(2)?.trim() ?? '';

      if (_metaAliases.containsKey(name)) {
        meta.putIfAbsent(_metaAliases[name]!, () => []).add(value);
        continue;
      }
      if (name == 'meta') {
        final space = value.indexOf(RegExp(r'\s'));
        if (space > 0) {
          final key = value.substring(0, space).toLowerCase();
          meta.putIfAbsent(key, () => []).add(value.substring(space).trim());
        }
        continue;
      }
      if (_commentAliases.containsKey(name)) {
        ensureSection().lines.add(
          CommentLine(value, style: _commentAliases[name]!),
        );
        continue;
      }
      if (_sectionStart.containsKey(name) || name.startsWith('start_of_')) {
        closeSection();
        final kind = _sectionStart[name] ?? SectionKind.custom;
        current = Section(kind: kind, label: _parseLabel(value));
        elements.add(current!);
        explicitSection = true;
        continue;
      }
      if (_sectionEnd.contains(name) || name.startsWith('end_of_')) {
        closeSection();
        continue;
      }
      if (name == 'chorus') {
        closeSection();
        elements.add(
          ChorusRecall(
            label: value.isEmpty ? null : _parseLabel(value),
            chorus: lastChorus,
          ),
        );
        continue;
      }
      // Unknown or layout directives (new_page, column_break, define, …)
      // are ignored for display.
      continue;
    }

    final section = current;
    if (section != null && section.isPreformatted) {
      section.lines.add(line.isEmpty ? const EmptyLine() : RawLine(line));
      continue;
    }

    if (trimmed.isEmpty) {
      // An empty line outside an explicit section separates implicit
      // paragraphs; inside a section it is kept as a spacer.
      if (section != null && !explicitSection) {
        closeSection();
      } else if (section != null) {
        section.lines.add(const EmptyLine());
      }
      continue;
    }

    ensureSection().lines.add(parseLyricLine(line));
  }
  closeSection();

  return Song(meta: meta, elements: elements);
}

/// Parses a single line with inline chords, e.g. `[G]Hello [C]world`.
LyricLine parseLyricLine(String line) {
  final segments = <Segment>[];
  var index = 0;
  ChordToken? pendingChord;
  final text = StringBuffer();

  void flush() {
    if (pendingChord != null || text.isNotEmpty) {
      segments.add(Segment(chord: pendingChord, text: text.toString()));
    }
    pendingChord = null;
    text.clear();
  }

  while (index < line.length) {
    final char = line[index];
    if (char == '[') {
      final end = line.indexOf(']', index + 1);
      if (end > index) {
        flush();
        pendingChord = ChordToken(line.substring(index + 1, end).trim());
        index = end + 1;
        continue;
      }
    }
    text.write(char);
    index++;
  }
  flush();
  return LyricLine(segments);
}

String? _parseLabel(String value) {
  if (value.isEmpty) return null;
  final attr = _labelAttr.firstMatch(value);
  if (attr != null) return attr.group(1);
  return value;
}

void _trimEmptyLines(List<Line> lines) {
  while (lines.isNotEmpty && lines.first is EmptyLine) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last is EmptyLine) {
    lines.removeLast();
  }
}
