/// The time of the audio engine, smoothed between audio buffers
/// (ADR-0026, #545).
///
/// The engine's playhead moves in steps of an audio buffer; in between, a
/// wall clock fills the gap. The gap is filled for at most
/// [maxExtrapolation]: while the engine stands (not started yet, or its
/// device stopped after idling), the time stands too instead of running
/// ahead of the engine, so a click scheduled from it is never scheduled
/// in the future by the time the engine stood.
class EngineClock {
  EngineClock({
    required Duration Function() engine,
    Duration Function()? wall,
    this.maxExtrapolation = const Duration(milliseconds: 100),
  }) : _engine = engine, // ignore: prefer_initializing_formals
       _wall = wall ?? _stopwatch();

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// How far the time runs ahead of the last engine time: about two audio
  /// buffers (2048 frames at 44.1 kHz).
  final Duration maxExtrapolation;

  final Duration Function() _engine;
  final Duration Function() _wall;
  Duration? _lastEngine;
  Duration _lastEngineWall = Duration.zero;
  Duration _lastReturned = Duration.zero;

  /// The engine time now. It never runs backwards until [reset].
  Duration now() {
    final engine = _engine();
    final wall = _wall();
    if (engine != _lastEngine) {
      _lastEngine = engine;
      _lastEngineWall = wall;
    }
    var gap = wall - _lastEngineWall;
    if (gap > maxExtrapolation) gap = maxExtrapolation;
    var t = engine + gap;
    if (t < _lastReturned) t = _lastReturned;
    return _lastReturned = t;
  }

  /// Takes the engine time as it is now as the new reference, e.g. after
  /// the engine was started again; nothing may be scheduled from the old
  /// time any more.
  void reset() {
    _lastEngine = _engine();
    _lastEngineWall = _wall();
    _lastReturned = _lastEngine!;
  }
}
