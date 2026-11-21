// Screenshots of live mode for drums, keyboard and freehand notes.
// See screenshot_support.dart.
import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' show Subdivision;

import 'package:setding/data/database.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // Live mode for drums (ADR-0026): the song map with drum notes instead of
  // the chord sheet, and on wide screens the beat panel with the set.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('drummer live mode $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'drums',
          'clickStart': 'manual',
        },
      );
      final items = await tester.runAsync(() async {
        final items = <LiveItem>[];
        for (final source in [
          lang == 'de' ? _drumsDe : _drums,
          _drumsNext,
          demoSongSource,
        ]) {
          final id = await app.songs.createSong(source: source);
          items.add(LiveItem.song((await app.songs.getSong(id))!));
        }
        return items;
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await shot(tester, '${lang}_11_live_drums');
      await app.dispose(tester);
    });
  }

  // The grouping and subdivisions of the click per song (#698): in the tempo
  // row of the control bar, with the grouping menu open.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('click per song $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'drums',
          'clickStart': 'manual',
        },
      );
      final items = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: _oddMeter);
        await app.songs.updateOverlay(
          id,
          (o) =>
              o.copyWith(clickSubdivision: const Value(Subdivision.sixteenths)),
        );
        final next = await app.songs.createSong(source: _drumsNext);
        return [
          LiveItem.song((await app.songs.getSong(id))!),
          LiveItem.song((await app.songs.getSong(next))!),
        ];
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(LiveScreen)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('click-grouping-button')));
      await shot(tester, '${lang}_25_live_click');
      await app.dispose(tester);
    });
  }

  // Freehand notes in live mode (ADR-0032): a highlighted line, a circled
  // chord, an arrow and a stamp, drawn with the stylus; once with the
  // toolbar of drawing mode, once while playing.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('freehand notes $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final items = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        return [LiveItem.song((await app.songs.getSong(id))!)];
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byType(PageView));
      await tester.tapAt(page.center);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-annotations-draw')));
      await tester.pumpAndSettle();

      Future<void> stroke(List<Offset> points) async {
        final g = await tester.startGesture(
          page.topLeft + points.first,
          kind: PointerDeviceKind.stylus,
        );
        for (final p in points.skip(1)) {
          await g.moveTo(page.topLeft + p);
          await tester.pump();
        }
        await g.up();
        await tester.pumpAndSettle();
      }

      Future<void> pick(String key) async {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      List<Offset> ellipse(Offset c, double rx, double ry) => [
        for (var i = 0; i <= 26; i++)
          c +
              Offset(
                rx * math.cos(i * math.pi / 12 - 0.4),
                ry * math.sin(i * math.pi / 12 - 0.4),
              ),
      ];

      List<Offset> line(Offset from, Offset to) => [
        for (var i = 0; i <= 12; i++) Offset.lerp(from, to, i / 12)!,
      ];

      // Highlighter: the first line of the chorus.
      await pick('annotation-tool-highlighter');
      await pick('annotation-color-3');
      await stroke(line(_noteSpots.highlightFrom, _noteSpots.highlightTo));
      // Pen: circle a chord, draw an arrow to it.
      await pick('annotation-tool-pen');
      await pick('annotation-color-0');
      await stroke(ellipse(_noteSpots.circle, 42, 20));
      await pick('annotation-color-1');
      final (from, to) = (_noteSpots.arrowFrom, _noteSpots.arrowTo);
      await stroke(line(from, to));
      final dir = (to - from) / (to - from).distance;
      final perp = Offset(-dir.dy, dir.dx);
      await stroke([to - dir * 22 + perp * 12, to, to - dir * 22 - perp * 12]);
      // Stamp: a fermata where the band holds.
      await pick('annotation-tool-stamp');
      await tester.tap(find.byKey(const Key('annotation-stamp-fermata')).last);
      await tester.pumpAndSettle();
      await stroke([_noteSpots.stamp]);
      await pick('annotation-tool-pen');
      await shot(tester, '${lang}_17_annotations');

      await pick('annotation-done');
      await shot(tester, '${lang}_17b_annotations_live');
      await app.dispose(tester);
    });
  }

  // Keyboard (MIDI, ADR-0039) for the user documentation: the device
  // settings with a connected Nord Stage 3, and live mode with the
  // indicator and "Send program again".
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('keyboard midi $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'keyboard',
          'midiEnabled': true,
          'midiOutputName': 'Nord Stage 3',
        },
      );
      app.midiOutput.ports = const [
        MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final midi = find.byKey(const Key('settings-category-midi'));
      await tester.ensureVisible(midi);
      await tester.pumpAndSettle();
      await tester.tap(midi);
      await shot(tester, '${lang}_22_settings_midi');

      final items = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        await app.songs.setMidiProgram(
          id,
          'nordStage3',
          const MidiProgram(msb: 0, lsb: 0, program: 57),
          deviceProfile: 'nordStage3',
        );
        return [LiveItem.song((await app.songs.getSong(id))!)];
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getRect(find.byType(PageView)).center);
      await shot(tester, '${lang}_22b_live_midi');
      await app.dispose(tester);
    });
  }
}

