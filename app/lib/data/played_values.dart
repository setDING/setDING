import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/foundation.dart';

/// How a song was played at a gig (ADR-0046): the key, tempo and sequence
/// resolved from the song, the band arrangement and the set item, frozen in
/// the set item once the gig date is reached (`played` in `setlists.items`).
@immutable
class PlayedValues {
  const PlayedValues({this.key, this.tempo, this.sequence});

  /// Reads the JSON form; unknown or malformed values are left out.
  factory PlayedValues.fromJson(Map<String, dynamic> json) => PlayedValues(
    key: json['key'] is String ? json['key'] as String : null,
    tempo: json['tempo'] is num ? (json['tempo'] as num).toInt() : null,
    sequence: json['sequence'] is String ? json['sequence'] as String : null,
  );

  /// The sounding key in international notation (personal transposition and
  /// capo are not part of it); null for a song without a key.
  final String? key;

  /// Beats per minute; null when neither the band nor the song has a tempo.
  final int? tempo;

  /// The song sequence (`{x_sequence}` syntax); null when there is none.
  final String? sequence;

  bool get isEmpty => key == null && tempo == null && sequence == null;

  cp.Key? get parsedKey => key == null ? null : cp.Key.tryParse(key!);

  /// The JSON form, without unknown values.
  Map<String, dynamic> toJson() => {
    'key': ?key,
    'tempo': ?tempo,
    'sequence': ?sequence,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayedValues &&
      other.key == key &&
      other.tempo == tempo &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(key, tempo, sequence);

  @override
  String toString() => 'PlayedValues(${toJson()})';
}
