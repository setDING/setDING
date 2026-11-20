/// Time signature (meter) of a song for the beat display and the click
/// (ADR-0026): `{time}` plus setDING's `{x_time_grouping}`.
library;

import 'dart:math' as math;

/// How a song's `{tempo}` is counted: the note value of one beat.
enum BeatUnit {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  dottedHalf,
  dottedQuarter,
  dottedEighth,
}

/// Kind of a meter.
enum MeterKind {
  /// 2/4, 3/4, 4/4, 2/2, …: one beat per note value.
  simple,

  /// 6/8, 9/8, 12/8, …: one beat per dotted note (the felt pulse), three
  /// subdivisions per beat.
  compound,

  /// 5/8, 7/8, 11/8, …: counted in eighths (the note value), accents from
  /// `{x_time_grouping}`.
  odd,
}

/// Clicks between the beats (ADR-0026, #698): a personal choice of the
/// drummer, globally and per song; not part of the meter.
enum Subdivision {
  /// The beats only.
  off,

  /// Eighth notes: two per quarter beat, three per dotted quarter (6/8),
  /// none between the eighths of an odd meter.
  eighths,

  /// Sixteenth notes: four per quarter beat, six per dotted quarter, two
  /// per eighth.
  sixteenths,

  /// Triplets: three per quarter (e.g. a shuffle in 4/4), three per beat of
  /// shorter beats; in compound meters the same as the eighths.
  triplets,
}

/// Accent of a beat within a bar.
enum BeatAccent {
  /// The first beat of the bar.
  bar,

  /// The first beat of a group (`{x_time_grouping}`), not the first of the bar.
  group,

  /// Any other beat.
  none,
}

/// A parsed time signature.
class Meter {
  const Meter._({
    required this.numerator,
    required this.denominator,
    required this.kind,
    required this.groups,
  });

  /// 4/4, used when a song has no or an unreadable `{time}`.
  static const common = Meter._(
    numerator: 4,
    denominator: 4,
    kind: MeterKind.simple,
    groups: [4],
  );

  /// Upper number of the time signature.
  final int numerator;

  /// Lower number of the time signature (a power of two).
  final int denominator;

  final MeterKind kind;

  /// Beats per group, summing to [beatsPerBar]: one group for simple meters
  /// and odd meters without a grouping, one group per beat for compound
  /// meters, `[2, 2, 3]` for 7/8 with `{x_time_grouping: 2+2+3}`.
  final List<int> groups;

  /// Parses a `{time}` value such as `4/4`, `6/8` or `7/8`, with an optional
  /// `{x_time_grouping}` such as `2+2+3` (used for odd meters only, and only
  /// when it adds up to the numerator). Returns null for anything else.
  static Meter? tryParse(String? time, {String? grouping}) {
    if (time == null) return null;
    final match = RegExp(r'^\s*(\d{1,2})\s*/\s*(\d{1,2})\s*$').firstMatch(time);
    if (match == null) return null;
    final n = int.parse(match.group(1)!);
    final d = int.parse(match.group(2)!);
    if (n < 1 || n > 32 || !const {1, 2, 4, 8, 16, 32}.contains(d)) {
      return null;
    }
    if (d >= 8 && n >= 6 && n % 3 == 0) {
      return Meter._(
        numerator: n,
        denominator: d,
        kind: MeterKind.compound,
        groups: List.filled(n ~/ 3, 1),
      );
    }
    if (d >= 8 && n > 3) {
      return Meter._(
        numerator: n,
        denominator: d,
        kind: MeterKind.odd,
        groups: _parseGrouping(grouping, n) ?? [n],
      );
    }
    return Meter._(
      numerator: n,
      denominator: d,
      kind: MeterKind.simple,
      groups: [n],
    );
  }

