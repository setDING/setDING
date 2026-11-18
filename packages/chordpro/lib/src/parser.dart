/// ChordPro parser for the whole ChordPro 6 specification (ADR-0003,
/// ADR-0012).
library;

import 'chord.dart';
import 'diagrams.dart';
import 'directive.dart';
import 'directive_names.dart';
import 'grid.dart';
import 'metadata.dart';
import 'section_heading.dart';
import 'song.dart';

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

final _sourceLines = Expando<int>('sourceLine');

/// The line of the source (0-based, counted over all songs of the source)
/// that [element] was parsed from: a [Line], or the start directive of a
/// [Section] or [DelegateSection]. Null if unknown, e.g. for empty lines.
/// Used to jump from the preview to the source in the editor (#372).
int? sourceLineOf(Object element) => _sourceLines[element];

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
  for (final (index, line) in lines.indexed) {
    final d = line.trimLeft().startsWith('{') ? parseDirective(line) : null;
    if (d != null && (d.name == 'new_song' || d.name == 'ns')) {
      if (parser.hasAnything) songs.add(parser.finish());
      parser = _SongParser(selectors);
      continue;
    }
    parser.addSourceLine(line, index);
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
      // Comments before the heading (e.g. `{comment_italic: first time a
      // cappella}`) stay in an unlabelled section of their own.
      final split = _headingSection(section);
      if (split != null) {
        final (:preface, :heading) = split;
        final index = elements.indexOf(section);
        elements[index] = heading;
        if (preface != null) {
          elements.insert(index, preface);
          _sourceLines[preface] = _sourceLines[section];
          _trimEmptyLines(preface.lines);
        }
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

  /// [addLine] that remembers [index] as the source line of the lines,
  /// sections and delegated environments it creates.
  void addSourceLine(String rawLine, int index) {
    final section = current;
    final known = section?.lines.length ?? 0;
    final openDelegate = delegate;
    addLine(rawLine);
    void mark(Object element) => _sourceLines[element] ??= index;
    if (delegate case final d? when !identical(d, openDelegate)) mark(d);
    final now = current;
    if (now == null) return;
    if (!identical(now, section)) mark(now);
    final from = identical(now, section) ? known : 0;
    for (final line in now.lines.skip(from)) {
      // Constant lines (empty lines, breaks) are shared objects.
      if (line is! EmptyLine && line is! BreakLine) mark(line);
    }
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
          (d.name == 'end_of_$skipping' ||
              shortSectionEnds[d.name] == skipping)) {
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
    // them. setDING knows {x_sequence} (song sequence) and
    // {x_time_grouping} (ADR-0026), kept as metadata so that %{x_sequence}
    // works; all others are ignored.
    if (customDirectives.contains(name)) {
      _addMeta(name, d.plainArgument);
      return;
    }
    if (name.startsWith('x_')) return;

    // Section ends never carry a selector; handle them first.
    final endName = name.startsWith('end_of_')
        ? name.substring(7)
        : shortSectionEnds[name];
    if (endName != null) {
      closeSection();
      return;
    }

    final startName = name.startsWith('start_of_')
        ? name.substring(9)
        : shortSectionStarts[name];

    if (!selected(d)) {
      if (startName != null) skipping = startName;
      return;
    }

    final metaName = metaDirectiveAliases[name];
    if (metaName != null) {
      _addMeta(metaName, d.plainArgument);
      return;
    }
    if (name == 'meta') {
      final m = RegExp(r'^(\S+)\s*(.*)$').firstMatch(d.argument);
      if (m != null) _addMeta(m.group(1)!.toLowerCase(), m.group(2)!);
      return;
    }

    final commentStyle = commentDirectives[name];
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
        final format = formatDirectives[name];
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
    final delegateType = delegateSectionNames[name];
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

    final kind = sectionKindNames[name] ?? SectionKind.custom;
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

/// Turns an implicit section starting with a heading comment into a
/// labelled section, e.g. `{comment: Chorus 1}` → chorus "Chorus 1".
///
/// Other comments may precede the heading; they are returned as an
/// unlabelled [preface] section shown before the labelled one.
({Section? preface, Section heading})? _headingSection(Section section) {
  if (section.kind != SectionKind.none) return null;
  for (var i = 0; i < section.lines.length; i++) {
    final line = section.lines[i];
    if (line is EmptyLine) continue;
    if (line is! CommentLine) return null;
    if (line.style != CommentStyle.normal) continue;
    final kind = headingSectionKind(line.text);
    if (kind == null) continue;
    final heading = Section(
      kind: kind,
      label: line.text.trim(),
      lines: section.lines.sublist(i + 1),
    );
    _sourceLines[heading] = _sourceLines[line] ?? _sourceLines[section];
    final preface = i == 0
        ? null
        : Section(kind: SectionKind.none, lines: section.lines.sublist(0, i));
    return (preface: preface, heading: heading);
  }
  return null;
}
