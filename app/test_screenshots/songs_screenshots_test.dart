// Screenshots of the song list and the song screen.
// See screenshot_support.dart.

import 'dart:io';
import 'dart:typed_data';

import 'package:chordpro/chordpro.dart' show ChordView;
import 'package:drift/drift.dart' show Value;
import 'package:setding/ui/render/abc_view.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/band_providers.dart';
import 'package:setding/data/band_view.dart';
import 'package:setding/data/org_storage_providers.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/song_list.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:setding/ui/trash/trash_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/sync_ui_test.dart' show syncNow;
import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();
  songImportSkippedScreenshots();
  songsTrashPdfScreenshots();

  // Songs with possible conversions (#798): the song list filtered from the
  // overview's To do card, with the icon and Convert all. The second song
  // only has German section labels, which are a conversion too (#1085).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('songs conversions $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final verse = lang == 'de' ? 'Strophe 1' : 'Verse 1';
      await tester.runAsync(() async {
        await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '{ccli: 6016351}\n{ccli_license: 1375063}\n'
              '{start_of_verse: $verse}\n[D]Morning light on the hill\n'
              '{end_of_verse}\n',
        );
        await app.songs.createSong(
          source:
              '{title: Abendlied}\n{artist: Hausband}\n{key: E}\n'
              '{start_of_verse: label="Vers 1"}\n[E]Der Tag geht still\n'
              '{end_of_verse}\n{comment: Schluss}\n[A]Gute [E]Nacht\n',
        );
        await app.songs.createSong(source: demoSongSource);
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-conversions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('songs-convert-all')), findsOneWidget);
      await shot(tester, '${lang}_38_songs_conversions');
      await app.dispose(tester);
    });
  }

  // The tag filter (#816): one menu with several tags ticked, songs with
  // any of them; and the menu of the band's plays.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('songs tags $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final (christmas, communion, current, archive) = lang == 'de'
          ? ('Advent & Weihnachten', 'Abendmahl', 'Aktuelle Songs', 'Archiv')
          : ('Advent & Christmas', 'Communion', 'Current songs', 'Archive');
      await tester.runAsync(() async {
        for (final (title, artist, key, tags) in [
          ('Morning Light', 'Ann Trainor', 'D', [current]),
          ('Silent Snow', 'House Band', 'G', [christmas]),
          ('Bread and Wine', 'Ann Trainor', 'E', [communion, current]),
          ('Train to Nowhere', 'House Band', 'E', [archive]),
          ('Starlight Carol', 'The Choir', 'F', [christmas, archive]),
        ]) {
          await app.songs.createSong(
            source:
                '{title: $title}\n{artist: $artist}\n{key: $key}\n'
                '${[for (final t in tags) '{tag: $t}\n'].join()}'
                '[$key]Sing a song\n',
          );
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.songs);
      await tester.tap(find.byKey(const Key('songs-tags')));
      await tester.pumpAndSettle();
      for (final t in [christmas, communion]) {
        await tester.tap(find.byKey(ValueKey('songs-tag-$t')).first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Train to Nowhere'), findsNothing);
      await shot(tester, '${lang}_42_songs_tags');

      // The band's plays (ADR-0046), the last filter: also a menu.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('songs-played')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('songs-played-stale')), findsOneWidget);
      await shot(tester, '${lang}_42b_songs_played');
      await app.dispose(tester);
    });
  }

  // The language of songs (ADR-0053, #805): tags and the language filter in
  // a library with songs in several languages, and the language of a song
  // set by hand.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('songs languages $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.runAsync(() async {
        await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]I walk along the river and you are always there with me,\n'
              'when the wind is in the willows and the night is calling me.\n'
              'You are my light, and all the stars will shine for you.',
        );
        await app.songs.createSong(
          source:
              '{title: Morgenlicht}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Ich gehe durch die Nacht und du bist immer bei mir,\n'
              'wenn der Wind über das Land zieht, singe ich mit dir.\n'
              'Du bist mein Licht, auch wenn die Sterne nicht mehr scheinen.',
        );
        await app.songs.createSong(
          source:
              '{title: Lumière du matin}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Je marche dans la nuit et tu es toujours avec moi,\n'
              'quand le vent chante sur la mer, je pense à toi.\n'
              'Tu es ma lumière, et les étoiles brillent pour nous.',
        );
        final id = await app.songs.createSong(
          source:
              '{title: Morgeliecht}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Mir sind hüt alli da und mir singed zäme es Lied,\n'
              'das chunnt vo ganzem Härze, wo mer nöd vergässed.',
        );
        await app.songs.setLanguage(id, 'gsw');
        await app.songs.createSong(
          source:
              '{title: Train to Nowhere}\n{artist: House Band}\n{key: E}\n'
              '[E]Waiting at the station for the train that never comes,\n'
              'and all the people there are counting all the hours.',
        );
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.songs);
      expect(find.byKey(const ValueKey('song-language-tag')), findsNWidgets(5));
      await shot(tester, '${lang}_39_songs_languages');

      // The language filter: All languages and No language above the
      // languages (#834), No language only with a song without one (#843).
      await tester.runAsync(
        () => app.songs.createSong(
          source: '{title: Intro}\n{artist: House Band}\n{key: E}\n[E] [A] [B]',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('songs-language')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('songs-language-none')), findsOneWidget);
      await shot(tester, '${lang}_39a_songs_language_filter');
      await tester.tap(find.byKey(const ValueKey('songs-language-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Morgeliecht'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-language')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('song-language-gsw')), findsOneWidget);
      await shot(tester, '${lang}_39b_song_language');
      await app.dispose(tester);
    });
  }

  // Language versions (ADR-0053, #806): the versions of a song below its
  // header, and the two-pane picker of the versions (#851).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('language versions $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.runAsync(() async {
        final en = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '{start_of_verse}\n'
              '[D]I walk along the [G]river and you are [A]always there with me,\n'
              'when the [D]wind is in the [G]willows and the [A]night is calling me.\n'
              '{end_of_verse}\n{start_of_chorus}\n'
              'You are my [G]light, and [A]all the stars will [D]shine for you.\n'
              '{end_of_chorus}',
        );
        final de = await app.songs.createSong(
          source:
              '{title: Morgenlicht}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Ich gehe durch die Nacht und du bist immer bei mir,\n'
              'wenn der Wind über das Land zieht, singe ich mit dir.\n'
              'Du bist mein Licht, auch wenn die Sterne nicht mehr scheinen.',
        );
        await app.songs.createSong(
          source:
              '{title: Lumière du matin}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Je marche dans la nuit et tu es toujours avec moi,\n'
              'quand le vent chante sur la mer, je pense à toi.\n'
              'Tu es ma lumière, et les étoiles brillent pour nous.',
        );
        final ch = await app.songs.createSong(
          source:
              '{title: Morgeliecht}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Mir sind hüt alli da und mir singed zäme es Lied,\n'
              'das chunnt vo ganzem Härze, wo mer nöd vergässed.',
        );
        await app.songs.setLanguage(ch, 'gsw');
        await app.songs.createSong(
          source:
              '{title: Train to Nowhere}\n{artist: House Band}\n{key: E}\n'
              '[E]Waiting at the station for the train that never comes,\n'
              'and all the people there are counting all the hours.',
        );
        await app.songs.linkLanguageVersions(en, de);
        await app.songs.linkLanguageVersions(en, ch);
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.songs);
      await tester.tap(find.textContaining('Morning Light'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('language-versions')), findsOneWidget);
      await shot(tester, '${lang}_40_language_versions');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-link-version')));
      await tester.pumpAndSettle();
      // Two versions linked, a third one ticked (#851).
      await tester.tap(find.textContaining('Lumière du matin'));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_40b_language_version_picker');
      await app.dispose(tester);
    });
  }

  // The sources of a song (`{x_link}`) with the SongSelect page of its
  // CCLI number (`{x_ccli}`, #1035) first.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song sources $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.runAsync(
        () => app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '{x_ccli: 7114209}\n'
              '{x_link: https://www.youtube.com/watch?v=abc | Live 2009}\n'
              '{x_link: https://open.spotify.com/track/1}\n'
              '{start_of_verse}\n'
              '[D]I walk along the [G]river and you are [A]always there with me,\n'
              'when the [D]wind is in the [G]willows and the [A]night is calling me.\n'
              '{end_of_verse}',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.songs);
      await tester.tap(find.textContaining('Morning Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-song-links')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-select-link')), findsOneWidget);
      await shot(tester, '${lang}_56_song_sources');
      await app.dispose(tester);
    });
  }

  // On a phone the panel buttons move into the ⋮ menu (#838).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song phone menu $lang', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final song = (await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        await app.songs.updateOverlay(id, (o) => o.copyWith(transpose: 2));
        return id;
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: song)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-personal-adjustments')), findsNothing);
      await tester.tap(find.byKey(const Key('app-bar-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('open-personal-adjustments-menu')),
        findsOneWidget,
      );
      await shot(tester, '${lang}_42c_song_phone_menu');
      await app.dispose(tester);
    });
  }

  // The attachment menu with Save (#1025).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song attachment menu $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final (song, horns) = (await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        final horns = await app.songs.addAttachment(
          id,
          name: lang == 'de' ? 'Bläser' : 'Horns',
          bytes: Uint8List(184320),
          pages: 2,
        );
        await app.songs.addAttachment(
          id,
          name: 'Piano',
          bytes: Uint8List(262144),
          pages: 3,
        );
        return (id, horns);
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: song)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('attachment-menu-$horns')));
      await tester.pumpAndSettle();
      expect(find.text(lang == 'de' ? 'Speichern' : 'Save'), findsOneWidget);
      await shot(tester, '${lang}_55_song_attachment_menu');
      await app.dispose(tester);
    });
  }

  // An attachment the server refused: only on this device, with the
  // reason (#1225).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song attachment refused $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final song = (await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        final horns = await app.songs.addAttachment(
          id,
          name: lang == 'de' ? 'Bläser' : 'Horns',
          bytes: Uint8List(184320),
          pages: 2,
        );
        await app.songs.addAttachment(
          id,
          name: 'Piano',
          bytes: Uint8List(262144),
          pages: 3,
        );
        await (app.db.update(
          app.db.attachments,
        )..where((a) => a.id.equals(horns))).write(
          const AttachmentsCompanion(
            uploadRefused: Value(UploadRefusal.notAllowed),
          ),
        );
        return id;
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: song)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachment-only-here')), findsOneWidget);
      await shot(tester, '${lang}_55b_song_attachment_refused');
      await app.dispose(tester);
    });
  }

  // The maximum size and the free storage before a file is picked, with
  // the warning from 90 %, and an attachment refused because the
  // organization's storage is full (ADR-0070).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song attachment storage $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
      final song = (await tester.runAsync(() async {
        final id = await songs.createSong(source: demoSongSource);
        await songs.addAttachment(
          id,
          name: 'Piano',
          bytes: Uint8List(262144),
          pages: 3,
        );
        final horns = await songs.addAttachment(
          id,
          name: lang == 'de' ? 'Bläser' : 'Horns',
          bytes: Uint8List(593920),
          pages: 4,
        );
        await (app.db.update(
          app.db.attachments,
        )..where((a) => a.id.equals(horns))).write(
          const AttachmentsCompanion(
            uploadRefused: Value(UploadRefusal.storageFull),
          ),
        );
        return id;
      }))!;
      const mb = 1024 * 1024;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SongScreen(songId: song),
            extra: [
              libraryProvider.overrideWith(
                (ref, id) => LibraryView(
                  id: id,
                  name: 'Music School',
                  orgRole: OrgRole.librarian,
                  userId: 'ann',
                ),
              ),
              orgStorageProvider.overrideWith(
                (ref, id) async => const OrgStorage(
                  usedBytes: 24 * mb + 600 * 1024,
                  limitBytes: 25 * mb,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachment-limit-hint')), findsOneWidget);
      expect(find.byKey(const Key('attachment-only-here')), findsOneWidget);
      await shot(tester, '${lang}_55c_song_attachment_storage');
      await app.dispose(tester);
    });
  }

  // The offer to copy the adjustments of another language version
  // (ADR-0053, #808).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('adjustment offer $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final de = (await tester.runAsync(() async {
        final en = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '{start_of_verse}\n[D]I walk along the [G]river\n{end_of_verse}\n',
        );
        final de = await app.songs.createSong(
          source:
              '{title: Morgenlicht}\n{artist: Ann Trainor}\n{key: D}\n'
              '{start_of_verse}\n[D]Ich gehe durch die [G]Nacht\n'
              '{end_of_verse}\n{start_of_chorus}\n'
              '[G]Du bist mein [A]Licht\n{end_of_chorus}\n',
        );
        await app.songs.setLanguage(en, 'en');
        await app.songs.setLanguage(de, 'de');
        await app.songs.linkLanguageVersions(en, de);
        await app.songs.updateOverlay(
          en,
          (o) => o.copyWith(transpose: -2, capoFret: const Value(2)),
        );
        return de;
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: de)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adjustment-offer')), findsOneWidget);
      await shot(tester, '${lang}_42_adjustment_offer');
      await app.dispose(tester);
    });
  }

  // One song in the three chord views and the menu of the per-song chord
  // view (ADR-0055).
  const chordViewSong =
      '{title: Evening Streets}\n{artist: setDING}\n{key: C}\n'
      '{start_of_verse: label="Verse"}\n'
      '[Cmaj7]Evening falls on [Am7]quiet streets\n'
      '[Dm7]Lights come on a[G7]long the way\n'
      '[Em7]Someone hums a [A7]song I know\n'
      '[Dm7]Stay a little [G7]longer, [C/E]stay\n'
      '{end_of_verse}\n'
      '{start_of_bridge}\n'
      '[Fmaj7]Rain on the [Bb7]window\n'
      '[Bm7b5]Minor de[E7]tour to[Am]night\n'
      '[D7]Back a[G7sus4]gain, back [G7]home\n'
      '{end_of_bridge}\n';
  // A chord grid whose held beats (`.`) show as dots (#1090).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('chord grid $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final song = await tester.runAsync(
        () => app.songs.createSong(source: _chordGrid),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: song!)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('.'), findsWidgets);
      await shot(tester, '${lang}_57_chord_grid');
      await app.dispose(tester);
    });
  }

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    for (final view in ChordView.values) {
      screenshotTest('chord view ${view.name} $lang', (tester) async {
        useTabletSize(tester);
        final app = await TestApp.create(
          prefs: {
            'language': lang,
            'themeMode': dark ? 'dark' : 'light',
            'chordView': view.name,
          },
        );
        final song = await tester.runAsync(
          () => app.songs.createSong(source: chordViewSong),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: UniqueKey(),
            child: app.build(home: SongScreen(songId: song!)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(switch (view) {
            ChordView.chords => 'Cmaj7',
            ChordView.nashville => '1maj7',
            ChordView.numerals => 'IΔ7',
          }),
          findsOneWidget,
        );
        await shot(tester, '${lang}_46_chord_view_${view.name}');
        if (view != ChordView.numerals) return app.dispose(tester);
        // The menu of the per-song chord view in the personal panel.
        await tester.tap(find.byKey(const Key('open-personal-adjustments')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chord-view-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chord-view-nashville')), findsOneWidget);
        await shot(tester, '${lang}_46b_chord_view_menu');
        await app.dispose(tester);
      });
    }
    // Numerals spelled with the chord symbol (ADR-0059).
    screenshotTest('chord view numerals chord symbol $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'chordView': 'numerals',
          'numeralSpelling': 'chordSymbol',
          'chordStyle': 'standard',
        },
      );
      final song = await tester.runAsync(
        () => app.songs.createSong(source: chordViewSong),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: song!)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Imaj7'), findsOneWidget);
      expect(find.text('VIm7'), findsOneWidget);
      await shot(tester, '${lang}_46c_chord_view_numerals_symbol');
      await app.dispose(tester);
    });
  }

  screenshotTest('song list search hits', (tester) async {
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
    await shot(tester, 'de_3_songs_search');
    await app.dispose(tester);
  });

  // Verses with the same chords stacked line by line (#521), in live mode.
  screenshotTest('stacked verses', (tester) async {
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
    await shot(tester, 'de_4e_live_stacked_verses');
    await app.dispose(tester);
  });

  // Stacked choruses next to stacked verses (#953), in live mode with the
  // menu that turns them on.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('stacked choruses $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final source = File('../docs/examples/personal-$lang.cho')
          .readAsStringSync();
      final song = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: source);
        final overlay = await app.songs.getOverlay(id);
        await app.songs.saveOverlay(
          overlay.copyWith(
            verseChords: VerseChords.stacked,
            stackedChoruses: true,
          ),
        );
        return (await app.songs.getSong(id))!;
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
        ),
      );
      await tester.pumpAndSettle();
      // The control bar, then the menu.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-chords-button')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxMenuButton), findsOneWidget);
      await shot(tester, '${lang}_4f_live_stacked_choruses');
      await app.dispose(tester);
    });
  }

  // Light and dark: the conflict icon (error colour) next to the gig icon
  // (primary colour) must stay apart with every palette (#269).
  for (final dark in [false, true]) {
    screenshotTest('song list status icons ${dark ? 'dark' : 'light'}', (
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
      await shot(tester, 'de_3_songs_status${dark ? '_dark' : ''}');
      await app.dispose(tester);
    });
  }

  screenshotTest('song list sorted by key', (tester) async {
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
    await shot(tester, 'de_3_songs_by_key');
    await tester.tap(find.byKey(const Key('songs-sort')));
    await shot(tester, 'de_3_songs_sort_menu');
    await app.dispose(tester);
  });

  screenshotTest('song list with a band arrangement', (tester) async {
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
    await shot(tester, 'en_3_songs_band');
    await app.dispose(tester);
  });

  // Lilypond notation drawn as notes with chord names and lyrics (#725).
  for (final lang in ['de', 'en']) {
    screenshotTest('lilypond $lang', (tester) async {
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
      await shot(tester, '${lang}_29_lilypond');
      await app.dispose(tester);
    });
  }

  // The hint when someone else changed the open song (#691).
  for (final lang in ['de', 'en']) {
    screenshotTest('sync hint $lang', (tester) async {
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
      await shot(tester, '${lang}_26_sync_hint');
      await app.dispose(tester);
    });
  }

  // Song archive (ADR-0043 §1c, #792): the export options and the preview
  // of an import that adds a new song and completes an existing one.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song archive $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final pdf = Uint8List.fromList('%PDF-1.4 lead sheet'.codeUnits);
      final (morning, zip) = (await tester.runAsync(() async {
        final morning = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Morning light on the [G]hill\n',
        );
        await app.songs.addAttachment(
          morning,
          name: 'Lead sheet',
          bytes: pdf,
          pages: 1,
        );
        final train = await app.songs.createSong(
          source:
              '{title: Late Train Home}\n{artist: Ann Trainor}\n{key: E}\n'
              '[E]The last train leaves at [A]dawn\n',
        );
        await app.songs.addAttachment(
          train,
          name: 'Horns',
          bytes: pdf,
          pages: 1,
        );
        final zip = await SongArchiveService(BackupService(app.db, app.storage))
            .export([morning, train]);
        // Here the lead sheet is missing and the other song is gone: the
        // import adds both again.
        for (final a in await app.songs.getAttachments(morning)) {
          await app.songs.deleteAttachment(a);
        }
        await app.songs.deleteSong(train);
        return (morning, zip);
      }))!;

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: SongScreen(songId: morning)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-format-archive')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-export')), findsOneWidget);
      await shot(tester, '${lang}_37_song_export');

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
                        ImportFile('songs.zip', zip),
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
      final added = find.byIcon(Icons.attach_file);
      for (var i = 0; i < 100 && added.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(added, findsOneWidget);
      await shot(tester, '${lang}_37b_song_import');
      await app.dispose(tester);
    });
  }
  // The trash (ADR-0043, #866): grouped by deletion time with the days
  // left, and the menu of an entry with Delete permanently.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('songs trash $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final now = DateTime.now();
      await tester.runAsync(() async {
        for (final (title, artist, days) in [
          ('Morning Light', 'Ann Trainor', 0),
          ('Train to Nowhere', 'House Band', 3),
          ('Amazing Grace', 'John Newton', 12),
          ('Old Rugged Cross', 'George Bennard', 28),
        ]) {
          final id = await app.songs.createSong(
            source: '{title: $title}\n{artist: $artist}\n[G]Hello',
          );
          await app.songs.deleteSong(id);
          await (app.db.update(
            app.db.songs,
          )..where((s) => s.id.equals(id))).write(
            SongsCompanion(
              deletedAt: Value(now.subtract(Duration(days: days))),
            ),
          );
        }
        await app.songs.createSong(source: demoSongSource);
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Songs').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('songs-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('songs-trash')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_45_songs_trash');
      await tester.tap(
        find.byTooltip(
          lang == 'de'
              ? 'Aktionen für «Old Rugged Cross»'
              : 'Actions for "Old Rugged Cross"',
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_45b_songs_trash_menu');
      await app.dispose(tester);
    });
  }
}

