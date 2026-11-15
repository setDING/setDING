/// Song sequence (arrangement): RealChord' custom directive `{x_sequence}`,
/// e.g. `{x_sequence: I, V1, C, V2, PC, C x2, B, C, O}`.
library;

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
  final found = <({SequencePart part, int? number, String text})>[];
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
    found.add((part: item.part, number: item.number, text: text));
  }
  // Number unlabelled repeats of a part: Verse, Verse → V1, V2.
  final unnumbered = <SequencePart, int>{};
  for (final f in found) {
    if (f.part != SequencePart.other && f.number == null) {
      unnumbered[f.part] = (unnumbered[f.part] ?? 0) + 1;
    }
  }
  final counters = <SequencePart, int>{};
  final result = <String, SequenceItem>{};
  for (final f in found) {
    var number = f.number;
    if (f.part != SequencePart.other &&
        number == null &&
        unnumbered[f.part]! > 1) {
      number = counters[f.part] = (counters[f.part] ?? 0) + 1;
    }
    final code = f.part == SequencePart.other
        ? f.text
        : '${sequenceAbbreviations[f.part]}${number ?? ''}';
    result.putIfAbsent(
      code,
      () => SequenceItem(code: code, part: f.part, number: number),
    );
  }
  return result.values.toList();
}
