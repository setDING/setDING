/// Conversion of German chord notation to international notation.
library;

import 'chord.dart';

final _chordInBrackets = RegExp(r'\[([^\]\[]*)\]');
final _keyDirective = RegExp(
  r'^(\s*\{\s*key\s*[:\s]\s*)([^}]*?)(\s*\})\s*$',
  caseSensitive: false,
  multiLine: true,
);

/// Converts all chords in [source] from German notation (H = B, B = B flat)
/// to international notation. Only chords in brackets and the `{key}`
/// directive are changed; everything else is kept as written.
String convertGermanToInternational(String source) {
  String convert(String text) {
    final chord = Chord.tryParse(text, germanInput: true);
    return chord == null ? text : chord.format(ChordNotation.international);
  }

  final withChords = source.replaceAllMapped(
    _chordInBrackets,
    (m) => '[${convert(m.group(1)!)}]',
  );
  return withChords.replaceAllMapped(
    _keyDirective,
    (m) => '${m.group(1)}${convert(m.group(2)!)}${m.group(3)}',
  );
}
