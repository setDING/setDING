/// Song sequence (arrangement): setDING' custom directive `{x_sequence}`,
/// e.g. `{x_sequence: I, V1, C, V2, PC, C x2, B, C, O}`.
library;

import 'markup.dart';
import 'parser.dart' show sourceLineOf;
import 'song.dart';

/// Kind of a part in a song sequence.
enum SequencePart {
  intro,
  verse,
  preChorus,
  chorus,
  postChorus,
  bridge,
  interlude,
  instrumental,
  solo,
  tag,
  outro,
  other,
}

/// One entry of a song sequence.
class SequenceItem {
  const SequenceItem({
    required this.code,
    required this.part,
    this.number,
    this.repeat,
  });

  /// As written, e.g. `V1`, `C x2`.
  final String code;
  final SequencePart part;

  /// Number of the part, e.g. 1 for `V1`.
  final int? number;

  /// Repetitions, e.g. 2 for `C x2` or `2x C`.
  final int? repeat;
}

/// Abbreviations (lower case) → part. Longer names are accepted too.
const _parts = {
  'i': SequencePart.intro,
  'in': SequencePart.intro,
  'intro': SequencePart.intro,
  'v': SequencePart.verse,
  'vs': SequencePart.verse,
  'verse': SequencePart.verse,
  'vers': SequencePart.verse,
  's': SequencePart.verse, // Strophe
  'str': SequencePart.verse,
  'strophe': SequencePart.verse,
  'pc': SequencePart.preChorus,
  'pre': SequencePart.preChorus,
  'prec': SequencePart.preChorus,
  'prechorus': SequencePart.preChorus,
  'pre-chorus': SequencePart.preChorus,
  'pr': SequencePart.preChorus, // Pre-Refrain
  'prerefrain': SequencePart.preChorus,
  'c': SequencePart.chorus,
  'ch': SequencePart.chorus,
  'chorus': SequencePart.chorus,
  'r': SequencePart.chorus, // Refrain
  'ref': SequencePart.chorus,
  'refrain': SequencePart.chorus,
  'poc': SequencePart.postChorus,
  'postc': SequencePart.postChorus,
  'postchorus': SequencePart.postChorus,
  'post-chorus': SequencePart.postChorus,
  'b': SequencePart.bridge,
  'br': SequencePart.bridge,
  'bridge': SequencePart.bridge,
  'int': SequencePart.interlude,
  'interlude': SequencePart.interlude,
  'zw': SequencePart.interlude, // Zwischenspiel
  'zwischenspiel': SequencePart.interlude,
  'inst': SequencePart.instrumental,
  'instr': SequencePart.instrumental,
  'instrumental': SequencePart.instrumental,
  'solo': SequencePart.solo,
  'sol': SequencePart.solo,
  't': SequencePart.tag,
  'tag': SequencePart.tag,
  'o': SequencePart.outro,
  'out': SequencePart.outro,
  'outro': SequencePart.outro,
  'end': SequencePart.outro,
  'ending': SequencePart.outro,
  'schluss': SequencePart.outro,
};

final _item = RegExp(
  r'^(?:(\d+)\s*[x×]\s*)?([a-zA-Z][a-zA-Z-]*?)\s*(\d+)?\s*(?:[x×]\s*(\d+)|\((\d+)\s*[x×]\))?$',
);

/// Parses the value of `{x_sequence}`. Items are separated by commas (or
/// semicolons); unknown abbreviations are kept as [SequencePart.other].
List<SequenceItem> parseSequence(String value) => [
  for (final raw in value.split(RegExp(r'[,;]')))
    if (raw.trim().isNotEmpty) _parseItem(raw.trim()),
];

SequenceItem _parseItem(String code) {
  final m = _item.firstMatch(code);
  if (m == null) {
    return SequenceItem(code: code, part: SequencePart.other);
  }
  final name = m.group(2)!.toLowerCase();
  return SequenceItem(
    code: code,
    part: _parts[name] ?? SequencePart.other,
    number: int.tryParse(m.group(3) ?? ''),
    repeat: int.tryParse(m.group(1) ?? m.group(4) ?? m.group(5) ?? ''),
  );
}

