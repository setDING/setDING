/// Chord fingerings for fretted instruments and keyboard voicings
/// (ADR-0012, phase 4). Fingerings are generated from the chord tones, so
/// no external chord library is needed.
library;

import 'chord.dart';
import 'chord_tones.dart';
import 'diagrams.dart';

/// A fretted string instrument.
class StringInstrument {
  const StringInstrument(
    this.name,
    this.tuning, {
    this.maxMuted = 2,
    this.rootInBass = true,
  });

  final String name;

  /// Open string pitches as MIDI numbers, from the lowest string.
  final List<int> tuning;

  /// Strings that may be muted (only at the low end).
  final int maxMuted;

  /// Whether the lowest note must be the root (or the slash bass). Not for
  /// re-entrant tunings such as the ukulele, where chords are inverted.
  final bool rootInBass;

  int get strings => tuning.length;

  static const guitar = StringInstrument('guitar', [40, 45, 50, 55, 59, 64]);

  /// Ukulele in re-entrant G-C-E-A tuning.
  static const ukulele = StringInstrument(
    'ukulele',
    [67, 60, 64, 69],
    maxMuted: 0,
    rootInBass: false,
  );

  static const bass = StringInstrument('bass', [28, 33, 38, 43], maxMuted: 2);
}

/// A generated fingering: frets per string from the lowest (`null` =
/// muted, `0` = open), absolute fret numbers.
class Fingering {
  const Fingering(this.frets);

  final List<int?> frets;

  /// First fret to show in a diagram (1 for open positions).
  int get baseFret {
    final fretted = [
      for (final f in frets)
        if (f != null && f > 0) f,
    ];
    if (fretted.isEmpty) return 1;
    final highest = fretted.reduce((a, b) => a > b ? a : b);
    if (highest <= 4) return 1;
    return fretted.reduce((a, b) => a < b ? a : b);
  }

  /// As a [ChordDefinition] (frets relative to [baseFret]).
  ChordDefinition toDefinition(String name) {
    final base = baseFret;
    return ChordDefinition(
      name: name,
      baseFret: base,
      frets: [
        for (final f in frets)
          f == null
              ? null
              : f == 0
              ? 0
              : f - base + 1,
      ],
    );
  }
}

final _cache = <String, Fingering?>{};

/// Finds a playable fingering of [chord] on [instrument], preferring low
/// positions, open strings, small stretches and few muted strings. Returns
/// null if no fingering with all required tones exists within 12 frets.
Fingering? fingeringFor(Chord chord, StringInstrument instrument) {
  final cacheKey =
      '${instrument.name}:${chord.root.pitch}:${chord.suffix}:'
      '${chord.bass?.pitch}';
  return _cache.putIfAbsent(cacheKey, () => _search(chord, instrument));
}

Fingering? _search(Chord chord, StringInstrument instrument) {
  final tones = chordTones(chord);
  final allowed = tones.pitchClasses;
  // On a bass only the lowest note matters, plus one or two chord tones.
  final isBass = instrument.name == 'bass';
  final required = isBass
      ? {tones.lowest, (tones.root + 7) % 12}
      : tones.required;
  final strings = instrument.strings;

  Fingering? best;
  var bestScore = double.infinity;
  final frets = List<int?>.filled(strings, null);

  void evaluate() {
    final sounding = <int>[];
    var lowestPitch = 1 << 30;
    var lowestString = -1;
    for (var s = 0; s < strings; s++) {
      final f = frets[s];
      if (f == null) continue;
      final pitch = instrument.tuning[s] + f;
      sounding.add(pitch % 12);
      if (pitch < lowestPitch) {
        lowestPitch = pitch;
        lowestString = s;
      }
    }
    if (lowestString < 0) return;
    if (!sounding.toSet().containsAll(required)) return;
    if (instrument.rootInBass && lowestPitch % 12 != tones.lowest) return;
    // Muted strings only at the low end.
    var muted = 0;
    for (var s = 0; s < strings && frets[s] == null; s++) {
      muted++;
    }
    if (muted > instrument.maxMuted) return;
    if (frets.skip(muted).any((f) => f == null)) return;
    if (isBass && sounding.length > 2) return;

    final fretted = [
      for (final f in frets)
        if (f != null && f > 0) f,
    ];
    final low = fretted.isEmpty ? 0 : fretted.reduce((a, b) => a < b ? a : b);
    final high = fretted.isEmpty ? 0 : fretted.reduce((a, b) => a > b ? a : b);
    final span = high - low;
    if (span > 3) return;
    // Fingers needed: a barre on the lowest fret counts as one finger.
    final atLow = fretted.where((f) => f == low).length;
    final fingers = fretted.length - (atLow > 1 ? atLow - 1 : 0);
    if (fingers > 4) return;

    final score =
        low * 1.2 + // prefer low positions
        span * 0.8 +
        fingers * 0.3 +
        muted * (isBass ? 0 : 1.5) -
        frets.where((f) => f == 0).length * 0.4 + // open strings sound full
        (sounding.length < strings - muted ? 0 : 0) +
        (tones.pitchClasses.length - sounding.toSet().length) * 1.0;
    if (score < bestScore) {
      bestScore = score;
      best = Fingering([...frets]);
    }
  }

  // Each window covers 4 frets starting at `start`; open strings always
  // allowed.
  for (var start = 1; start <= 12; start++) {
    void place(int s) {
      if (s == strings) {
        evaluate();
        return;
      }
      final open = instrument.tuning[s] % 12;
      final options = <int?>[null];
      if (allowed.contains(open)) options.add(0);
      for (var f = start; f < start + 4; f++) {
        if (allowed.contains((instrument.tuning[s] + f) % 12)) options.add(f);
      }
      for (final option in options) {
        frets[s] = option;
        place(s + 1);
      }
      frets[s] = null;
    }

    place(0);
    // A good open-position fingering is not beaten by higher positions.
    if (best != null && start >= 3 && bestScore < start * 1.2) break;
  }
  return best;
}

/// Keyboard voicing of [chord]: MIDI notes in root position around C4,
/// with the bass note of a slash chord below.
List<int> keyboardVoicing(Chord chord) {
  final tones = chordTones(chord);
  final root = 60 + tones.root;
  final notes = <int>[
    if (tones.bass != null) 48 + tones.bass!,
    for (final i in tones.intervals) root + i,
  ];
  return notes;
}