  static List<int>? _parseGrouping(String? value, int total) {
    if (value == null) return null;
    final parts = value.split('+').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null || p < 1)) return null;
    final groups = parts.cast<int>();
    return groups.fold<int>(0, (a, b) => a + b) == total ? groups : null;
  }

  /// Beats per bar: the clicks of a bar and the dots of the beat display.
  int get beatsPerBar =>
      kind == MeterKind.compound ? numerator ~/ 3 : numerator;

  /// Eighth-note subdivisions per beat (for the optional subdivision of the
  /// click): 2 for quarter beats, 3 for dotted quarters, 1 for eighths;
  /// halves and sixteenths follow the same rule.
  int get subdivisions => switch (kind) {
    MeterKind.compound => 3,
    MeterKind.odd => 1,
    MeterKind.simple => denominator <= 4 ? 8 ~/ denominator : 1,
  };

  /// Clicks per beat for [subdivision] (1 = the beat only).
  int stepsPerBeat(Subdivision subdivision) => switch (subdivision) {
    Subdivision.off => 1,
    Subdivision.eighths => subdivisions,
    Subdivision.sixteenths => math.max(subdivisions, _sixteenthsPerBeat),
    Subdivision.triplets => switch (kind) {
      MeterKind.compound => subdivisions,
      _ => denominator <= 4 ? 3 * (4 ~/ denominator) : 3,
    },
  };

  /// Sixteenths in one beat (at least one).
  int get _sixteenthsPerBeat {
    final perNote = denominator <= 16 ? 16 ~/ denominator : 1;
    return kind == MeterKind.compound ? 3 * perNote : perNote;
  }

  /// The subdivisions that sound different for this meter: [Subdivision.off]
  /// and every other choice whose clicks per beat no earlier choice has
  /// (e.g. no eighths in 7/8, no triplets in 6/8).
  Set<Subdivision> get subdivisionChoices {
    final seen = <int>{};
    return {
      for (final s in Subdivision.values)
        if (seen.add(stepsPerBeat(s))) s,
    };
  }

  /// This meter with [grouping] (`2+2+3`, or the numerator alone for no
  /// groups) instead of its own; itself when [grouping] is null, the meter
  /// is not odd or the grouping does not add up.
  Meter withGrouping(String? grouping) {
    if (grouping == null || kind != MeterKind.odd) return this;
    final groups = _parseGrouping(grouping, numerator);
    if (groups == null) return this;
    return Meter._(
      numerator: numerator,
      denominator: denominator,
      kind: kind,
      groups: groups,
    );
  }

  /// The groupings of an odd meter into twos and threes, in the order
  /// `2+2+3`, `2+3+2`, `3+2+2` (at most [limit]); empty for other meters.
  List<String> groupingChoices({int limit = 24}) {
    if (kind != MeterKind.odd) return const [];
    final result = <String>[];
    void walk(int left, List<int> parts) {
      if (result.length >= limit) return;
      if (left == 0) {
        if (parts.length > 1) result.add(parts.join('+'));
        return;
      }
      for (final part in const [2, 3]) {
        if (part <= left) walk(left - part, [...parts, part]);
      }
    }

    walk(numerator, []);
    return result;
  }

  /// The note value one beat (and one BPM of `{tempo}`) refers to.
  BeatUnit get beatUnit => switch (kind) {
    MeterKind.compound => switch (denominator) {
      8 => BeatUnit.dottedQuarter,
      16 => BeatUnit.dottedEighth,
      _ => BeatUnit.dottedEighth,
    },
    _ => switch (denominator) {
      1 => BeatUnit.whole,
      2 => BeatUnit.half,
      4 => BeatUnit.quarter,
      8 => BeatUnit.eighth,
      _ => BeatUnit.sixteenth,
    },
  };

  /// Accent of every beat of a bar.
  List<BeatAccent> get accents {
    final result = <BeatAccent>[];
    for (final group in groups) {
      for (var i = 0; i < group; i++) {
        result.add(
          result.isEmpty
              ? BeatAccent.bar
              : i == 0 && groups.length > 1 && kind == MeterKind.odd
              ? BeatAccent.group
              : BeatAccent.none,
        );
      }
    }
    return result;
  }

  /// Length of one beat at [bpm] beats per minute.
  Duration beatDuration(num bpm) =>
      Duration(microseconds: (60000000 / bpm).round());

  /// Length of one bar at [bpm].
  Duration barDuration(num bpm) =>
      Duration(microseconds: (60000000 * beatsPerBar / bpm).round());

  /// As written, e.g. `7/8`.
  @override
  String toString() => '$numerator/$denominator';

  /// `2+2+3` for an odd meter with a grouping, null otherwise.
  String? get groupingLabel =>
      kind == MeterKind.odd && groups.length > 1 ? groups.join('+') : null;

  @override
  bool operator ==(Object other) =>
      other is Meter &&
      other.numerator == numerator &&
      other.denominator == denominator &&
      _sameGroups(other.groups, groups);

  @override
  int get hashCode =>
      Object.hash(numerator, denominator, Object.hashAll(groups));

  static bool _sameGroups(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