/// Where the freehand notes screenshot draws, relative to the live page.
const _noteSpots = (
  highlightFrom: Offset(36, 472),
  highlightTo: Offset(352, 472),
  circle: Offset(283, 121),
  arrowFrom: Offset(480, 175),
  arrowTo: Offset(335, 130),
  stamp: Offset(392, 612),
);

/// A song with drum notes for the drummer screenshot.
const _drums = '''{title: Highway Lights}
{artist: House Band}
{key: E}
{tempo: 118}
{time: 4/4}
{x_sequence: I, V1, PC, C, V2, PC, C x2, B, O}
{start_of_verse: Intro}
{comment-drums: Toms, four bars, then full groove}
{end_of_verse}
{start_of_verse: Verse 1}
[E]Headlights on the [A]empty road
{comment-drums: Rim click, hi-hat closed}
{end_of_verse}
{start_of_verse: Pre-Chorus}
[C#m]Hold on, [B]hold on
{comment-drums: Build on the floor tom}
{end_of_verse}
{start_of_chorus}
[A]We ride the [E]highway lights
{comment-drums: Crash on 1, ride cymbal}
{end_of_chorus}
{start_of_verse: Verse 2}
[E]Radio plays our [A]favourite song
{end_of_verse}
{start_of_bridge}
[F#m]Half time [B]here
{comment-drums: Half time, snare on 3}
{end_of_bridge}
{start_of_verse: Outro}
{comment-drums: Big ending on the cue}
{end_of_verse}
''';

/// [_drums] with the drum notes in German.
final _drumsDe = {
  'Toms, four bars, then full groove': 'Toms, vier Takte, dann voller Groove',
  'Rim click, hi-hat closed': 'Rimclick, Hi-Hat geschlossen',
  'Build on the floor tom': 'Aufbau auf der Floor Tom',
  'Crash on 1, ride cymbal': 'Crash auf 1, dann Ride',
  'Half time, snare on 3': 'Halftime, Snare auf 3',
  'Big ending on the cue': 'Grosser Schluss auf Zeichen',
}.entries.fold(_drums, (s, e) => s.replaceAll(e.key, e.value));

/// A song in an odd meter for the screenshot of the click per song.
const _oddMeter = '''{title: Seven Steps}
{tempo: 168}
{time: 7/8}
{x_time_grouping: 2+2+3}

{start_of_verse: Intro}
[Am]Da da [G]da
{end_of_verse}
{start_of_verse}
[Am]Seven steps [G]up the [F]hill
{comment-drums: Kick on every group}
{end_of_verse}
{start_of_chorus}
[C]Count them [G]all again
{end_of_chorus}
''';

/// The song after [_drums]; the footer shows its tempo and time signature.
const _drumsNext =
    '{title: Blue Monday Groove}\n{tempo: 84}\n{time: 12/8}\n[Bb7]Blues [Eb7]line\n';
