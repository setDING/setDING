/// A key suggested from the chords of a song without `{key}` (#919,
/// ADR-0056). Only a suggestion: a person confirms it before it is written,
/// and it is never used in place of a missing `{key}`.
library;

import 'chord.dart';
import 'grid.dart';
import 'song.dart';

/// The key that fits the chords of a song best, and the runner-up when it
/// fits nearly as well (typically the relative minor or major).
class KeyGuess {
  const KeyGuess(this.key, {this.alternative});

  final Key key;

  /// A second key that fits almost as well; null when [key] is clear.
  final Key? alternative;

  @override
  bool operator ==(Object other) =>
      other is KeyGuess && other.key == key && other.alternative == alternative;

  @override
  int get hashCode => Object.hash(key, alternative);

  @override
  String toString() => alternative == null ? '$key' : '$key (or $alternative)';
}

/// The fewest different chords that make a guess worthwhile: two chords fit
/// too many keys.
const minChordsForKeyGuess = 3;

/// The runner-up is offered when it scores at least this share of the best.
const _alternativeShare = 0.75;

/// Extra weight of the tonic chord as first or last chord, as a share of
/// the number of chords: songs usually start and end on the tonic.
const _tonicBonus = 0.3;

/// Guesses the key of [song] from its chords; null when there are too few
/// chords (see [minChordsForKeyGuess]).
///
/// Only chords before the first `{key}` count (chords after it belong to the
/// key it names), so a song with `{key}` at the top gets no guess. The
/// chords are taken as written: `{capo}` and `{transpose}` do not change
/// them, as `{key}` names the key of the written chords.
///
/// Each of the 24 keys scores every chord by its degree in that key: the
/// tonic, subdominant and dominant most, the other diatonic chords less and
/// the usual borrowed chords (`bVII` in major, the major `V` in minor) a
/// little. The tonic chord as first and as last chord adds a bonus.
KeyGuess? guessKey(Song song) {
  final chords = _chordsBeforeKey(song);
  final distinct = {for (final c in chords) (c.root.pitch, _quality(c))};
  if (distinct.length < minChordsForKeyGuess) return null;

  final candidates = <(Key, double)>[];
  for (final minor in [false, true]) {
    for (var tonic = 0; tonic < 12; tonic++) {
      final fits = minor ? _minorFits : _majorFits;
      var score = 0.0;
      for (final c in chords) {
        score += fits[(_quality(c), (c.root.pitch - tonic) % 12)] ?? 0;
      }
      bool isTonic(Chord c) =>
          c.root.pitch == tonic && _quality(c) == (minor ? _Q.minor : _Q.major);
      final bonus = _tonicBonus * chords.length;
      if (isTonic(chords.first)) score += bonus;
      if (isTonic(chords.last)) score += bonus;
      if (score > 0) {
        candidates.add((
          Key(const Note(0), minor: minor).transpose(tonic),
          score,
        ));
      }
    }
  }
  if (candidates.isEmpty) return null;
  // Stable on ties: major before minor, then by pitch from C.
  candidates.sort((a, b) => b.$2.compareTo(a.$2));
  final (best, bestScore) = candidates.first;
  final runnerUp = candidates.length > 1 ? candidates[1] : null;
  return KeyGuess(
    best,
    alternative:
        runnerUp != null && runnerUp.$2 >= bestScore * _alternativeShare
        ? runnerUp.$1
        : null,
  );
}

/// The parsed chords of [song] in order, up to the first `{key}`.
List<Chord> _chordsBeforeKey(Song song) {
  final result = <Chord>[];
  // False once a chord under a `{key}` is reached.
  bool add(ChordToken? token) {
    if (token == null || token.isAnnotation) return true;
    if (token.key != null) return false;
    if (token.chord case final chord?) result.add(chord);
    return true;
  }

  for (final section in song.sections) {
    for (final line in section.lines) {
      final tokens = switch (line) {
        LyricLine(:final segments) => [for (final s in segments) s.chord],
        GridLine(:final row) => [
          for (final t in row.tokens)
            if (t is GridChords) ...t.chords,
        ],
        _ => const <ChordToken?>[],
      };
      for (final t in tokens) {
        if (!add(t)) return result;
      }
    }
  }
  return result;
}

/// The chord quality as far as the key is concerned.
enum _Q { major, minor, diminished }

_Q _quality(Chord chord) => switch (chord.parsedSuffix?.quality) {
  ChordQuality.diminished || ChordQuality.halfDiminished => _Q.diminished,
  _ when chord.isMinor => _Q.minor,
  _ => _Q.major,
};

/// How well a chord of a quality fits on a degree (semitones above the
/// tonic) of a major key.
const _majorFits = {
  (_Q.major, 0): 3.0, // I
  (_Q.minor, 2): 1.5, // ii
  (_Q.minor, 4): 1.0, // iii
  (_Q.major, 5): 2.0, // IV
  (_Q.major, 7): 2.5, // V
  (_Q.minor, 9): 1.5, // vi
  (_Q.diminished, 11): 1.0, // vii°
  (_Q.major, 10): 1.0, // bVII (Mixolydian, rock)
  (_Q.major, 2): 0.5, // II (secondary dominant)
  (_Q.minor, 5): 0.5, // iv (borrowed from minor)
};

/// How well a chord of a quality fits on a degree of a minor key.
const _minorFits = {
  (_Q.minor, 0): 3.0, // i
  (_Q.diminished, 2): 1.0, // ii°
  (_Q.major, 3): 1.5, // bIII
  (_Q.minor, 5): 2.0, // iv
  (_Q.minor, 7): 1.0, // v
  (_Q.major, 7): 2.0, // V (harmonic minor)
  (_Q.major, 8): 1.5, // bVI
  (_Q.major, 10): 1.5, // bVII
  (_Q.major, 5): 0.5, // IV (Dorian)
};
