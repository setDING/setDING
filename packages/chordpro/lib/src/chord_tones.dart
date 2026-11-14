/// Chord tones (intervals) derived from chord names, for chord diagrams.
library;

import 'chord.dart';

/// Tones of a chord.
class ChordTones {
  const ChordTones({
    required this.root,
    required this.intervals,
    required this.optional,
    this.bass,
  });

  /// Root pitch class (0 = C).
  final int root;

  /// Semitones above the root (0 … 23), sorted, without duplicates.
  final List<int> intervals;

  /// Intervals that may be left out when an instrument has too few
  /// strings (fifth, and the root when a bass note is given).
  final Set<int> optional;

  /// Pitch class of the bass note of a slash chord.
  final int? bass;

  /// Pitch classes of all tones.
  Set<int> get pitchClasses => {
    for (final i in intervals) (root + i) % 12,
    ?bass,
  };

  /// Pitch classes that must be played.
  Set<int> get required => {
    for (final i in intervals)
      if (!optional.contains(i)) (root + i) % 12,
    ?bass,
  };

  /// Pitch class of the lowest note.
  int get lowest => bass ?? root;
}

/// Derives the tones of [chord] from its suffix, e.g. `m7`, `sus4`,
/// `maj7`, `7(b9)`, `add9`, `dim7`, `m7b5`, `6/9`, `13`. Unknown parts are
/// ignored, so every chord yields at least a triad.
ChordTones chordTones(Chord chord) {
  var s = chord.suffix.replaceAll(RegExp(r'[()\s,]'), '');
  final tones = <int>{0};
  int? third = 4;
  int? fifth = 7;
  final extra = <int>{};

  bool take(String prefix) {
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length);
      return true;
    }
    return false;
  }

  // Quality.
  if (take('maj') ||
      take('Maj') ||
      take('M') ||
      take('Δ') ||
      take('△') ||
      take('^')) {
    // Major seventh family: "maj" alone means maj7.
    final number = RegExp(r'^(7|9|11|13)').firstMatch(s);
    if (number != null) {
      s = s.substring(number.group(0)!.length);
      extra.add(11);
      _extensions(int.parse(number.group(0)!), extra, includeSeventh: false);
    } else {
      extra.add(11);
    }
  } else if (take('m7b5') || take('ø7') || take('ø') || take('-7b5')) {
    third = 3;
    fifth = 6;
    extra.add(10);
  } else if (take('dim7') || take('°7') || take('o7')) {
    third = 3;
    fifth = 6;
    extra.add(9);
  } else if (take('dim') || take('°') || take('o')) {
    third = 3;
    fifth = 6;
  } else if (take('aug') || take('+')) {
    fifth = 8;
  } else if (take('min') || take('mi') || take('m') || take('-')) {
    third = 3;
    if (take('maj7') || take('M7') || take('Δ')) extra.add(11);
  }

  // Numbers and alterations.
  while (s.isNotEmpty) {
    if (take('sus2')) {
      third = null;
      extra.add(2);
    } else if (take('sus4') || take('sus')) {
      third = null;
      extra.add(5);
    } else if (take('add9') || take('add2') || take('2')) {
      extra.add(14);
    } else if (take('add11') || take('add4') || take('4')) {
      extra.add(5);
    } else if (take('6/9') || take('69')) {
      extra.addAll({9, 14});
    } else if (take('13')) {
      _extensions(13, extra);
    } else if (take('11')) {
      _extensions(11, extra);
    } else if (take('9')) {
      _extensions(9, extra);
    } else if (take('7')) {
      extra.add(10);
    } else if (take('6')) {
      extra.add(9);
    } else if (take('5')) {
      // Power chord: no third.
      third = null;
    } else if (take('b5') || take('-5')) {
      fifth = 6;
    } else if (take('#5') || take('+5')) {
      fifth = 8;
    } else if (take('b9')) {
      extra.add(13);
    } else if (take('#9')) {
      extra.add(15);
    } else if (take('#11')) {
      extra.add(18);
    } else if (take('b13')) {
      extra.add(20);
    } else if (take('no3')) {
      third = null;
    } else if (take('no5')) {
      fifth = null;
    } else {
      s = s.substring(1); // Unknown character.
    }
  }

  tones.addAll({?third, ?fifth, ...extra});
  final sorted = tones.toList()..sort();
  final bass = chord.bass?.pitch;
  return ChordTones(
    root: chord.root.pitch,
    intervals: sorted,
    optional: {
      if (fifth == 7 && sorted.length > 3) 7,
      if (bass != null && bass != chord.root.pitch && sorted.length > 3) 0,
      // 11 and 13 chords: the 9th and 11th are often left out.
      if (extra.contains(21)) 17,
      if (extra.contains(21) || extra.contains(17)) 14,
    },
    bass: bass == chord.root.pitch ? null : bass,
  );
}

void _extensions(int number, Set<int> extra, {bool includeSeventh = true}) {
  if (includeSeventh) extra.add(10);
  if (number >= 9) extra.add(14);
  if (number >= 11) extra.add(17);
  if (number >= 13) extra.add(21);
}
