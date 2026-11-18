import 'dart:async';

import 'package:chordpro/chordpro.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../util/log.dart';
import 'beat_timeline.dart';
import 'click_output.dart';
import 'click_sound.dart';

export 'beat_timeline.dart' show BeatPosition;

/// How the click sounds (ADR-0026), from the settings.
@immutable
class ClickConfig {
  const ClickConfig({
    this.enabled = false,
    this.volume = 0.8,
    this.sound = ClickSound.click,
    this.accent = true,
    this.subdivision = false,
    this.latency = Duration.zero,
  });

  factory ClickConfig.of(AppSettings s) => ClickConfig(
    enabled: s.playClick,
    volume: s.clickVolume,
    sound: s.clickSound,
    accent: s.clickAccent,
    subdivision: s.clickSubdivision,
    latency: Duration(milliseconds: s.audioLatencyMs),
  );

  final bool enabled;
  final double volume;
  final ClickSound sound;
  final bool accent;
  final bool subdivision;

  /// Delay of the audio output; the display is shifted by it.
  final Duration latency;
}

/// Beat and click of live mode (ADR-0026). The audio engine is the clock
/// while the click plays: one bar is rendered and looped by the engine, and
/// the display reads the engine's time. Without a click (or without audio)
/// a monotonic clock takes its place. Either way, positions are computed
/// from the start, so the beat never drifts and a slow frame only delays
/// the drawing.
class Metronome {
  Metronome({
    ClickOutput? output,
    Duration Function()? wallClock,
    this.readyTimeout = const Duration(seconds: 3),
  }) : _output = output, // ignore: prefer_initializing_formals
       _wallClock = wallClock ?? _defaultWallClock();

  static const _log = Log('metronome');

  /// Time between asking for the start and the first beat, so the first
  /// click is never scheduled in the past.
  static const lead = Duration(milliseconds: 120);

  static const minBpm = 20;
  static const maxBpm = 400;

  /// How long the start waits for the audio output. Some devices never
  /// answer (the audio engine hangs while it opens the device); the beat
  /// then runs without the click instead of not at all.
  final Duration readyTimeout;

  static Duration Function() _defaultWallClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final ClickOutput? _output;
  final Duration Function() _wallClock;

  /// Whether a beat runs (also during the count-in).
  final running = ValueNotifier<bool>(false);

  /// The current tempo while running (changed on stage), else null.
  final tempo = ValueNotifier<int?>(null);

  /// Whether the click was asked for but there is no audio output.
  final clickUnavailable = ValueNotifier<bool>(false);

  BeatTimeline? _timeline;
  ClickConfig _config = const ClickConfig();
  bool _audio = false;
  bool _countInOnly = false;
  Object? _bar;
  Object? _handle;
  var _generation = 0;

  Duration _clock() => _audio ? _output!.now() : _wallClock();

  /// The timeline while running, for tests and the latency calibration.
  @visibleForTesting
  BeatTimeline? get timeline => _timeline;

  /// Starts the beat with [countInBars] count-in bars. With [countInOnly]
  /// it stops by itself after the count-in.
  Future<void> start({
    required Meter meter,
    required int bpm,
    int countInBars = 0,
    bool countInOnly = false,
    ClickConfig config = const ClickConfig(),
  }) async {
    await stop();
    final generation = ++_generation;
    _config = config;
    _countInOnly = countInOnly && countInBars > 0;
    var audio = false;
    if (config.enabled && _output != null) {
      audio = await _output.ensureReady().timeout(
        readyTimeout,
        onTimeout: () {
          _log.warning('The audio output did not answer; beat without click');
          return false;
        },
      );
      clickUnavailable.value = !audio;
    } else {
      clickUnavailable.value = false;
    }
    if (generation != _generation) return;
    _audio = audio;
    final clamped = bpm.clamp(minBpm, maxBpm);
    final timeline = BeatTimeline(
      meter: meter,
      bpm: clamped,
      start: _clock() + lead,
      countInBars: countInBars,
    );
    _timeline = timeline;
    tempo.value = clamped;
    running.value = true;
    if (audio) {
      try {
        final bar = await _output!.load(_render(meter, clamped));
        if (generation != _generation) {
          unawaited(_output.unload(bar));
          return;
        }
        _bar = bar;
        _handle = _output.play(
          bar,
          timeline.start,
          volume: config.volume,
          until: _end(timeline),
        );
      } catch (e) {
        _log.warning('Cannot play the click', e);
        clickUnavailable.value = true;
      }
    }
  }

  Duration? _end(BeatTimeline timeline) =>
      _countInOnly ? timeline.timeOfBar(timeline.countInBars) : null;

