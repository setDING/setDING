import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chordpro/chordpro.dart';

import '../settings/settings.dart' show ClickSound;

/// Sample rate of the rendered click and of the audio engine.
const clickSampleRate = 44100;

/// How strongly a click sounds.
enum ClickLevel { bar, group, beat, subdivision }

/// One click of a bar: where it starts (in samples) and how strong it is.
typedef ClickHit = ({int offset, ClickLevel level});

/// Length of one bar in samples at [bpm].
int barSamples(Meter meter, int bpm, {int sampleRate = clickSampleRate}) =>
    (sampleRate * 60 * meter.beatsPerBar / bpm).round();

/// The clicks of one bar (ADR-0026): every beat, accented on the 1 (and on
/// the groups of an odd meter) when [accent] is on, and quieter
/// [subdivision] clicks in between.
List<ClickHit> clickHits(
  Meter meter,
  int bpm, {
  bool accent = true,
  Subdivision subdivision = Subdivision.off,
  int sampleRate = clickSampleRate,
}) {
  final total = barSamples(meter, bpm, sampleRate: sampleRate);
  final beats = meter.beatsPerBar;
  final steps = meter.stepsPerBeat(subdivision);
  final accents = meter.accents;
  return [
    for (var beat = 0; beat < beats; beat++)
      for (var step = 0; step < steps; step++)
        (
          offset: (total * (beat * steps + step) / (beats * steps)).round(),
          level: step > 0
              ? ClickLevel.subdivision
              : !accent
              ? ClickLevel.beat
              : switch (accents[beat]) {
                  BeatAccent.bar => ClickLevel.bar,
                  BeatAccent.group => ClickLevel.group,
                  BeatAccent.none => ClickLevel.beat,
                },
        ),
  ];
}

/// One bar of clicks as a mono 16-bit WAV file, to be looped by the audio
/// engine: the engine keeps the time, so the click never wavers.
Uint8List renderClickBar(
  Meter meter,
  int bpm, {
  ClickSound sound = ClickSound.click,
  bool accent = true,
  Subdivision subdivision = Subdivision.off,
  int sampleRate = clickSampleRate,
}) {
  final total = barSamples(meter, bpm, sampleRate: sampleRate);
  final mix = Float64List(total);
  for (final hit in clickHits(
    meter,
    bpm,
    accent: accent,
    subdivision: subdivision,
    sampleRate: sampleRate,
  )) {
    final samples = _hitSamples(sound, hit.level, sampleRate);
    final end = math.min(total, hit.offset + samples.length);
    for (var i = hit.offset; i < end; i++) {
      mix[i] += samples[i - hit.offset];
    }
  }
  return _wav(mix, sampleRate);
}

double _amplitude(ClickLevel level) => switch (level) {
  ClickLevel.bar => 0.9,
  ClickLevel.group => 0.75,
  ClickLevel.beat => 0.6,
  ClickLevel.subdivision => 0.3,
};

/// A single synthesised click: a short decaying tone, higher on accents.
Float64List _hitSamples(ClickSound sound, ClickLevel level, int sampleRate) {
  final accented = level == ClickLevel.bar || level == ClickLevel.group;
  final (double freq, double decay, double length) = switch (sound) {
    ClickSound.click => (accented ? 2500.0 : 1800.0, 0.004, 0.03),
    ClickSound.woodblock => (accented ? 1250.0 : 900.0, 0.012, 0.06),
    ClickSound.beep => (accented ? 1760.0 : 880.0, 0.0, 0.06),
  };
  final n = (length * sampleRate).round();
  final out = Float64List(n);
  final amp = _amplitude(level);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final double envelope;
    if (sound == ClickSound.beep) {
      // Short fades against clicks at the edges.
      const fade = 0.003;
      envelope = math.min(1.0, math.min(t / fade, (length - t) / fade));
    } else {
      envelope = math.exp(-t / decay);
    }
    var v = math.sin(2 * math.pi * freq * t);
    if (sound == ClickSound.woodblock) {
      v = 0.75 * v + 0.25 * math.sin(2 * math.pi * freq * 2.7 * t);
    }
    out[i] = amp * envelope * v;
  }
  return out;
}

Uint8List _wav(Float64List samples, int sampleRate) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}
