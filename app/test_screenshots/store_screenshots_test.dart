// Screenshots of the store listings (Google Play, ADR-0067, #1147, and the
// App Store), in both languages and both themes. Composed into docs/store/
// by tool/store-screenshots.sh (run by tool/copy-screenshots.sh).
// See screenshot_support.dart.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:chordpro/chordpro.dart' show SectionRole;

import '../test/test_app.dart';

import 'screenshot_support.dart';

/// The devices of the store listings: for Google Play a phone at 1080×1920
/// (about 411×731 logical pixels) and a landscape tablet at 2560×1600
/// (1280×800); for the App Store the iPhone 6.9" (1320×2868), the iPad 13"
/// in landscape (2752×2064) and the Mac (2880×1800).
enum _Device {
  phone(Size(1080, 1920), 2.625),
  tablet(Size(2560, 1600), 2),
  iphone(Size(1320, 2868), 3),
  ipad(Size(2752, 2064), 2),
  mac(Size(2880, 1800), 2);

  const _Device(this.size, this.ratio);
  final Size size;
  final double ratio;
}

void main() {
  setUpScreenshots();

  // Every screen in both themes and both languages: tool/store-screenshots.sh
  // picks the theme per screen and splits the first one diagonally.
  for (final device in _Device.values) {
    for (final lang in ['de', 'en']) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        final label = '${device.name} $lang $theme';
        final prefix = '${lang}_${theme}_store_${device.name}';

        Future<TestApp> start(
          WidgetTester tester, [
          Map<String, Object> prefs = const {},
        ]) {
          tester.view.physicalSize = device.size;
          tester.view.devicePixelRatio = device.ratio;
          addTearDown(tester.view.reset);
          return TestApp.create(
            prefs: {'language': lang, 'themeMode': theme, ...prefs},
          );
        }

        Future<void> capture(WidgetTester tester, String name) =>
            shot(tester, '${prefix}_$name', pixelRatio: device.ratio);

        screenshotTest('store $label', (tester) async {
          final app = await start(tester, {'userName': 'Ann'});
          final ids = await tester.runAsync(() => _fill(app, lang));
          Future<void> show(Widget? home, String name) async {
            await tester.pumpWidget(
              RepaintBoundary(
                key: UniqueKey(),
                child: app.build(home: home),
              ),
            );
            await capture(tester, name);
          }

          final items = await tester.runAsync(
            () async => [
              for (final v in await app.sets.getItems(ids!.set))
                v.song == null
                    ? LiveItem.marker(v.item.icon, v.item.note)
                    : LiveItem.song(v.song!),
            ],
          );
          await show(LiveScreen(items: items!), '1_live');
          await show(SetScreen(setId: ids!.set), '2_set');
          // The editor with the section menu open next to the preview.
          await show(
            const SongEditorScreen(initialSource: demoSongSource),
            '3_editor',
          );
          await tester.tap(find.text(lang == 'de' ? 'Abschnitte' : 'Sections'));
          await capture(tester, '3_editor');
          await show(null, '5_overview');
          await show(const SongsScreen(), '6_songs');
          await app.dispose(tester);
        });

        // The song display editor (ADR-0033) with the chorus selected.
        screenshotTest('store style $label', (tester) async {
          final app = await start(tester);
          await tester.pumpWidget(
            RepaintBoundary(
              key: UniqueKey(),
              child: app.build(home: const SettingsScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await openSettingsCategory(tester, SettingsCategory.songDisplay);
          await tester.tap(
            find.byKey(const Key('song-display-preset-colorCoded')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('song-display-customise')));
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .byKey(const ValueKey(('role-target', SectionRole.chorus)))
                .first,
          );
          await capture(tester, '4_style');
          await app.dispose(tester);
        });

        // Drummer mode: the beat above, the song map of the song below (#952).
        screenshotTest('store drums $label', (tester) async {
          final app = await start(tester, {
            'instrument': 'drums',
            'clickStart': 'manual',
            'drumPanelView': 'songMap',
          });
          final items = await tester.runAsync(() async {
            final items = <LiveItem>[];
            for (final source in [
              lang == 'de' ? _drumsDe : _drums,
              _songs[0],
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
          await capture(tester, '7_drums');
          await app.dispose(tester);
        });

        // An own server (ADR-0063): the Server dialog under Account & sync.
        screenshotTest('store server $label', (tester) async {
          final app = await start(tester);
          await tester.pumpWidget(
            RepaintBoundary(
              key: UniqueKey(),
              child: app.build(home: const SettingsScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await openSettingsCategory(tester, SettingsCategory.account);
          await tester.tap(find.byIcon(Icons.dns_outlined));
          await tester.pumpAndSettle();
          final field = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(field, 'https://setding.example.org');
          await capture(tester, '8_server');
          await app.dispose(tester);
        });
      }
    }
  }
}

/// The library and the set of the main screens.
Future<({String demo, String set})> _fill(TestApp app, String lang) async {
  final now = DateTime.now();
  final demo = await app.songs.createSong(source: demoSongSource);
  await app.songs.saveOverlay(
    (await app.songs.getOverlay(demo)).copyWith(
      notes: Value(
        lang == 'de'
            ? 'Einzählen auf 4, ritardando am Schluss'
            : 'Count in 4, ritardando at the end',
      ),
    ),
  );
  final others = [
    for (final source in _songs) await app.songs.createSong(source: source),
  ];
  final set = await app.sets.createSet(
    name: lang == 'de' ? 'Sommerfest' : 'Summer Festival',
    venue: 'Bern',
    gigDate: DateTime(now.year, now.month, now.day + 3),
  );
  await app.sets.addSongs(set, [demo, others[0], others[1]]);
  await app.sets.addMarker(
    set,
    MarkerIcons.breakIcon,
    lang == 'de' ? 'Pause' : 'Break',
  );
  await app.sets.addSongs(set, [others[2], others[3]]);
  return (demo: demo, set: set);
}

/// Further songs of the set and the library, written for these screenshots.
const _songs = [
  '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n{tempo: 84}\n'
      '{x_sequence: I, V, C, V, C x2, O}\n[Bb7]Blues [Eb7]line\n',
  '{title: Highway Lights}\n{artist: House Band}\n{key: E}\n{tempo: 118}\n'
      '{x_sequence: I, V1, PC, C, V2, PC, C x2, B, O}\n[E]Headlights on the [A]road\n',
  '{title: Paper Boats}\n{artist: The Harbour Choir}\n{key: D}\n{tempo: 72}\n'
      '[D]Paper boats on the [G]river\n',
  '{title: Northern Sky}\n{artist: Ann Trainor}\n{key: Am}\n{tempo: 100}\n'
      '[Am]Under the northern [F]sky\n',
  '{title: Golden Hour}\n{artist: Ann Trainor}\n{key: F}\n{tempo: 96}\n'
      '[F]Golden hour is [C]calling\n',
  '{title: Morning Light}\n{artist: The Harbour Choir}\n{key: G}\n{tempo: 80}\n'
      '[G]Morning light on the [C]hill\n',
  '{title: Seven Steps}\n{artist: Jazz Trio}\n{key: Dm}\n{tempo: 168}\n'
      '{time: 7/8}\n[Dm7]Seven [G7]steps\n',
];

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
[E]Highway [B]lights
{comment-drums: Crash on 1, ride cymbal}
{end_of_chorus}
{start_of_bridge}
[A]Slow it [B]down
{comment-drums: Half time, snare on 3}
{end_of_bridge}
{start_of_verse: Outro}
{comment-drums: Big ending on the cue}
{end_of_verse}
''';

final _drumsDe = {
  'Toms, four bars, then full groove': 'Toms, vier Takte, dann voller Groove',
  'Rim click, hi-hat closed': 'Rimclick, Hi-Hat geschlossen',
  'Build on the floor tom': 'Aufbau auf der Floor Tom',
  'Crash on 1, ride cymbal': 'Crash auf 1, dann Ride',
  'Half time, snare on 3': 'Halftime, Snare auf 3',
  'Big ending on the cue': 'Grosser Schluss auf Zeichen',
}.entries.fold(_drums, (s, e) => s.replaceAll(e.key, e.value));
