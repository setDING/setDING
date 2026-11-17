/// The trimmed [value], or null when it is null or blank.
String? blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

const _folded = {
  'àáâãäå': 'a',
  'æ': 'ae',
  'ç': 'c',
  'èéêë': 'e',
  'ìíîï': 'i',
  'ñ': 'n',
  'òóôõöø': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ùúûü': 'u',
  'ýÿ': 'y',
};

final _foldMap = {
  for (final MapEntry(:key, :value) in _folded.entries)
    for (final c in key.split('')) c: value,
};

/// [value] in lower case without accents, for sorting and grouping
/// (`Ärger` sorts with `arger`, not after `Z`).
String foldForSort(String value) {
  final out = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    out.write(_foldMap[c] ?? c);
  }
  return out.toString();
}