/// A PDF deleted on its own in the trash of an organization's library,
/// with the menu to delete it permanently (ADR-0070).
void songsTrashPdfScreenshots() {
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('songs trash pdf $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
      final now = DateTime.now();
      final horns = (await tester.runAsync(() async {
        final song = await songs.createSong(
          source: '{title: Morning Light}\n{artist: Ann Trainor}\n[G]Hello',
        );
        final horns = await songs.addAttachment(
          song,
          name: lang == 'de' ? 'Bläser' : 'Horns',
          bytes: Uint8List(593920),
          pages: 4,
        );
        final old = await songs.createSong(
          source: '{title: Amazing Grace}\n{artist: John Newton}\n[G]Hello',
        );
        await songs.deleteSong(old);
        await (app.db.update(
          app.db.songs,
        )..where((s) => s.id.equals(old))).write(
          SongsCompanion(
            deletedAt: Value(now.subtract(const Duration(days: 12))),
          ),
        );
        // On the server, deleted on its own two days ago.
        await (app.db.update(
          app.db.attachments,
        )..where((a) => a.id.equals(horns))).write(
          AttachmentsCompanion(
            revision: const Value(1),
            deleted: const Value(true),
            deletedAt: Value(now.subtract(const Duration(days: 2))),
          ),
        );
        return horns;
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const TrashScreen.songs(libraryId: 'o1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('trash-menu-$horns')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_45c_songs_trash_pdf');
      await app.dispose(tester);
    });
  }
}

/// The summary of a song archive import that skipped a PDF over 1 MB, with
/// its song, its size and the limit (ADR-0070).
void songImportSkippedScreenshots() {
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song import skipped $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final zip = (await tester.runAsync(() async {
        final song = await app.songs.createSong(
          source: '{title: Morning Light}\n{artist: Ann Trainor}\n[G]Hello',
        );
        await app.songs.addAttachment(
          song,
          name: lang == 'de' ? 'Bläser' : 'Horns',
          bytes: Uint8List.fromList('%PDF-1.4 horns'.codeUnits),
          pages: 1,
        );
        final big = Uint8List(2516582)..setAll(0, '%PDF-1.4'.codeUnits);
        await app.storage.write('scan.pdf', big);
        await app.db
            .into(app.db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: 'scan',
                songId: song,
                name: lang == 'de' ? 'Partitur (Scan)' : 'Full score (scan)',
                fileName: 'scan.pdf',
                sizeBytes: big.length,
                updatedAt: DateTime.now(),
              ),
            );
        final zip = await SongArchiveService(BackupService(app.db, app.storage))
            .export([song]);
        await app.songs.deleteSong(song);
        return zip;
      }))!;
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
                        ImportFile('songs.zip', zip),
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
      Future<void> waitFor(Key key) async {
        for (var i = 0; i < 500 && find.byKey(key).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.byKey(key), findsOneWidget);
      }

      await waitFor(const Key('song-import-start'));
      // The preview is read outside the fake clock before the start works.
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-import-start')));
      await waitFor(const Key('song-import-result'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-skipped-files')), findsOneWidget);
      await shot(tester, '${lang}_37c_song_import_skipped');
      await app.dispose(tester);
    });
  }
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

/// A song with a chord grid for the grid screenshot (#1090).
const _chordGrid = r'''{title: Morning Light}
{artist: Ann Trainor}
{key: B}

{start_of_grid shape="1+4x4+1" label="Intro"}
A || B . B . | E F# B . | E . F# . | G#m . G#m . || x2
{end_of_grid}

{start_of_verse: label="Verse 1"}
[B]Morning light on the [E]hill a[F#]gain
{end_of_verse}
''';
