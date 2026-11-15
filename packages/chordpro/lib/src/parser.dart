/// ChordPro parser for the whole ChordPro 6 specification (ADR-0003,
/// ADR-0012).
library;

import 'chord.dart';
import 'diagrams.dart';
import 'directive.dart';
import 'grid.dart';
import 'metadata.dart';
import 'song.dart';

/// Directive names (long and short) of meta-data items.
const _metaAliases = {
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

const _commentAliases = {
  'c': CommentStyle.normal,
  'comment': CommentStyle.normal,
  'highlight': CommentStyle.normal,
  'ci': CommentStyle.italic,
  'comment_italic': CommentStyle.italic,
  'cb': CommentStyle.box,
  'comment_box': CommentStyle.box,
};

/// Short forms of section directives.
const _shortStart = {
  'sov': 'verse',
  'soc': 'chorus',
  'sob': 'bridge',
  'sot': 'tab',
  'sog': 'grid',
};
const _shortEnd = {
  'eov': 'verse',
  'eoc': 'chorus',
  'eob': 'bridge',
  'eot': 'tab',
  'eog': 'grid',
};

const _sectionKinds = {
  'verse': SectionKind.verse,
  'chorus': SectionKind.chorus,
  'bridge': SectionKind.bridge,
  'tab': SectionKind.tab,
  'grid': SectionKind.grid,
};

const _delegates = {
  'abc': DelegateType.abc,
  'ly': DelegateType.ly,
  'svg': DelegateType.svg,
  'textblock': DelegateType.textblock,
};

/// Font/size/colour directives: name → (target, property).
final Map<String, (FormatTarget, FormatProperty)> _formatDirectives = {
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

/// Parses ChordPro [source] into a [Song] (the first song if the file
/// contains several, see [parseChordProSongs]).
Song parseChordPro(
  String source, {
  SelectorContext selectors = const SelectorContext(),
}) => parseChordProSongs(source, selectors: selectors).first;

/// Splits ChordPro [source] at `{new_song}` / `{ns}` into the source texts
/// of the individual songs (ADR-0012). Parts without content are dropped.
List<String> splitChordProSongs(String source) {
  final parts = <String>[];
  final current = <String>[];
  void flush() {
    final text = current.join('\n').trim();
    if (text.isNotEmpty) parts.add('$text\n');
    current.clear();
  }

  for (final line in source.replaceAll('\r\n', '\n').split('\n')) {
    final d = line.trimLeft().startsWith('{') ? parseDirective(line) : null;
    if (d != null && (d.name == 'new_song' || d.name == 'ns')) {
      flush();
    } else {
      current.add(line);
    }
  }
  flush();
  return parts;
}

/// Parses ChordPro [source] that may contain several songs separated by
/// `{new_song}` / `{ns}`.
///
/// The parser is lenient: unknown directives are ignored (the source text
/// itself is never modified), unclosed sections are closed implicitly.
/// [selectors] decides conditional directives such as `{comment-alto: …}`.
List<Song> parseChordProSongs(
  String source, {
  SelectorContext selectors = const SelectorContext(),
}) {
  final songs = <Song>[];
  final lines = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  var parser = _SongParser(selectors);
  for (final line in lines) {
    final d = line.trimLeft().startsWith('{') ? parseDirective(line) : null;
    if (d != null && (d.name == 'new_song' || d.name == 'ns')) {
      if (parser.hasAnything) songs.add(parser.finish());
      parser = _SongParser(selectors);
      continue;
    }
    parser.addLine(line);
  }
  if (parser.hasAnything || songs.isEmpty) songs.add(parser.finish());
  return songs;
}

class _SongParser {
  _SongParser(this.selectors);

  final SelectorContext selectors;
  final meta = <String, List<String>>{};
  final elements = <SongElement>[];
  final definitions = <ChordDefinition>[];
  int? columns;
  String? diagrams;

  Section? current;
  bool explicitSection = false;
  Section? lastChorus;
  GridShape? lastGridShape;

  /// Open delegated environment.
  DelegateSection? delegate;

  /// Section name being skipped because its selector did not match.
  String? skipping;

  /// `{transpose}` stack: (semitones, prefer flats).
  final transposeStack = <(int, bool?)>[];
  Key? currentKey;
  int? leadingTranspose;
  bool hasAnything = false;

  int get transpose => transposeStack.isEmpty ? 0 : transposeStack.last.$1;
  bool? get preferFlats =>
      transposeStack.isEmpty ? null : transposeStack.last.$2;

  List<String> lookup(String name) {
    switch (name) {
      case 'key_actual':
        final key = currentKey?.transpose(transpose);
        return key == null ? const [] : [key.toString()];
      case 'key_from':
        return transpose == 0 || currentKey == null
            ? const []
            : [currentKey.toString()];
      case '_key':
        final capo = int.tryParse(meta['capo']?.firstOrNull ?? '') ?? 0;
        final key = currentKey?.transpose(capo);
        return key == null ? const [] : [key.toString()];
      case 'instrument' || 'instrument.type':
        return [?selectors.instrument];
      case 'user' || 'user.name':
        return [?selectors.user];
      case 'today':
        final now = DateTime.now();
        String two(int n) => n.toString().padLeft(2, '0');
        return ['${now.year}-${two(now.month)}-${two(now.day)}'];
      case 'chordpro':
        return const ['ChordPro'];
    }
    return meta[name] ?? const [];
  }

  String substitute(String text) => substituteMetadata(text, lookup);

  bool selected(Directive d) {
    final selector = d.selector;
    if (selector == null) return true;
    final match =
        selector == selectors.instrument?.toLowerCase() ||
        selector == selectors.user?.toLowerCase() ||
        isTruthy(meta[selector]?.firstOrNull);
    return d.negated ? !match : match;
  }

  Section ensureSection() {
    if (current == null) {
      current = Section(kind: SectionKind.none);
      elements.add(current!);
      explicitSection = false;
    }
    return current!;
  }

  void startContent() {
    hasAnything = true;
    leadingTranspose ??= transpose;
  }

  void closeSection() {
    var section = current;
    if (section != null && !explicitSection) {
      // SongSelect and other sources mark sections with a comment heading
      // such as `{comment: Verse 1}` instead of `{start_of_verse}`.
      final heading = _headingSection(section);
      if (heading != null) {
        elements[elements.indexOf(section)] = heading;
        section = heading;
      }
    }
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

  void addLine(String rawLine) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();
    final d = trimmed.startsWith('{') ? parseDirective(trimmed) : null;

    // Inside a delegated environment everything up to its end is content.
    final openDelegate = delegate;
    if (openDelegate != null) {
      if (d != null && d.name == 'end_of_${openDelegate.type.name}') {
        delegate = null;
      } else {
        openDelegate.lines.add(line);
      }
      return;
    }

    // Skipping a section whose selector did not match.
    if (skipping != null) {
      if (d != null &&
          (d.name == 'end_of_$skipping' || _shortEnd[d.name] == skipping)) {
        skipping = null;
      }
      return;
    }

    if (d != null) {
      _directive(d);
      return;
    }

    if (trimmed.startsWith('#')) return;

    final section = current;
    if (section != null && section.isPreformatted) {
      section.lines.add(line.isEmpty ? const EmptyLine() : RawLine(line));
      return;
    }
    if (section != null && section.kind == SectionKind.grid) {
      if (trimmed.isEmpty) {
        section.lines.add(const EmptyLine());
      } else {
        section.lines.add(
          GridLine(
            parseGridRow(
              trimmed,
              transpose: transpose,
              preferFlats: preferFlats,
              key: currentKey,
            ),
          ),
        );
      }
      return;
    }

    if (trimmed.isEmpty) {
      // An empty line outside an explicit section separates implicit
      // paragraphs; inside a section it is kept as a spacer.
      if (section != null && !explicitSection) {
        closeSection();
      } else if (section != null) {
        section.lines.add(const EmptyLine());
      }
      return;
    }

    startContent();
    ensureSection().lines.add(
      parseLyricLine(
        line,
        transpose: transpose,
        preferFlats: preferFlats,
        key: currentKey,
      ),
    );
  }

  void _directive(Directive d) {
    final name = d.name;
    // Custom extensions start with x_ (ChordPro spec); other tools ignore
    // them. RealChord knows {x_sequence} (song sequence), kept as
    // metadata so that %{x_sequence} works; all others are ignored.
    if (name == 'x_sequence') {
      _addMeta('x_sequence', d.plainArgument);
      return;
    }
    if (name.startsWith('x_')) return;

    // Section ends never carry a selector; handle them first.
    final endName = name.startsWith('end_of_')
        ? name.substring(7)
        : _shortEnd[name];
    if (endName != null) {
      closeSection();
      return;
    }

    final startName = name.startsWith('start_of_')
        ? name.substring(9)
        : _shortStart[name];

    if (!selected(d)) {
      if (startName != null) skipping = startName;
      return;
    }

    final metaName = _metaAliases[name];
    if (metaName != null) {
      _addMeta(metaName, d.plainArgument);
      return;
    }
    if (name == 'meta') {
      final m = RegExp(r'^(\S+)\s*(.*)$').firstMatch(d.argument);
      if (m != null) _addMeta(m.group(1)!.toLowerCase(), m.group(2)!);
      return;
    }

    final commentStyle = _commentAliases[name];
    if (commentStyle != null) {
      startContent();
      ensureSection().lines.add(
        CommentLine(substitute(d.argument), style: commentStyle),
      );
      return;
    }

    if (startName != null) {
      _startSection(startName, d);
      return;
    }

    switch (name) {
      case 'chorus':
        closeSection();
        startContent();
        final label = d.label;
        elements.add(
          ChorusRecall(
            label: label == null ? null : substitute(label),
            chorus: lastChorus,
          ),
        );
      case 'transpose':
        _transpose(d.plainArgument);
      case 'image':
        startContent();
        final attributes = d.attributes.isNotEmpty
            ? d.attributes
            : {'src': d.plainArgument};
        ensureSection().lines.add(ImageLine(attributes));
      case 'define':
        final def = ChordDefinition.tryParse(d.argument);
        if (def != null) definitions.add(def);
      case 'chord':
        final def = ChordDefinition.tryParse(d.argument);
        if (def != null) {
          startContent();
          ensureSection().lines.add(ChordDiagramLine(def));
        }
      case 'diagrams':
        diagrams = d.plainArgument.isEmpty
            ? 'on'
            : d.plainArgument.toLowerCase();
      case 'columns' || 'col':
        columns = int.tryParse(d.plainArgument);
      case 'column_break' || 'colb':
        ensureSection().lines.add(const BreakLine(BreakKind.column));
      case 'new_page' || 'np' || 'new_physical_page' || 'npp':
        ensureSection().lines.add(const BreakLine(BreakKind.page));
      default:
        final format = _formatDirectives[name];
        if (format != null) {
          final value = d.plainArgument;
          ensureSection().lines.add(
            FormatLine(format.$1, format.$2, value.isEmpty ? null : value),
          );
        }
      // Other directives (pagetype, titles, grid, no_grid, unknown ones)
      // have no effect on screen.
    }
  }

  void _addMeta(String name, String value) {
    hasAnything = true;
    meta.putIfAbsent(name, () => []).add(value);
    if (name == 'key') {
      final key = Key.tryParse(value);
      if (key != null) currentKey = key;
    }
  }

  void _startSection(String name, Directive d) {
    closeSection();
    final delegateType = _delegates[name];
    if (delegateType != null) {
      startContent();
      final label = d.label;
      final section = DelegateSection(
        type: delegateType,
        label: label == null ? null : substitute(label),
        attributes: d.attributes,
      );
      elements.add(section);
      delegate = section;
      return;
    }

    final kind = _sectionKinds[name] ?? SectionKind.custom;
    GridShape? shape;
    var label = d.label;
    if (kind == SectionKind.grid) {
      // {start_of_grid shape="1+4x4+1" label="Intro"} or legacy
      // {start_of_grid: 1+4x4+1 Intro}.
      shape = GridShape.tryParse(d.attributes['shape']);
      if (shape == null && d.attributes.isEmpty && d.argument.isNotEmpty) {
        final legacy = RegExp(r'^(\S+)\s*(.*)$').firstMatch(d.argument);
        shape = GridShape.tryParse(legacy?.group(1));
        if (shape != null) {
          final rest = legacy!.group(2)!.trim();
          label = rest.isEmpty ? null : rest;
        }
      }
      shape ??= lastGridShape ?? GridShape.fallback;
      lastGridShape = shape;
    }
    startContent();
    current = Section(
      kind: kind,
      label: label == null ? null : substitute(label),
      name: name,
      attributes: d.attributes,
      gridShape: shape,
    );
    elements.add(current!);
    explicitSection = true;
  }

  void _transpose(String argument) {
    if (argument.isEmpty) {
      if (transposeStack.isNotEmpty) transposeStack.removeLast();
      return;
    }
    final m = RegExp(r'^([+-]?\d+)\s*([sf])?$').firstMatch(argument);
    if (m == null) return;
    final value = int.parse(m.group(1)!);
    final mode = m.group(2);
    final flats = mode == 'f'
        ? true
        : mode == 's'
        ? false
        : value < 0;
    transposeStack.add((value, flats));
  }

  Song finish() {
    delegate = null;
    closeSection();
    return Song(
      meta: meta,
      elements: elements,
      definitions: definitions,
      columns: columns,
      diagrams: diagrams,
      leadingTranspose: leadingTranspose ?? transpose,
    );
  }
}

/// Parses a single line with inline chords, e.g. `[G]Hello [C]world`.
/// `\[` and `\]` produce literal brackets.
LyricLine parseLyricLine(
  String line, {
  int transpose = 0,
  bool? preferFlats,
  Key? key,
}) {
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
    if (char == r'\' &&
        index + 1 < line.length &&
        '[]{}'.contains(line[index + 1])) {
      text.write(line[index + 1]);
      index += 2;
      continue;
    }
    if (char == '[') {
      final end = line.indexOf(']', index + 1);
      if (end > index) {
        flush();
        pendingChord = ChordToken(
          line.substring(index + 1, end).trim(),
          transpose: transpose,
          preferFlats: preferFlats,
          key: key,
        );
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

void _trimEmptyLines(List<Line> lines) {
  while (lines.isNotEmpty && lines.first is EmptyLine) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last is EmptyLine) {
    lines.removeLast();
  }
}

final _heading = RegExp(
  r'^(pre[\s-]?chorus|pre[\s-]?refrain|post[\s-]?chorus|chorus|refrain|'
  r'verse|vers|strophe|bridge|intro|outro|tag|interlude|instrumental|'
  r'zwischenspiel|ending|schluss|coda|solo|vamp|turnaround)'
  r'(\s*\d+[a-z]?)?(\s*\(.*\))?\s*:?$',
  caseSensitive: false,
);

/// Turns an implicit section starting with a heading comment into a
/// labelled section, e.g. `{comment: Chorus 1}` → chorus "Chorus 1".
Section? _headingSection(Section section) {
  if (section.kind != SectionKind.none || section.lines.isEmpty) return null;
  final first = section.lines.first;
  if (first is! CommentLine || first.style != CommentStyle.normal) return null;
  final match = _heading.firstMatch(first.text.trim());
  if (match == null) return null;
  final kind = switch (match.group(1)!.toLowerCase()) {
    'chorus' || 'refrain' => SectionKind.chorus,
    'verse' || 'vers' || 'strophe' => SectionKind.verse,
    'bridge' => SectionKind.bridge,
    _ => SectionKind.custom,
  };
  return Section(
    kind: kind,
    label: first.text.trim(),
    lines: section.lines.sublist(1),
  );
}
