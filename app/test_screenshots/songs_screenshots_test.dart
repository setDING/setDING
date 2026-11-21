// Screenshots of the song list and the song screen.
// See screenshot_support.dart.

import 'dart:typed_data';

import 'package:setding/ui/render/abc_view.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/sync_ui_test.dart' show syncNow;
import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

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
      await tester.tap(find.byKey(const Key('song-export-archive')));
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
