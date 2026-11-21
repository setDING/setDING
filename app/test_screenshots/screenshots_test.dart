// Renders screenshots with real fonts for visual review.
// Run: make screenshots   (output in build/screenshots/)
//
// The files are only written with --dart-define=WRITE_SCREENSHOTS=true
// (set by `make screenshots`). Without it, as in the test gate
// (tool/check.sh), the screens are still built, driven and rendered, so a UI
// change that breaks the screenshots fails `make check`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chordpro/chordpro.dart' show Subdivision;

import 'package:setding/ui/render/abc_view.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/ui/widgets/export_file.dart' show saveFileProvider;
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/widgets/logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../test/sync_ui_test.dart' show syncNow;
import '../test/test_app.dart';

const _write = bool.fromEnvironment('WRITE_SCREENSHOTS');

/// The Material fonts of the Flutter SDK running the test: the test runs in
/// `<sdk>/bin/cache/artifacts/engine/<platform>/flutter_tester`.
String get _materialFonts =>
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
    '/material_fonts';

Future<void> _loadFonts() async {
  final dir = _materialFonts;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Italic.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  // Wordmark of the logo (registered in pubspec.yaml).
  final noto = FontLoader('NotoSans')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/NotoSans-Bold.ttf').readAsBytesSync(),
        ),
      ),
    );
  await noto.load();
  // A system monospace font for tabs and sources, if available.
  const mono = '/usr/share/fonts/TTF/DejaVuSansMono.ttf';
  if (File(mono).existsSync()) {
    final loader = FontLoader('monospace')
      ..addFont(
        Future.value(ByteData.sublistView(File(mono).readAsBytesSync())),
      );
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  expect(bytes!.lengthInBytes, greaterThan(0));
  if (!_write) return;
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png')
      .writeAsBytesSync(bytes.buffer.asUint8List());
}

/// A Lilypond lead sheet for the notation screenshot (#725).
const _lilypond = r'''{title: Morning Light}
{artist: Ann Trainor}
{key: G}
{time: 3/4}

{start_of_ly label="Melody"}
<<
  \chords { s4 | g2. | c2 d4:7 | g2. | g }
  \relative c' {
    \key g \major \time 3/4 \partial 4
    d4 | \repeat volta 2 { g4( a) b | c2 e,8[ fis] }
    \alternative { { g2 d4 } { g2. } }
  }
  \addlyrics { Morn -- ing light, on the hill a -- gain }
>>
{end_of_ly}
''';

/// Editor content for the highlighting screenshot: one line per token kind.
const _highlightSource = '''{title: Highlighting}
{key: G}
{x_sequence: V, C}
# A comment line
{start_of_verse: label="Verse 1"}
[G]Lyrics with <b>markup</b>, [*Riff] and [Xyz] [N.C.]
{comment-alto: Selector}
{comment: A long comment wraps onto a second row in the editor; the line number stays on the first row}
{textsize: 120%}
{end_of_verse}
{start_of_grid}
| G . . . | C . D . :|
{end_of_grid}
{start_of_tab}
e|--0--2--|
{end_of_tab}
{start_of_abc}
X:1
K:G
{end_of_abc}
[Am unclosed
''';

/// A screenshot test that renders real elevation shadows.
///
/// Flutter tests disable shadows (`debugDisableShadows`), which paints them as
/// thick black outlines; the screenshots should look like the real app. The
/// flag is restored before the test ends, as the framework checks it.
void _screenshotTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    final disabled = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = disabled;
    }
  });
}

