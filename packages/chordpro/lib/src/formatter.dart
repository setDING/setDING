/// Display formatting of chords: transposition, capo, notation, Nashville.
library;

import 'chord.dart';
import 'song.dart';

/// Options that turn a written chord into the displayed chord.
///
/// Combines the layers of ADR-0006 (set item transposition, personal
/// transposition and capo, device settings for notation and Nashville
/// numbers) with the song's own `{transpose}`, `{key}` and `{capo}`
/// directives (ADR-0012).
class ChordFormatter {
  const ChordFormatter({
    this.transpose = 0,
    this.capo,
    this.songCapo = 0,
    this.notation = ChordNotation.international,
    this.nashville = false,
    this.key,
    this.leadingTranspose = 0,
  });

  /// Creates a formatter for [song], using its `{key}`, `{capo}` and
  /// leading `{transpose}` directives.
  factory ChordFormatter.forSong(
    Song song, {
    int transpose = 0,
    int? capo,
    ChordNotation notation = ChordNotation.international,
    bool nashville = false,
  }) => ChordFormatter(
    transpose: transpose,
    capo: capo,
    songCapo: song.capoFret,
    notation: notation,
    nashville: nashville,
    key: song.key,
    leadingTranspose: song.leadingTranspose,
  );

  /// Semitones to transpose the sounding pitch (set item + personal).
  final int transpose;

  /// Personal capo fret; null = play with the song's own `{capo}`.
  final int? capo;

  /// `{capo}` of the song: the chords in the file are shapes for this fret.
  final int songCapo;

  final ChordNotation notation;

  /// Show Nashville numbers instead of chord names (requires a key).
  final bool nashville;

  /// First `{key}` of the song (as written).
  final Key? key;

  /// `{transpose}` in effect where the song starts.
  final int leadingTranspose;

  /// Capo the player uses.
  int get effectiveCapo => capo ?? songCapo;

  /// Shift applied to written chords, in addition to `{transpose}`.
  int get shift => transpose + songCapo - effectiveCapo;

  /// Key as heard (concert key) at the start of the song.
  Key? get soundingKey =>
      key?.transpose(leadingTranspose + transpose + songCapo);

  /// Key of the chord shapes at the start of the song.
  Key? get shapeKey => key?.transpose(leadingTranspose + shift);

  /// Whether Nashville numbers can actually be shown.
  bool get showsNashville => nashville && key != null;

  /// Formats a chord token for display.
  String format(ChordToken token) {
    if (token.isAnnotation) return token.annotationText;
    final chord = token.chord;
    if (chord == null) return token.raw;
    final tokenKey = token.key ?? key;
    String text;
    if (nashville && tokenKey != null) {
      // Degrees relative to the key in effect (both as written).
      text = chord.toNashville(tokenKey);
    } else {
      final total = shift + token.transpose;
      if (total == 0 && notation == ChordNotation.international) {
        return token.raw;
      }
      bool? useFlats;
      if (total != 0) {
        useFlats = shift == 0 && token.preferFlats != null
            // Only the song's {transpose}: follow its sharps/flats rule.
            ? token.preferFlats
            : tokenKey?.transpose(total).usesFlats ??
                  token.preferFlats ??
                  chord.root.preferFlat;
      }
      text = chord.transpose(total, useFlats: useFlats).format(notation);
    }
    return token.parenthesized ? '($text)' : text;
  }

  /// Formats the sounding key for display (e.g. in the header).
  String? formatKey() => soundingKey?.format(notation);
}