  Uint8List _render(Meter meter, int bpm) => renderClickBar(
    meter,
    bpm,
    sound: _config.sound,
    accent: _config.accent,
    subdivision: _config.subdivision,
  );

  /// Changes the tempo from the next bar line on (tempo on stage, only
  /// until live mode is left).
  Future<void> setTempo(int bpm) async {
    final timeline = _timeline;
    if (timeline == null) return;
    final clamped = bpm.clamp(minBpm, maxBpm);
    final generation = _generation;
    final at = timeline.changeTempo(clamped, now: _clock());
    tempo.value = clamped;
    final handle = _handle;
    final oldBar = _bar;
    if (!_audio || handle == null) return;
    try {
      final bar = await _output!.load(_render(timeline.meter, clamped));
      if (generation != _generation) {
        unawaited(_output.unload(bar));
        return;
      }
      _output.stopAt(handle, at);
      _bar = bar;
      _handle = _output.play(
        bar,
        at,
        volume: _config.volume,
        until: _end(timeline),
      );
      if (oldBar != null) _unloadLater(oldBar, at);
    } catch (e) {
      _log.warning('Cannot change the tempo of the click', e);
    }
  }

  /// Bars replaced by a tempo change, freed once their end has passed
  /// (at the next change or the stop), without timers.
  final _retired = <({Object bar, Duration until})>[];

  void _unloadLater(Object bar, Duration at) {
    final now = _clock();
    _retired.removeWhere((r) {
      if (r.until > now) return false;
      unawaited(_output!.unload(r.bar).catchError((_) {}));
      return true;
    });
    _retired.add((bar: bar, until: at));
  }

  /// Changes the volume of a running click.
  void setVolume(double volume) {
    _config = ClickConfig(
      enabled: _config.enabled,
      volume: volume,
      sound: _config.sound,
      accent: _config.accent,
      subdivision: _config.subdivision,
      latency: _config.latency,
    );
    final handle = _handle;
    if (_audio && handle != null) _output!.setVolume(handle, volume);
  }

  /// Stops the beat and the click at once.
  Future<void> stop() async {
    _generation++;
    final handle = _handle;
    final bar = _bar;
    _handle = null;
    _bar = null;
    _timeline = null;
    running.value = false;
    tempo.value = null;
    if (_audio && handle != null) {
      try {
        _output!.stopAt(handle, Duration.zero);
        if (bar != null) await _output.unload(bar);
        for (final r in _retired) {
          await _output.unload(r.bar);
        }
        _retired.clear();
      } catch (e) {
        _log.warning('Cannot stop the click', e);
      }
    }
    _audio = false;
  }

  /// The beat as it is heard now (the audio delay taken into account), or
  /// null while not running or before the first beat. Ends the beat after
  /// the count-in when only the count-in plays.
  BeatPosition? position() {
    final timeline = _timeline;
    if (timeline == null) return null;
    final now = _clock();
    final end = _end(timeline);
    if (end != null &&
        now >= end + (_audio ? _config.latency : Duration.zero)) {
      unawaited(stop());
      return null;
    }
    return timeline.positionAt(
      now - (_audio ? _config.latency : Duration.zero),
    );
  }

  /// Offset of a tap (by the clock of the beat, not shifted by the audio
  /// delay) from the nearest beat, for the latency calibration: positive
  /// when the tap comes after the beat.
  Duration? tapOffset() {
    final timeline = _timeline;
    if (timeline == null) return null;
    final now = _clock();
    final p = timeline.positionAt(now);
    if (p == null) return null;
    final beat = timeline.barLength(p.bpm) * (1 / p.meter.beatsPerBar);
    final sinceBeat = beat * p.phase;
    return p.phase <= 0.5 ? sinceBeat : sinceBeat - beat;
  }

  void dispose() {
    unawaited(stop());
    running.dispose();
    tempo.dispose();
    clickUnavailable.dispose();
  }
}

/// The audio delay from the tap offsets of a calibration ([Metronome.tapOffset]):
/// the median, between 0 and [AppSettings.maxAudioLatencyMs]; null with
/// fewer than four taps.
int? latencyFromTaps(List<Duration> offsets) {
  if (offsets.length < 4) return null;
  final sorted = [...offsets.map((d) => d.inMicroseconds)]..sort();
  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) ~/ 2;
  return (median / 1000).round().clamp(0, AppSettings.maxAudioLatencyMs);
}

/// The metronome of the app; tests replace its audio output.
final clickOutputProvider = Provider<ClickOutput?>(
  (ref) => SoLoudClickOutput(),
);

final metronomeProvider = Provider<Metronome>((ref) {
  final metronome = Metronome(output: ref.watch(clickOutputProvider));
  ref.onDispose(metronome.dispose);
  return metronome;
});
