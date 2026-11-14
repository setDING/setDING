/// Song sequence (arrangement): BandChords' custom directive `{x_sequence}`,
/// e.g. `{x_sequence: I, V1, C, V2, PC, C x2, B, C, O}`.
library;

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
