/// Display formatting of chords: transposition, capo, notation, Nashville.
library;

import 'chord.dart';
import 'song.dart';

/// Options that turn a written chord into the displayed chord.
///
/// Combines the layers of ADR-0006: set item transposition, personal
/// transposition and capo, and the device settings for notation and
/// Nashville numbers.
class ChordFormatter {
  const ChordFormatter({
    this.transpose = 0,
    this.capo = 0,
    this.notation = ChordNotation.international,
    this.nashville = false,
    this.key,
  });

  /// Creates a formatter for [song], using its `{key}` directive.
  factory ChordFormatter.forSong(
    Song song, {
    int transpose = 0,
    int capo = 0,
    ChordNotation notation = ChordNotation.international,
    bool nashville = false,
  }) => ChordFormatter(
    transpose: transpose,
    capo: capo,
    notation: notation,
    nashville: nashville,
    key: song.key,
  );

  /// Semitones to transpose the sounding pitch (set item + personal).
  final int transpose;

  /// Capo fret: chords are shown as shapes, i.e. `capo` semitones lower.
  final int capo;

  final ChordNotation notation;

  /// Show Nashville numbers instead of chord names (requires [key]).
  final bool nashville;

  /// Original key of the song.
  final Key? key;

  /// Total shift applied to written chords.
  int get shift => transpose - capo;

  /// Sounding key after transposition.
  Key? get soundingKey => key?.transpose(transpose);

  /// Key of the chord shapes (after capo).
  Key? get shapeKey => key?.transpose(shift);

  /// Whether Nashville numbers can actually be shown.
  bool get showsNashville => nashville && key != null;

  /// Formats a chord token for display.
  String format(ChordToken token) {
    if (token.isAnnotation) return token.annotationText;
    final chord = token.chord;
    if (chord == null) return token.raw;
    if (shift == 0 && notation == ChordNotation.international && !nashville) {
      return token.raw;
    }
    final String text;
    if (showsNashville) {
      text = chord.toNashville(key!);
    } else {
      final useFlats = shift == 0
          ? null
          : (shapeKey?.usesFlats ?? chord.root.preferFlat);
      text = chord.transpose(shift, useFlats: useFlats).format(notation);
    }
    return token.parenthesized ? '($text)' : text;
  }

  /// Formats the sounding key for display (e.g. in the header).
  String? formatKey() => soundingKey?.format(notation);
}