final _directive = RegExp(
  r'^[ \t]*\{[ \t]*x_sequence[ \t]*:[ \t]*([^}\n]*)\}',
  multiLine: true,
);

/// The raw value of the first `{x_sequence}` in a ChordPro [source], without
/// parsing the whole song (e.g. for list views). Null when there is none.
String? findSequence(String source) {
  final value = _directive.firstMatch(source)?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// Short code of each part, used for sequences built from a song's parts.
const sequenceAbbreviations = {
  SequencePart.intro: 'I',
  SequencePart.verse: 'V',
  SequencePart.preChorus: 'PC',
  SequencePart.chorus: 'C',
  SequencePart.postChorus: 'PoC',
  SequencePart.bridge: 'B',
  SequencePart.interlude: 'Int',
  SequencePart.instrumental: 'Inst',
  SequencePart.solo: 'Solo',
  SequencePart.tag: 'T',
  SequencePart.outro: 'O',
};

/// The parts that exist in [song] (its sections), in document order and
/// without duplicates, as sequence items with short codes (`V1`, `PC`, `C`).
///
/// The part is detected from the section label (`Verse 2`, `Pre-Chorus`,
/// `Refrain`) or, without a label, from the section type. Unlabelled
/// sections of the same part are numbered when there are several.
/// Unknown labels are kept as written (e.g. `Coda`).
List<SequenceItem> songParts(Song song) {
  final result = <String, SequenceItem>{};
  for (final item in _sectionParts(song).values) {
    result.putIfAbsent(item.code, () => item);
  }
  return result.values.toList();
}

/// The part of each section of [song] that is one (see [songParts]).
Map<Section, SequenceItem> _sectionParts(Song song) {
  final found =
      <({Section section, SequencePart part, int? number, String text})>[];
  for (final section in song.sections) {
    final label = section.label?.split('\n').first.trim();
    final text = (label != null && label.isNotEmpty)
        ? label
        : switch (section.kind) {
            SectionKind.verse => 'Verse',
            SectionKind.chorus => 'Chorus',
            SectionKind.bridge => 'Bridge',
            SectionKind.custom => section.name ?? '',
            _ => '',
          };
    if (text.isEmpty) continue;
    final item = _parseItem(text);
    found.add((
      section: section,
      part: item.part,
      number: item.number,
      text: text,
    ));
  }
  // Number unlabelled repeats of a part: Verse, Verse → V1, V2.
  final unnumbered = <SequencePart, int>{};
  for (final f in found) {
    if (f.part != SequencePart.other && f.number == null) {
      unnumbered[f.part] = (unnumbered[f.part] ?? 0) + 1;
    }
  }
  final counters = <SequencePart, int>{};
  return {
    for (final f in found)
      f.section: () {
        var number = f.number;
        if (f.part != SequencePart.other &&
            number == null &&
            unnumbered[f.part]! > 1) {
          number = counters[f.part] = (counters[f.part] ?? 0) + 1;
        }
        final code = f.part == SequencePart.other
            ? f.text
            : '${sequenceAbbreviations[f.part]}${number ?? ''}';
        return SequenceItem(code: code, part: f.part, number: number);
      }(),
  };
}

/// [song] reduced to the parts of a [sequence], see [filterBySequence].
class SequenceSelection {
  const SequenceSelection(
    this.song,
    this.hidden, {
    this.outside = const [],
    Set<int> outsideLines = const {},
  }) : _outsideLines = outsideLines;

  /// The song with only the sections of the sequence, or the whole song
  /// when the parts outside the sequence are kept (see [outside]).
  final Song song;

  /// Codes of the hidden parts (`V3`, `B`, `Coda`), in document order and
  /// without duplicates; empty when nothing is hidden.
  final List<String> hidden;

  /// Codes of the parts outside the sequence that were kept (`keepOutside`
  /// of [filterBySequence]), in document order and without duplicates.
  final List<String> outside;

  /// Source lines of the sections in [outside].
  final Set<int> _outsideLines;

  /// Whether [section] is a part outside the sequence that was kept. Also
  /// true for copies made from such a section (e.g. by
  /// [firstVerseChordsOnly]), as they keep its source line.
  bool isOutside(Section section) {
    final line = sourceLineOf(section);
    return line != null && _outsideLines.contains(line);
  }
}

/// Keeps only the sections of [song] whose part appears in [sequence]
/// (`V` matches every verse, `V2` only the second one). Sections that are
/// no part (no label, tab, grid) stay, and so do delegated environments; a
/// chorus recall stays when the sequence has a chorus. Order and
/// repetitions of the sequence are not applied: the song stays in
/// document order.
///
/// With [keepOutside], nothing is left out: the song is returned whole and
/// the parts outside the sequence are listed in [SequenceSelection.outside]
/// instead, e.g. to show them dimmed.
///
/// When the sequence is empty or matches none of the song's parts (e.g.
/// unknown codes), the song is returned unchanged.
SequenceSelection filterBySequence(
  Song song,
  List<SequenceItem> sequence, {
  bool keepOutside = false,
}) {
  final parts = _sectionParts(song);
  if (sequence.isEmpty || parts.isEmpty) {
    return SequenceSelection(song, const []);
  }
  bool inSequence(SequenceItem part) => sequence.any(
    (item) => part.part == SequencePart.other
        ? item.part == SequencePart.other &&
              _otherKey(item.code) == _otherKey(part.code)
        : item.part == part.part &&
              (item.number == null ||
                  part.number == null ||
                  item.number == part.number),
  );
  if (!parts.values.any(inSequence)) return SequenceSelection(song, const []);
  final hasChorus = sequence.any((i) => i.part == SequencePart.chorus);
  final hidden = <String>{};
  final elements = <SongElement>[];
  if (keepOutside) {
    final outsideLines = <int>{};
    for (final MapEntry(key: section, value: part) in parts.entries) {
      if (inSequence(part)) continue;
      hidden.add(part.code);
      final line = sourceLineOf(section);
      if (line != null) outsideLines.add(line);
    }
    if (hidden.isEmpty) return SequenceSelection(song, const []);
    return SequenceSelection(
      song,
      const [],
      outside: hidden.toList(),
      outsideLines: outsideLines,
    );
  }
  for (final element in song.elements) {
    final part = element is Section ? parts[element] : null;
    if (part != null && !inSequence(part)) {
      hidden.add(part.code);
    } else if (element is ChorusRecall && !hasChorus) {
      hidden.add(sequenceAbbreviations[SequencePart.chorus]!);
    } else {
      elements.add(element);
    }
  }
  if (hidden.isEmpty) return SequenceSelection(song, const []);
  return SequenceSelection(
    Song(
      meta: song.meta,
      elements: elements,
      definitions: song.definitions,
      columns: song.columns,
      diagrams: song.diagrams,
      leadingTranspose: song.leadingTranspose,
    ),
    hidden.toList(),
  );
}

/// Name and number of an unknown part, without repetitions: `Coda x2` →
/// `coda`.
String _otherKey(String code) {
  final m = _item.firstMatch(code.trim());
  if (m == null) return code.trim().toLowerCase();
  return '${m.group(2)!.toLowerCase()}${m.group(3) ?? ''}';
}

/// One block of the song map of the drummer mode (ADR-0026): a part as it
/// is played, with a cue from the lyrics and the notes of its section.
class SongMapEntry {
  const SongMapEntry({required this.part, this.cue, this.notes = const []});

  /// The part (code, kind, number and repetitions).
  final SequenceItem part;

  /// The first line of lyrics of the part, without chords and markup.
  final String? cue;

  /// The comments of the part's section, e.g. drum notes
  /// (`{comment-drums: …}` with the instrument drums).
  final List<String> notes;
}

/// The song as the drummer plays it (ADR-0026): the parts of [sequence] in
/// its order with its repetitions, each with a cue and the comments of its
/// section. A part without a number takes the next section of its kind
/// (`V, C, V, C` → first verse, chorus, second verse, chorus). Without a
/// sequence, or when it matches none of the song's parts, the parts of the
/// song in document order (a chorus recall repeats the chorus).
List<SongMapEntry> songMap(Song song, List<SequenceItem> sequence) => [
  for (final (:part, :section) in playedParts(song, sequence))
    SongMapEntry(
      part: part,
      cue: section == null ? null : _cue(section),
      notes: section == null ? const [] : _notes(section),
    ),
];

/// The parts of [song] in the order the band plays them, each with its
/// section (null when a sequence item matches no section): the parts of
/// [sequence] in its order (repetitions are kept on the item, not
/// expanded), where a part without a number takes the next section of its
/// kind (`V, C, V, C` → first verse, chorus, second verse, chorus).
/// Without a sequence, or when it matches none of the song's parts, the
/// parts of the song in document order, a chorus recall repeating the
/// chorus. Sections that are no part (no label, tab, grid) are left out;
/// used by the song map (ADR-0026) and the lyrics projection (ADR-0068).
List<({SequenceItem part, Section? section})> playedParts(
  Song song,
  List<SequenceItem> sequence,
) {
  final bySequence = sequenceParts(song, sequence);
  if (bySequence != null) return bySequence;
  final parts = _sectionParts(song);
  final result = <({SequenceItem part, Section? section})>[];
  Section? lastChorus;
  for (final element in song.elements) {
    if (element is Section) {
      final part = parts[element];
      if (part == null) continue;
      if (element.kind == SectionKind.chorus) lastChorus = element;
      result.add((part: part, section: element));
    } else if (element is ChorusRecall) {
      final chorus = element.chorus ?? lastChorus;
      final part = chorus == null ? null : parts[chorus];
      result.add((
        part:
            part ??
            SequenceItem(
              code: sequenceAbbreviations[SequencePart.chorus]!,
              part: SequencePart.chorus,
            ),
        section: chorus,
      ));
    }
  }
  return result;
}

/// The parts of [sequence] in its order, each with the section of [song]
/// it plays (see [playedParts]); null when the sequence is empty or matches
/// none of the song's parts.
List<({SequenceItem part, Section? section})>? sequenceParts(
  Song song,
  List<SequenceItem> sequence,
) {
  final parts = _sectionParts(song);
  final sections = parts.keys.toList();
  bool matches(SequenceItem item, SequenceItem part) =>
      part.part == SequencePart.other
      ? item.part == SequencePart.other &&
            _otherKey(item.code) == _otherKey(part.code)
      : item.part == part.part &&
            (item.number == null ||
                part.number == null ||
                item.number == part.number);

  if (sequence.isNotEmpty &&
      parts.values.any((p) => sequence.any((i) => matches(i, p)))) {
    final used = <SequencePart, int>{};
    return [
      for (final item in sequence)
        () {
          final candidates = [
            for (final s in sections)
              if (matches(item, parts[s]!)) s,
          ];
          Section? section;
          if (candidates.isNotEmpty) {
            if (item.number != null || candidates.length == 1) {
              section = candidates.first;
            } else {
              final n = used[item.part] ?? 0;
              section = candidates[n % candidates.length];
              used[item.part] = n + 1;
            }
          }
          return (part: item, section: section);
        }(),
    ];
  }
  return null;
}

String? _cue(Section section) {
  for (final line in section.lines) {
    if (line is LyricLine) {
      final text = line.plainText.trim();
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

List<String> _notes(Section section) => [
  for (final line in section.lines)
    if (line is CommentLine && stripMarkup(line.text).trim().isNotEmpty)
      stripMarkup(line.text).trim(),
];
