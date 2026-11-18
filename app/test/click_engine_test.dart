import 'dart:async';
import 'dart:typed_data';

import 'package:chordpro/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/audio/beat_timeline.dart';
import 'package:setding/audio/click_sound.dart';
import 'package:setding/audio/metronome.dart';
import 'package:setding/settings/settings.dart';

import 'fake_click_output.dart';

/// Click engine of the drummer mode (ADR-0026, #332).
void main() {
  final fourFour = Meter.common;
  final sixEight = Meter.tryParse('6/8')!;
  final sevenEight = Meter.tryParse('7/8', grouping: '2+2+3')!;

  group('BeatTimeline', () {
    test('positions are computed from the start, without drift', () {
      final t = BeatTimeline(
        meter: fourFour,
        bpm: 120,
        start: const Duration(seconds: 1),
        countInBars: 2,
      );
      expect(t.positionAt(Duration.zero), isNull);
      final first = t.positionAt(const Duration(seconds: 1))!;
      expect((first.bar, first.beat, first.phase), (0, 0, 0.0));
      expect(first.inCountIn, isTrue);
      final p = t.positionAt(const Duration(milliseconds: 1750))!;
      expect((p.bar, p.beat), (0, 1));
      expect(p.phase, closeTo(0.5, 0.001));
      // Bar 2 is the first bar of the song after two count-in bars.
      final song = t.positionAt(const Duration(seconds: 5))!;
      expect(song.bar, 2);
      expect(song.songBar, 0);
      expect(song.inCountIn, isFalse);
      // An hour later, still exactly on the beat (no accumulated error).
      final later = t.positionAt(const Duration(seconds: 1 + 3600))!;
      expect(later.bar, 1800);
      expect(later.beat, 0);
      expect(later.phase, lessThan(0.001));
    });

    test('a tempo change starts at the next bar line', () {
      final t = BeatTimeline(meter: fourFour, bpm: 120, start: Duration.zero);
      final at = t.changeTempo(60, now: const Duration(milliseconds: 2500));
      expect(at, const Duration(seconds: 4));
      expect(t.bpm, 60);
      expect(t.positionAt(const Duration(milliseconds: 3900))!.bpm, 120);
      final p = t.positionAt(const Duration(seconds: 5))!;
      expect((p.bar, p.beat, p.bpm), (2, 1, 60));
      expect(t.timeOfBar(3), const Duration(seconds: 8));
      // A second change before the first is reached replaces it.
      t.changeTempo(90, now: const Duration(milliseconds: 3000));
      expect(t.positionAt(const Duration(seconds: 5))!.bpm, 90);
    });

    test('compound and odd meters', () {
      final c = BeatTimeline(meter: sixEight, bpm: 60, start: Duration.zero);
      expect(c.positionAt(const Duration(milliseconds: 1500))!.beat, 1);
      expect(c.positionAt(const Duration(seconds: 2))!.bar, 1);
      final o = BeatTimeline(meter: sevenEight, bpm: 210, start: Duration.zero);
      final p = o.positionAt(const Duration(milliseconds: 600))!;
      expect(p.beat, 2);
      expect(p.accent, BeatAccent.group);
    });
  });

  group('click sound', () {
    test('one bar: beats, accents and subdivisions', () {
      final hits = clickHits(fourFour, 120);
      expect(hits.map((h) => h.offset), [0, 22050, 44100, 66150]);
      expect(hits.first.level, ClickLevel.bar);
      expect(hits[1].level, ClickLevel.beat);
      expect(
        clickHits(fourFour, 120, accent: false).first.level,
        ClickLevel.beat,
      );
      final sub = clickHits(sixEight, 60, subdivision: true);
      expect(sub, hasLength(6));
      expect(sub.where((h) => h.level == ClickLevel.subdivision), hasLength(4));
      final odd = clickHits(sevenEight, 210);
      expect(odd.map((h) => h.level), [
        ClickLevel.bar,
        ClickLevel.beat,
        ClickLevel.group,
        ClickLevel.beat,
        ClickLevel.group,
        ClickLevel.beat,
        ClickLevel.beat,
      ]);
    });

    test('rendered as a WAV exactly one bar long', () {
      for (final sound in ClickSound.values) {
        final wav = renderClickBar(fourFour, 100, sound: sound);
        final data = ByteData.sublistView(wav);
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        expect(data.getUint32(24, Endian.little), clickSampleRate);
        final samples = data.getUint32(40, Endian.little) ~/ 2;
        expect(samples, barSamples(fourFour, 100));
        expect(samples, clickSampleRate * 60 * 4 ~/ 100);
        // The click is at the start, silence before the second beat.
        expect(data.getInt16(44 + 20, Endian.little).abs(), greaterThan(0));
        final beforeSecond = 44 + (samples ~/ 4 - 10) * 2;
        expect(data.getInt16(beforeSecond, Endian.little), 0);
      }
    });
  });

  group('Metronome', () {
    test('plays one looped bar, scheduled on the engine clock', () async {
      final out = FakeClickOutput()..time = const Duration(seconds: 10);
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 120,
        countInBars: 2,
        config: const ClickConfig(enabled: true, volume: 0.5),
      );
      expect(m.running.value, isTrue);
      expect(m.tempo.value, 120);
      final play = out.plays.single;
      expect(play.at, const Duration(seconds: 10) + Metronome.lead);
      expect(play.volume, 0.5);
      expect(play.until, isNull);
      expect(out.loaded.single.length, 44 + barSamples(fourFour, 120) * 2);

      out.time = play.at + const Duration(milliseconds: 500);
      expect(m.position()!.beat, 1);
      await m.stop();
      expect(m.running.value, isFalse);
      expect(out.stops.single.at, Duration.zero);
      expect(out.unloaded, [0]);
      expect(m.position(), isNull);
    });

    test('the display follows the audio delay', () async {
      final out = FakeClickOutput();
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 60,
        config: const ClickConfig(
          enabled: true,
          latency: Duration(milliseconds: 200),
        ),
      );
      final start = out.plays.single.at;
      out.time = start + const Duration(milliseconds: 1100);
      // Heard: 0.9 s after the start, still the first beat.
      expect(m.position()!.beat, 0);
      out.time = start + const Duration(milliseconds: 1250);
      expect(m.position()!.beat, 1);
      await m.stop();
    });

    test('count-in only stops the click and the beat after it', () async {
      final out = FakeClickOutput();
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 120,
        countInBars: 1,
        countInOnly: true,
        config: const ClickConfig(enabled: true),
      );
      final play = out.plays.single;
      expect(play.until, play.at + const Duration(seconds: 2));
      out.time = play.at + const Duration(milliseconds: 1900);
      expect(m.position()!.inCountIn, isTrue);
      out.time = play.at + const Duration(seconds: 2);
      expect(m.position(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(m.running.value, isFalse);
    });

    test('a tempo change on stage switches the bar at the bar line', () async {
      final out = FakeClickOutput();
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 120,
        config: const ClickConfig(enabled: true),
      );
      final start = out.plays.single.at;
      out.time = start + const Duration(milliseconds: 500);
      await m.setTempo(121);
      expect(m.tempo.value, 121);
      expect(out.plays, hasLength(2));
      final barLine = start + m.timeline!.barLength(120);
      expect(out.plays.last.at, barLine);
      expect(out.stops.single, (handle: 'handle-0', at: barLine));
      await m.setTempo(1000);
      expect(m.tempo.value, Metronome.maxBpm);
      await m.stop();
    });

    test('without a click or without audio, a monotonic clock runs', () async {
      var wall = Duration.zero;
      final out = FakeClickOutput(available: false);
      final m = Metronome(output: out, wallClock: () => wall);
      await m.start(
        meter: fourFour,
        bpm: 60,
        config: const ClickConfig(enabled: true),
      );
      expect(m.clickUnavailable.value, isTrue);
      expect(out.plays, isEmpty);
      wall = Metronome.lead + const Duration(milliseconds: 2100);
      expect(m.position()!.beat, 2);
      await m.start(meter: fourFour, bpm: 60);
      expect(m.clickUnavailable.value, isFalse);
      await m.stop();
    });

    test('an audio output that does not answer: the beat runs without '
        'the click', () async {
      var wall = Duration.zero;
      final out = FakeClickOutput()..ready = Completer<bool>();
      final m = Metronome(
        output: out,
        wallClock: () => wall,
        readyTimeout: const Duration(milliseconds: 20),
      );
      await m.start(
        meter: fourFour,
        bpm: 60,
        config: const ClickConfig(enabled: true),
      );
      expect(m.running.value, isTrue);
      expect(m.clickUnavailable.value, isTrue);
      expect(out.plays, isEmpty);
      wall = Metronome.lead + const Duration(milliseconds: 1100);
      expect(m.position()!.beat, 1);
      // Once the output answers, the next start plays the click.
      out.ready!.complete(true);
      await m.start(
        meter: fourFour,
        bpm: 60,
        config: const ClickConfig(enabled: true),
      );
      expect(m.clickUnavailable.value, isFalse);
      expect(out.plays, hasLength(1));
      await m.stop();
    });

    test('volume of a running click', () async {
      final out = FakeClickOutput();
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 100,
        config: const ClickConfig(enabled: true),
      );
      m.setVolume(0.3);
      expect(out.volumes, [0.3]);
      await m.stop();
    });

    test('settings give the click configuration', () {
      final c = ClickConfig.of(
        const AppSettings(
          instrument: 'drums',
          clickVolume: 0.4,
          clickSound: ClickSound.beep,
          audioLatencyMs: 150,
        ),
      );
      expect(c.enabled, isTrue);
      expect(c.volume, 0.4);
      expect(c.sound, ClickSound.beep);
      expect(c.latency, const Duration(milliseconds: 150));
    });
  });

  group('latency calibration', () {
    test('tap offsets from the nearest beat', () async {
      final out = FakeClickOutput();
      final m = Metronome(output: out);
      await m.start(
        meter: fourFour,
        bpm: 60,
        config: const ClickConfig(enabled: true),
      );
      final start = out.plays.single.at;
      out.time = start + const Duration(milliseconds: 1180);
      expect(m.tapOffset(), const Duration(milliseconds: 180));
      out.time = start + const Duration(milliseconds: 1950);
      expect(m.tapOffset(), const Duration(milliseconds: -50));
      await m.stop();
      expect(m.tapOffset(), isNull);
    });

    test('the median of the taps, within the allowed range', () {
      Duration ms(int v) => Duration(milliseconds: v);
      expect(latencyFromTaps([ms(100), ms(120)]), isNull);
      expect(latencyFromTaps([ms(100), ms(120), ms(500), ms(110)]), 115);
      expect(latencyFromTaps([ms(-30), ms(-10), ms(-20), ms(-40)]), 0);
      expect(
        latencyFromTaps([for (var i = 0; i < 5; i++) ms(900)]),
        AppSettings.maxAudioLatencyMs,
      );
    });
  });
}
