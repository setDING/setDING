import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../util/log.dart';

/// Audio output for the click (ADR-0026). The time is the engine's own
/// clock: a bar scheduled for a time starts exactly then, sample-accurate.
abstract class ClickOutput {
  /// Prepares the audio device; false if there is no audio (e.g. no
  /// device, or the web client).
  Future<bool> ensureReady();

  /// The engine time of the sound now reaching the speakers or headphones,
  /// smoothed between audio buffers.
  Duration now();

  /// Loads one rendered bar ([wav]); the result is passed to [play].
  Future<Object> load(Uint8List wav);

  /// Plays [bar] in a loop from [at] (engine time) on, until [until] if
  /// given; returns a handle for [stopAt] and [setVolume].
  Object play(
    Object bar,
    Duration at, {
    required double volume,
    Duration? until,
  });

  /// Stops [handle] at [at] (engine time); a time in the past stops it now.
  void stopAt(Object handle, Duration at);

  void setVolume(Object handle, double volume);

  /// Frees a loaded bar.
  Future<void> unload(Object bar);
}

/// [ClickOutput] on SoLoud (`flutter_soloud`, MIT; SoLoud zlib).
class SoLoudClickOutput implements ClickOutput {
  SoLoudClickOutput({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  static const _log = Log('click');

  final SoLoud _soloud;
  Future<bool>? _ready;
  final _wall = Stopwatch()..start();
  Duration _lastEngine = Duration.zero;
  Duration _lastEngineWall = Duration.zero;
  Duration _lastReturned = Duration.zero;
  var _loads = 0;

  @override
  Future<bool> ensureReady() => _ready ??= _init();

  Future<bool> _init() async {
    if (kIsWeb) return false;
    try {
      if (!_soloud.isInitialized) await _soloud.init(sampleRate: 44100);
      return true;
    } catch (e) {
      _log.warning('No audio output for the click', e);
      _ready = null;
      return false;
    }
  }

  @override
  Duration now() {
    final engine = _soloud.getPlayheadTime();
    final wall = _wall.elapsed;
    if (engine != _lastEngine) {
      _lastEngine = engine;
      _lastEngineWall = wall;
    }
    // The engine clock moves in steps of an audio buffer; in between, the
    // wall clock fills the gap. It never runs backwards.
    var t = engine + (wall - _lastEngineWall);
    if (t < _lastReturned) t = _lastReturned;
    return _lastReturned = t;
  }

  @override
  Future<Object> load(Uint8List wav) =>
      _soloud.loadMem('click-${_loads++}.wav', wav);

  @override
  Object play(
    Object bar,
    Duration at, {
    required double volume,
    Duration? until,
  }) => _Handle(
    _soloud.playScheduled(
      bar as AudioSource,
      at,
      duration: until == null ? null : until - at,
      volume: volume,
      looping: true,
    ),
  );

  @override
  void stopAt(Object handle, Duration at) =>
      _soloud.stopScheduled((handle as _Handle).handle, at);

  @override
  void setVolume(Object handle, double volume) =>
      _soloud.setVolume((handle as _Handle).handle, volume);

  @override
  Future<void> unload(Object bar) => _soloud.disposeSource(bar as AudioSource);
}

/// A [SoundHandle] (an extension type) as an object.
class _Handle {
  const _Handle(this.handle);

  final SoundHandle handle;
}
