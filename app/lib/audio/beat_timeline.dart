import 'package:chordpro/chordpro.dart';

import 'click_sound.dart';

/// Where the beat stands at a moment (ADR-0026).
class BeatPosition {
  const BeatPosition({
    required this.bar,
    required this.beat,
    required this.phase,
    required this.meter,
    required this.bpm,
    required this.countInBars,
  });

  /// Bar since the start, counting the count-in bars (0 is the first).
  final int bar;

  /// Beat within the bar, 0 is the 1.
  final int beat;

  /// How far the current beat has gone, 0 (on the beat) to 1.
  final double phase;
  final Meter meter;
  final int bpm;
  final int countInBars;

  /// Whether the bar is one of the count-in bars.
  bool get inCountIn => bar < countInBars;

  /// Bar of the song after the count-in (0 is its first bar), negative
  /// during the count-in.
  int get songBar => bar - countInBars;

  BeatAccent get accent => meter.accents[beat];

  @override
  String toString() => 'BeatPosition(bar $bar, beat $beat, $phase)';
}

/// A stretch of steady tempo, from [start] on, beginning at bar [firstBar].
class _Segment {
  const _Segment(this.start, this.bpm, this.firstBar);

  final Duration start;
  final int bpm;
  final int firstBar;
}

/// The beat over time: a meter and a tempo that can change at bar lines.
/// Pure arithmetic on a clock that the caller provides (the audio engine's
/// clock while the click plays, otherwise a monotonic clock), so the beat
/// never drifts: every position is computed from the start, not summed up.
class BeatTimeline {
  BeatTimeline({
    required this.meter,
    required int bpm,
    required Duration start,
    this.countInBars = 0,
  }) : _segments = [_Segment(start, bpm, 0)];

  final Meter meter;
  final int countInBars;
  final List<_Segment> _segments;

  /// Tempo of the latest segment.
  int get bpm => _segments.last.bpm;

  /// When the first bar starts.
  Duration get start => _segments.first.start;

  /// Length of one bar at [bpm], exactly as long as the rendered click bar
  /// (whole samples), so the display and the looped click stay together.
  Duration barLength(int bpm) => Duration(
    microseconds: (barSamples(meter, bpm) * 1000000 / clickSampleRate).round(),
  );

  _Segment _segmentAt(Duration time) {
    for (var i = _segments.length - 1; i > 0; i--) {
      if (_segments[i].start <= time) return _segments[i];
    }
    return _segments.first;
  }

  /// The beat at [time], or null before the start.
  BeatPosition? positionAt(Duration time) {
    if (time < start) return null;
    final segment = _segmentAt(time);
    final bars =
        (time - segment.start).inMicroseconds /
        barLength(segment.bpm).inMicroseconds;
    final whole = bars.floor();
    final beats = (bars - whole) * meter.beatsPerBar;
    final beat = beats.floor().clamp(0, meter.beatsPerBar - 1);
    return BeatPosition(
      bar: segment.firstBar + whole,
      beat: beat,
      phase: (beats - beat).clamp(0.0, 1.0),
      meter: meter,
      bpm: segment.bpm,
      countInBars: countInBars,
    );
  }

  /// When [bar] starts (bars counted from the start, count-in included).
  Duration timeOfBar(int bar) {
    var segment = _segments.first;
    for (final s in _segments) {
      if (s.firstBar <= bar) segment = s;
    }
    return segment.start + barLength(segment.bpm) * (bar - segment.firstBar);
  }

  /// The first bar line at or after [time].
  int nextBarAt(Duration time) {
    final position = positionAt(time);
    if (position == null) return 0;
    final barStart = timeOfBar(position.bar);
    return barStart == time ? position.bar : position.bar + 1;
  }

  /// Changes the tempo from the next bar line after [now] on; returns the
  /// time of that bar line. Changes not yet reached are replaced.
  Duration changeTempo(int bpm, {required Duration now}) {
    final bar = nextBarAt(now);
    final at = timeOfBar(bar);
    _segments.removeWhere((s) => s.firstBar >= bar && s.start > now);
    _segments.add(_Segment(at, bpm, bar));
    return at;
  }
}