void main() {
  setUpAll(() async => _loadFonts());

  _screenshotTest('song list search hits', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: demoSongSource);
      await app.songs.createSong(
        source:
            '{title: Train to Nowhere}\n{artist: House Band}\n{key: E}\n'
            '[E]Waiting at the station\n[A]For the train that never comes',
      );
      await app.songs.createSong(
        source:
            '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
            '[D]Morning light on the hill\n[G]The last train leaves at dawn',
      );
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: const SongsScreen()),
      ),
    );
    await tester.enterText(find.byType(SearchBar), 'train');
    await tester.pump(songSearchDelay);
    await _shot(tester, 'de_3_songs_search');
    await app.dispose(tester);
  });

  // Verses with the same chords stacked line by line (#521), in live mode.
  _screenshotTest('stacked verses', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'de'});
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source:
            '{title: Amazing Grace}\n{key: G}\n'
            '{start_of_verse: Strophe 1}\n'
            'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
            'That saved a wretch like [D]me\n'
            'I [G]once was [G7]lost, but [C]now am [G]found\n'
            'Was [Em]blind, but [D]now I [G]see\n{end_of_verse}\n'
            '{start_of_verse: Strophe 2}\n'
            '\'Twas [G]grace that [G7]taught my [C]heart to [G]fear\n'
            'And grace my fears re[D]lieved\n'
            'How [G]precious [G7]did that [C]grace ap[G]pear\n'
            'The [Em]hour I [D]first be[G]lieved\n{end_of_verse}\n'
            '{start_of_verse: Strophe 3}\n'
            'Through many dangers, toils and snares\n'
            'I have already come\n'
            '\'Tis grace hath brought me safe thus far\n'
            'And grace will lead me home\n{end_of_verse}\n',
      );
      final overlay = await app.songs.getOverlay(id);
      await app.songs.saveOverlay(
        overlay.copyWith(verseChords: VerseChords.stacked),
      );
      return (await app.songs.getSong(id))!;
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
      ),
    );
    await _shot(tester, 'de_4e_live_stacked_verses');
    await app.dispose(tester);
  });

  // Light and dark: the conflict icon (error colour) next to the gig icon
  // (primary colour) must stay apart with every palette (#269).
  for (final dark in [false, true]) {
    _screenshotTest('song list status icons ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'de', 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.runAsync(() async {
        final a = await app.songs.createSong(source: demoSongSource);
        await app.songs.createSong(title: 'Hallelujah (Noten)');
        final c = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: House Band}\n{key: D}\n[D]x',
        );
        await app.db
            .into(app.db.songConflicts)
            .insert(
              SongConflictsCompanion.insert(
                songId: c,
                title: 'Morning Light',
                chordproSource: '{title: Morning Light}',
                revision: 2,
                detectedAt: DateTime.now(),
              ),
            );
        final set = await app.sets.createSet(
          name: 'Summer Festival',
          gigDate: DateTime.now().add(const Duration(days: 3)),
        );
        await app.sets.addSongs(set, [a, c]);
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SongsScreen()),
        ),
      );
      await _shot(tester, 'de_3_songs_status${dark ? '_dark' : ''}');
      await app.dispose(tester);
    });
  }

  _screenshotTest('song list sorted by key', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'de', 'songSort': 'key'},
    );
    await tester.runAsync(() async {
      for (final (title, artist, key) in [
        ('Late Train Home', 'setDING Example', 'G'),
        ('Ännchen von Tharau', 'Volkslied', 'D'),
        ('Blue Monday Groove', 'House Band', 'Bb'),
        ('Morning Light', 'House Band', 'D'),
        ('Open Road', null, null),
      ]) {
        await app.songs.createSong(
          source:
              '{title: $title}\n${artist == null ? '' : '{artist: $artist}\n'}'
              '${key == null ? '' : '{key: $key}\n'}{x_sequence: V, C, V, C}\n',
        );
      }
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: const SongsScreen()),
      ),
    );
    await _shot(tester, 'de_3_songs_by_key');
    await tester.tap(find.byKey(const Key('songs-sort')));
    await _shot(tester, 'de_3_songs_sort_menu');
    await app.dispose(tester);
  });

  _screenshotTest('song list with a band arrangement', (tester) async {
    useTabletSize(tester);
    const ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: ann,
    );
    app.backend.addBand('b1', 'Rock', admin: ann, organizationId: 'o1');
    await tester.runAsync(() async {
      final songs = TestApp.songsIn(app, 'o1');
      final id = await songs.createSong(source: demoSongSource);
      await songs.createSong(
        source:
            '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n'
            '{tempo: 92}\n{tag: Blues}\n{x_sequence: I, V, C, V, C x2, O}\n',
      );
      await ArrangementRepository(app.db)
          .save('b1', id, transpose: 2, sequence: 'I, V, C, C, O', tempo: 104);
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: const SongsScreen()),
      ),
    );
    await _shot(tester, 'en_3_songs_band');
    await app.dispose(tester);
  });

  for (final dark in [false, true]) {
    _screenshotTest('sets grouped by gig date ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      useTabletSize(tester, landscape: false);
      final app = await TestApp.create(
        // Past sets expanded, to show all three sections.
        prefs: {
          'language': 'de',
          'themeMode': dark ? 'dark' : 'light',
          'pastSetsCollapsed': false,
        },
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        for (final (name, venue, days) in [
          ('Sommerfest', 'Bern', 3),
          ('Hochzeit Meier', 'Thun', 17),
          ('Probe', null, null),
          ('Jazznacht', 'Biel', -12),
          ('Weihnachtskonzert', 'Luzern', -200),
        ]) {
          await app.sets.createSet(
            name: name,
            venue: venue,
            gigDate: days == null ? null : today.add(Duration(days: days)),
          );
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await _shot(tester, 'de_1_sets_grouped${dark ? '_dark' : ''}');
      await app.dispose(tester);
    });
  }

  for (final dark in [false, true]) {
    _screenshotTest('splash ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.5;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SplashScreen(),
          ),
        ),
      );
      await _shot(tester, '0_splash_${dark ? 'dark' : 'light'}');
    });
  }

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('screenshots $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final ids = await tester.runAsync(() async {
        final a = await app.songs.createSong(source: demoSongSource);
        final b = await app.songs.createSong(
          source: '{title: Blue Monday Groove}\n{artist: House Band}\n{key: Bb}\n{tag: Blues}\n{x_sequence: I, V, PC, C, V, PC, C x2, B, O}\n[Bb7]Blues [Eb7]line\n',
        );
        await app.songs.saveOverlay(
          (await app.songs.getOverlay(
            a,
          )).copyWith(notes: const Value('Count in 4, ritardando at the end')),
        );
        final setId = await app.sets.createSet(
          name: 'Summer Festival',
          venue: 'Bern',
          gigDate: DateTime(2027, 6, 21),
        );
        await app.sets.addSongs(setId, [a, b]);
        await app.sets.addMarker(
          setId,
          MarkerIcons.breakIcon,
          lang == 'de' ? 'Pause' : 'Break',
        );
        return [a, setId];
      });

      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      // Wide: the next gig is shown next to the list (#266).
      await _shot(tester, '${lang}_1_sets');
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SetScreen(setId: ids![1])),
        ),
      );
      await _shot(tester, '${lang}_2_set');
      // The ⋮ menu of the set: print, share and export the set list.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await _shot(tester, '${lang}_2b_set_menu');
      // The marker dialog with an icon and a text (ADR-0047).
      await tester.tap(
        find.text(lang == 'de' ? 'Hinweis hinzufügen' : 'Add marker'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marker-icon-encore')));
      await tester.pumpAndSettle();
      await _shot(tester, '${lang}_2c_marker_dialog');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: ids[0])),
        ),
      );
      await _shot(tester, '${lang}_3_song');
      // ? lists the keyboard shortcuts (#729).
      await tester.sendKeyEvent(
        LogicalKeyboardKey.slash,
        character: '?',
        physicalKey: PhysicalKeyboardKey.slash,
      );
      await _shot(tester, '${lang}_30_shortcuts');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SongsScreen()),
        ),
      );
      await _shot(tester, '${lang}_3_songs');
      // Selection mode: select all, copy to band and delete selected (#738).
      await tester.longPress(find.text('Blue Monday Groove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is Checkbox && w.value == false).first,
      );
      await _shot(tester, '${lang}_3c_songs_selected');

      final items = await tester.runAsync(
        () async => [
          for (final v in await app.sets.getItems(ids[1]))
            v.song == null
                ? LiveItem.marker(v.item.icon, v.item.note)
                : LiveItem.song(v.song!),
        ],
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items!)),
        ),
      );
      await _shot(tester, '${lang}_4_live');
      // A tap in the middle shows the control bar.
      await tester.tapAt(tester.getRect(find.byType(PageView)).center);
      await _shot(tester, '${lang}_4b_live_controls');
      // The page of a marker (ADR-0047): the break after the two songs.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items, initialIndex: 2)),
        ),
      );
      await _shot(tester, '${lang}_4c_live_marker');
      // Stage appearance independent of the app theme (#263): dark on the
      // light German app, true black on the dark English one.
      final stage = lang == 'de' ? 'dark' : 'black';
      await app.prefs.setString('liveAppearance', stage);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items)),
        ),
      );
      await _shot(tester, '${lang}_4_live_$stage');
      // The second song shows the sequence chips (chorus, pre-chorus,
      // bridge and other parts, #288) on the stage and in the app theme.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items, initialIndex: 1)),
        ),
      );
      await _shot(tester, '${lang}_4_live_${stage}_sequence');
      await app.prefs.setString('liveAppearance', 'app');
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items, initialIndex: 1)),
        ),
      );
      await _shot(tester, '${lang}_4_live_sequence');
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items)),
        ),
      );
      await _shot(tester, '${lang}_5_live_portrait');

      // Showcase of ChordPro features (ADR-0012).
      tester.view.physicalSize = const Size(1280, 800);
      final showcase = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: _showcase);
        return app.songs.getSong(id);
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: [LiveItem.song(showcase!)])),
        ),
      );
      await _shot(tester, '${lang}_6_chordpro_showcase');

      // Chord diagrams below the song (guitar in English, ukulele in German).
      await app.prefs.setString('diagrams', 'bottom');
      await app.prefs.setString(
        'instrument',
        lang == 'de' ? 'ukulele' : 'guitar',
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: items)),
        ),
      );
      await _shot(tester, '${lang}_7_diagrams');

      // Delegated environments: SVG, textblock, Lilypond source.
      await app.prefs.setString('diagrams', 'off');
      final media = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: _media);
        return app.songs.getSong(id);
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: [LiveItem.song(media!)])),
        ),
      );
      await _shot(tester, '${lang}_8_media');

      // Song editor with grouped insert menus; the preview starts at the top.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(initialSource: demoSongSource),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'de' ? 'Abschnitte' : 'Sections'));
      await _shot(tester, '${lang}_9_editor');

      // Syntax highlighting of every kind of ChordPro element.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const SongEditorScreen(initialSource: _highlightSource),
          ),
        ),
      );
      // The cursor after "[" of [*Riff] highlights the bracket pair.
      tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .selection = TextSelection.collapsed(
        offset: _highlightSource.indexOf('[*Riff]') + 1,
      );
      await _shot(tester, '${lang}_9b_editor_highlighting');

      // Autocompletion of directives after "{".
      await tester.tap(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        '{title: Autocomplete}\n{key: G}\n[G]la [Em]li\n{st',
      );
      await _shot(tester, '${lang}_9c_editor_autocomplete');

      // Song sequence for a set item, built from the parts of the song.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SetScreen(setId: ids[1])),
        ),
      );
      await tester.pumpAndSettle();
      // The ⋮ menu of the first set item (the demo song).
      await tester.tap(
        find
            .byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-'))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('set-item-action-sequence')));
      await tester.pumpAndSettle();
      for (final code in ['V1', 'C', 'V2', 'C']) {
        await tester.tap(find.byKey(ValueKey('sequence-part-$code')));
        await tester.pump();
      }
      await _shot(tester, '${lang}_10_set_sequence');
      await app.dispose(tester);
    });
  }

  // Section labels in the short form (#672): the editor hint and the import
  // report that offer to convert them to label="…"; the CCLI bar line hint
  // (#481).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('section label conversion $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final source = lang == 'de' ? _shortLabelsDe : _shortLabels;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongEditorScreen(initialSource: source)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LegacyLabelHint), findsOneWidget);
      await _shot(tester, '${lang}_23_editor_labels');

      // CCLI bar lines (#481): the hint that converts them to chord grids.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(
              initialSource: lang == 'de' ? _ccliBarsDe : _ccliBars,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CcliGridHint), findsOneWidget);
      expect(find.byType(LegacyLabelHint), findsNothing);
      await _shot(tester, '${lang}_24_editor_ccli');

      // Typing aids (#747): Enter after a section start adds its end, a
      // typed `[` its `]`. Esc hides the chord suggestions, which would
      // cover the end directive.
      const autoClose =
          '{title: Amazing Grace}\n{key: G}\n\n{start_of_verse}\n'
          'A[G]mazing [G7]grace, how [C]sweet the [G]sound\n'
          '{end_of_verse}\n\n{start_of_chorus}';
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const SongEditorScreen(initialSource: autoClose),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final editor = tester.widget<TextField>(find.byType(TextField));
      for (final char in ['\n', '[']) {
        final value = editor.controller!.value;
        final at = char == '\n'
            ? value.text.length
            : value.selection.baseOffset;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: value.text.replaceRange(at, at, char),
            selection: TextSelection.collapsed(offset: at + 1),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        editor.controller!.text,
        endsWith('{start_of_chorus}\n[]\n{end_of_chorus}'),
      );
      await _shot(tester, '${lang}_31_editor_auto_close');

      // The save button (#748): filled as soon as there are unsaved changes.
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongEditorScreen(initialSource: demoSongSource),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final saveField = tester.widget<TextField>(find.byType(TextField));
      saveField.controller!.text = '$demoSongSource\n';
      await _shot(tester, '${lang}_32_editor_save');

      ImportFile file(String name, String text) =>
          ImportFile(name, Uint8List.fromList(utf8.encode(text)));
      final files = [
        file('amazing-grace.cho', source),
        file(
          'morning-light.cho',
          '{title: Morning Light}\n{key: D}\n'
              '{sov: ${lang == 'de' ? 'Strophe' : 'Verse'} 1}\n'
              '[D]Morning light on the hill\n{eov}\n',
        ),
        file(
          'washed.cho',
          '{title: Washed}\n{c: Chorus} (a cappella)\n[G]la\n',
        ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showImportDialog(
                      context,
                      pick: ({extensions}) async => files,
                    ),
                    child: const Text('import'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Dateien auswählen' : 'Choose files'),
      );
      // The import writes to the database outside the fake clock.
      final report = find.byKey(const Key('import-problems'));
      for (var i = 0; i < 100 && report.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(report, findsOneWidget);
      await _shot(tester, '${lang}_23b_import_labels');
      await app.dispose(tester);
    });
  }

  // Set archive (ADR-0043 §1b, #707): the export options, the preview of an
  // import that finds the set again and the report.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('set archive $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final (setId, zip) = (await tester.runAsync(() async {
        final morning = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Morning light on the [G]hill\n',
        );
        final grace = await app.songs.createSong(
          source: '{title: Amazing Grace}\n{key: G}\n[G]Amazing grace\n',
        );
        await ArrangementRepository(app.db)
            .save(localBandId, morning, transpose: 2, sequence: 'V1, C, V2, C');
        final set = await app.sets.createSet(
          name: lang == 'de' ? 'Sommerfest' : 'Summer party',
          gigDate: DateTime(2027, 6, 21),
          venue: 'Bern',
        );
        await app.sets.addSongs(set, [morning]);
        await app.sets.addMarker(set, MarkerIcons.breakIcon, '');
        await app.sets.addSongs(set, [grace]);
        final zip = await SetArchiveService(BackupService(app.db, app.storage))
            .export(set);
        // Gone from the library since: the import adds it again.
        await app.songs.deleteSong(grace);
        return (set, zip);
      }))!;

      var pdfSaved = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SetScreen(setId: setId),
            extra: [
              saveFileProvider.overrideWithValue((
                name,
                bytes, {
                mimeType = '',
              }) async {
                pdfSaved = true;
                return true;
              }),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openSetMenu() async {
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
      }

      // After the PDF export, the message offers "Open" (#721).
      await openSetMenu();
      await tester.tap(
        find.text(
          lang == 'de'
              ? 'Set-Liste exportieren (PDF zum Drucken)'
              : 'Export set list (PDF for printing)',
        ),
      );
      // The PDF is built outside the fake clock (fonts, isolates).
      for (var i = 0; i < 200 && !pdfSaved; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(SnackBarAction), findsOneWidget);
      await _shot(tester, '${lang}_28_set_pdf_exported');
      ScaffoldMessenger.of(tester.element(find.byType(SetScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await openSetMenu();
      await tester.tap(
        find.text(lang == 'de' ? 'Als ZIP exportieren' : 'Export as ZIP'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-export')), findsOneWidget);
      await _shot(tester, '${lang}_27_set_export');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showImportDialog(
                      context,
                      pick: ({extensions}) async => [
                        ImportFile('set.zip', zip),
                      ],
                    ),
                    child: const Text('import'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Dateien auswählen' : 'Choose files'),
      );
      // The preview reads the database outside the fake clock.
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(finder, findsOneWidget);
      }

      await waitFor(find.byKey(const Key('set-import-replace')));
      // As a copy: the preview shows the copy name (#719).
      await tester.tap(find.byKey(const Key('set-import-copy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-import-new-name')), findsOneWidget);
      await _shot(tester, '${lang}_27b_set_import');
      await tester.tap(find.byKey(const Key('set-import-start')));
      await waitFor(find.byKey(const Key('set-import-result')));
      await _shot(tester, '${lang}_27c_set_import_result');
      await app.dispose(tester);
    });
  }

  // Lilypond notation drawn as notes with chord names and lyrics (#725).
  for (final lang in ['de', 'en']) {
    _screenshotTest('lilypond $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': lang == 'de' ? 'light' : 'dark'},
      );
      final id = await tester.runAsync(
        () => app.songs.createSong(source: _lilypond),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: id!)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AbcView), findsOneWidget);
      await _shot(tester, '${lang}_29_lilypond');
      await app.dispose(tester);
    });
  }

  // The hint when someone else changed the open song (#691).
  for (final lang in ['de', 'en']) {
    _screenshotTest('sync hint $lang', (tester) async {
      useTabletSize(tester);
      const ben = AuthUser(id: 'ben', email: 'ben@example.test', name: 'Ben');
      const anna = AuthUser(
        id: 'anna',
        email: 'anna@example.test',
        name: 'Anna',
      );
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': lang == 'de' ? 'light' : 'dark',
          'currentBandId': 'b1',
        },
        user: ben,
      );
      RemoteSong song(String line) => RemoteSong(
        id: 's1',
        organizationId: 'o1',
        title: 'Morning Light',
        chordpro:
            '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
            '{start_of_verse}\n[D]Morning light on the [G]hill\n'
            '[A]$line\n{end_of_verse}\n',
      );
      app.backend
        ..addBand('b1', 'Rock', admin: anna, organizationId: 'o1')
        ..addMember('b1', ben, BandRole.member)
        ..putSong(song('The last train leaves at dawn'), by: 'anna');
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await syncNow(tester);
      final home = tester.element(find.byType(HomeScreen));
      ScaffoldMessenger.of(home).removeCurrentSnackBar();
      Navigator.of(home).push(
        MaterialPageRoute<void>(builder: (_) => const SongScreen(songId: 's1')),
      );
      await tester.pumpAndSettle();
      app.backend.putSong(
        song('The [D]first bus leaves at [A]dawn'),
        by: 'anna',
      );
      await syncNow(tester);
      expect(find.byKey(const Key('sync-hint-songChanged')), findsOneWidget);
      await _shot(tester, '${lang}_26_sync_hint');
      await app.dispose(tester);
    });
  }

  // Live mode for drums (ADR-0026): the song map with drum notes instead of
  // the chord sheet, and on wide screens the beat panel with the set.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('drummer live mode $lang', (tester) async {
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
      await _shot(tester, '${lang}_11_live_drums');
      await app.dispose(tester);
    });
  }

  // The grouping and subdivisions of the click per song (#698): in the tempo
  // row of the control bar, with the grouping menu open.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('click per song $lang', (tester) async {
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
      await _shot(tester, '${lang}_25_live_click');
      await app.dispose(tester);
    });
  }

  // Organization, band and invitation screens for the user documentation
  // (website, ADR-0030), signed in as the organization admin.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('organization and band $lang', (tester) async {
      useTabletSize(tester);
      const ann = AuthUser(
        id: 'ann',
        email: 'ann@example.test',
        name: 'Ann Keller',
      );
      const people = [
        AuthUser(id: 'ben', email: 'ben@example.test', name: 'Ben Frei'),
        AuthUser(id: 'cara', email: 'cara@example.test', name: 'Cara Meier'),
        AuthUser(id: 'dan', email: 'dan@example.test', name: 'Dan Huber'),
        AuthUser(id: 'eva', email: 'eva@example.test', name: 'Eva Graf'),
      ];
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
        user: ann,
      );
      final school = lang == 'de' ? 'Musikschule Bern' : 'Music School';
      app.backend.addOrganization('o1', school, admin: ann);
      app.backend.addBand('b1', 'Rock Band', admin: ann, organizationId: 'o1');
      app.backend.addBand('b2', 'Jazz Combo', admin: ann, organizationId: 'o1');
      app.backend.addOrgMember('o1', people[0], OrgRole.librarian);
      app.backend.addMember('b1', people[1], BandRole.planner);
      app.backend.addMember('b1', people[2], BandRole.member);
      app.backend.addMember('b2', people[3], BandRole.member);

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const OrganizationScreen(organizationId: 'o1'),
          ),
        ),
      );
      await _shot(tester, '${lang}_12_organization');

      // The invitation button is below the people.
      await tester.scrollUntilVisible(
        find.byKey(const Key('invite-create')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      await _shot(tester, '${lang}_13_invite');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const BandScreen(bandId: 'b1')),
        ),
      );
      await _shot(tester, '${lang}_14_band');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await _shot(tester, '${lang}_15_settings');
      // The musician settings: instrument, voice, diagrams, beat.
      await tester.tap(find.text(lang == 'de' ? 'Musiker' : 'Musician'));
      await _shot(tester, '${lang}_16_settings_musician');
      await tester.tap(find.byKey(const Key('settings-category-general')));
      await _shot(tester, '${lang}_18_settings_general');
      // Song display styles (ADR-0033) with a preset of colours.
      await tester.tap(find.byKey(const Key('settings-category-songDisplay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-preset-colorCoded')));
      await _shot(tester, '${lang}_20_settings_song_display');
      // The editor: controls next to the preview (#478).
      await tester.tap(find.byKey(const Key('song-display-customise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-type-chorus')));
      await _shot(tester, '${lang}_21_song_display_editor');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Not every category fits on a landscape tablet.
      final live = find.byKey(const Key('settings-category-live'));
      await tester.ensureVisible(live);
      await tester.pumpAndSettle();
      await tester.tap(live);
      await _shot(tester, '${lang}_19_settings_live');
      await app.dispose(tester);
    });
  }

  // Freehand notes in live mode (ADR-0032): a highlighted line, a circled
  // chord, an arrow and a stamp, drawn with the stylus; once with the
  // toolbar of drawing mode, once while playing.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('freehand notes $lang', (tester) async {
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
      await _shot(tester, '${lang}_17_annotations');

      await pick('annotation-done');
      await _shot(tester, '${lang}_17b_annotations_live');
      await app.dispose(tester);
    });
  }

  // Keyboard (MIDI, ADR-0039) for the user documentation: the device
  // settings with a connected Nord Stage 3, and live mode with the
  // indicator and "Send program again".
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    _screenshotTest('keyboard midi $lang', (tester) async {
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
      await _shot(tester, '${lang}_22_settings_midi');

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
      await _shot(tester, '${lang}_22b_live_midi');
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

const _showcase = r'''{title: ChordPro Showcase}
{artist: setDING}
{key: D}
{tempo: 100}
{c: Key %{key}, %{tempo} BPM}

{start_of_verse: label="Verse 1\nAll voices"}
[D]Markup is <b>bold</b>, <i>italic</i> and [G]<span color="red">red</span>,
[Em]<u>underlined</u> and <span size="larger">larger</span> [A7]too.
{end_of_verse}

{textcolour: #1e88e5}
{start_of_chorus}
[G]A coloured [D]chorus [A]line,
[G]sung with [D]joy [A]all the [D]time.
{end_of_chorus}
{textcolour}

{column_break}
{start_of_grid shape="1+4x2+1" label="Interlude"}
A   || D . | G . | % . | A7 . |
    | Em~A7 . | / . | D . | . . || x2
{end_of_grid}

{transpose: 2}
{start_of_bridge: Bridge (+2)}
[D]Modulates up [G]two [A]semitones
{end_of_bridge}
''';

const _ccliBars = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Intro}
[|][G] [.] [G/B] [.][|][C2] [.] [G] [.][|]

{start_of_verse: label="Verse 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{comment: Turnaround}
[|][Em] [D] [C] [.][|][G] [.] [.] [.][|]
''';

const _ccliBarsDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{comment: Intro}
[|][G] [.] [G/B] [.][|][C2] [.] [G] [.][|]

{start_of_verse: label="Strophe 1"}
A[G]mazing grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{comment: Zwischenspiel}
[|][Em] [D] [C] [.][|][G] [.] [.] [.][|]
''';

const _shortLabels = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: Verse 1}
A[G]mazing [G7]grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{soc: Chorus}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
{eoc}

{start_of_verse: label="Verse 2"}
'Twas [G]grace that [G7]taught my [C]heart to [G]fear
{end_of_verse}
''';

const _shortLabelsDe = '''{title: Amazing Grace}
{artist: John Newton}
{key: G}

{start_of_verse: Strophe 1}
A[G]mazing [G7]grace, how [C]sweet the [G]sound
That saved a wretch like [D]me
{end_of_verse}

{soc: Refrain}
I [G]once was [G7]lost, but [C]now am [G]found
Was [Em]blind, but [D]now I [G]see
{eoc}

{start_of_verse: label="Strophe 2"}
'Twas [G]grace that [G7]taught my [C]heart to [G]fear
{end_of_verse}
''';

const _media = r'''{title: Media Showcase}
{start_of_verse}
[G]A verse before the [D]picture
{end_of_verse}
{start_of_svg label="Stage plan"}
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 120">
<rect x="5" y="5" width="290" height="110" rx="10" fill="none" stroke="#7986cb" stroke-width="3"/>
<circle cx="70" cy="60" r="22" fill="#3f51b5"/><text x="70" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Guitar</text>
<circle cx="150" cy="45" r="22" fill="#e53935"/><text x="150" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Vocals</text>
<circle cx="230" cy="60" r="22" fill="#43a047"/><text x="230" y="100" font-size="14" text-anchor="middle" fill="#7986cb">Bass</text>
</svg>
{end_of_svg}
{start_of_textblock flush=center align=center label="Spoken intro"}
Ladies and gentlemen,
<i>please welcome</i> the <b>band</b>!
{end_of_textblock}
{start_of_abc}
X:1
T:Speed the Plough
M:4/4
L:1/8
K:G
|:"G"GABG DGBG|"D"A2 AB c2 Bc|"G"d^cdB "C"c2 =cB|1 "D7"A3 G A4:|2 "D7"A2 F2 G4||
w:one two three four
{end_of_abc}
{start_of_ly label="Melody"}
\relative c' { c4 d e f | g2 g }
{end_of_ly}
''';
