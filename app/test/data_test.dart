import 'dart:io';
import 'dart:typed_data';

import 'dart:convert';

import 'package:realchord/data/attachment_storage_io.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/import_export.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SongRepository songs;
  late SetRepository sets;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('realchord_test');
    final storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('SongRepository', () {
    test('creates a song and extracts metadata', () async {
      final id = await songs.createSong(
        source: '{title: Hello}\n{artist: Band}\n{key: G}\n{tempo: 100}\n[G]Hi',
      );
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Hello');
      expect(song.artist, 'Band');
      expect(song.songKey, 'G');
      expect(song.tempo, 100);
      expect(song.libraryId, localBandId);
    });

    test('PDF-only song uses given title and artist', () async {
      final id = await songs.createSong(title: 'Horns', artist: 'Brass');
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Horns');
      expect(song.chordproSource, '');
    });

    test('updateSource keeps the title if the source has none', () async {
      final id = await songs.createSong(title: 'Keep me');
      await songs.updateSource(id, '[C]No title here');
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Keep me');
      // The revision is the server's (ADR-0004); local edits don't change it.
      expect(song.revision, 0);
    });

    test('search matches title, artist and lyrics', () async {
      await songs.createSong(source: '{title: Alpha}\nsunshine');
      await songs.createSong(source: '{title: Beta}\n{artist: Gamma}');
      expect(
        (await songs.watchSongs(query: 'sun').first).single.title,
        'Alpha',
      );
      expect((await songs.watchSongs(query: 'gam').first).single.title, 'Beta');
      expect(await songs.watchSongs().first, hasLength(2));
    });

    test('full-text search ignores chords, accents and word order', () async {
      await songs.createSong(
        source:
            '{title: Über den Wolken}\n{artist: Reinhard Mey}\n'
            '[C]Hel[G]lo sun[Am]shine\n{c: Capo 2 – slowly}',
      );
      await songs.createSong(source: '{title: Other}\n[D]rain');
      Future<List<String>> find(String q) async => [
        for (final s in await songs.watchSongs(query: q).first) s.title,
      ];
      expect(await find('hello'), ['Über den Wolken']);
      expect(await find('uber'), ['Über den Wolken']);
      expect(await find('mey wolk'), ['Über den Wolken']);
      expect(await find('slowly'), ['Über den Wolken']);
      expect(await find('wolken rain'), isEmpty);
      // Quotes and operators are search text, not FTS syntax.
      expect(await find('"rain" OR'), isEmpty);
      expect(await find('NEAR('), isEmpty);
      expect(await find('!!'), isEmpty);
      // The list query searches the same way.
      expect(
        (await songs.watchSongList(query: 'hello').first).single.title,
        'Über den Wolken',
      );
      // Editing updates the index.
      final id = (await songs.watchSongs(query: 'rain').first).single.id;
      await songs.updateSource(id, '{title: Other}\n[D]snow');
      expect(await find('rain'), isEmpty);
      expect(await find('snow'), ['Other']);
    });

    test('attachments are stored and size-limited', () async {
      final id = await songs.createSong(title: 'X');
      final attId = await songs.addAttachment(
        id,
        name: 'Piano',
        bytes: Uint8List.fromList([1, 2, 3]),
        pages: 2,
      );
      final list = await songs.getAttachments(id);
      expect(list.single.id, attId);
      expect(
        await File('${dir.path}/${list.single.fileName}').exists(),
        isTrue,
      );
      expect((await songs.watchAttachmentCounts().first)[id], 1);

      expect(
        () => songs.addAttachment(
          id,
          name: 'Big',
          bytes: Uint8List(maxAttachmentBytes + 1),
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );

      await songs.deleteAttachment(list.single);
      expect(await songs.getAttachments(id), isEmpty);
      expect(
        await File('${dir.path}/${list.single.fileName}').exists(),
        isFalse,
      );
    });

    test('overlay defaults and saving', () async {
      final id = await songs.createSong(title: 'X');
      expect((await songs.getOverlay(id)).transpose, 0);
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(transpose: 2, capo: 1),
      );
      final overlay = await songs.getOverlay(id);
      expect(overlay.transpose, 2);
      expect(overlay.capo, 1);
    });

    test('overlay fields can be reset to null', () async {
      final id = await songs.createSong(title: 'X');
      final attId = await songs.addAttachment(
        id,
        name: 'P',
        bytes: Uint8List.fromList([1]),
      );
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(
          nashville: const Value(true),
          notes: const Value('note'),
          liveView: Value(attId),
        ),
      );
      expect((await songs.getOverlay(id)).nashville, isTrue);

      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(
          nashville: const Value(null),
          notes: const Value(null),
          liveView: const Value(null),
        ),
      );
      final overlay = await songs.getOverlay(id);
      expect(overlay.nashville, isNull);
      expect(overlay.notes, isNull);
      expect(overlay.liveView, isNull);
    });
  });

  group('Tags, sorting and import', () {
    test('sorts by sorttitle and filters by tag', () async {
      await songs.createSong(
        source: '{title: The Zebra}\n{sorttitle: Zebra}\n{tag: Rock}',
      );
      await songs.createSong(
        source: '{title: Apple}\n{tag: Ballad}\n{tag: rock}',
      );
      await songs.createSong(source: '{title: Mango}');
      expect((await songs.watchSongs().first).map((s) => s.title), [
        'Apple',
        'Mango',
        'The Zebra',
      ]);
      expect((await songs.watchSongs(tag: 'Rock').first).map((s) => s.title), [
        'Apple',
        'The Zebra',
      ]);
      expect(await songs.watchTags().first, ['Ballad', 'Rock']);
    });

    test('a file with several songs is imported as several songs', () async {
      final service = ImportExportService(songs, sets);
      final result = await service.importFiles([
        ImportFile(
          'medley.cho',
          Uint8List.fromList(
            utf8.encode('{title: One}\n[C]a\n{new_song}\n{title: Two}\n[G]b\n'),
          ),
        ),
      ]);
      expect(result.imported, 2);
      final all = await songs.watchSongs().first;
      expect(all.map((s) => s.title), ['One', 'Two']);
      expect(all.last.chordproSource, '{title: Two}\n[G]b\n');
    });
  });

  test('the song list sorts by title, artist, key or last edit', () async {
    final c = await songs.createSong(source: '{title: Charlie}\n{key: Em}');
    await songs.createSong(source: '{title: Alpha}\n{artist: Zoe}\n{key: G}');
    await songs.createSong(source: '{title: Bravo}\n{artist: Ann}\n{key: E}');
    await songs.createSong(source: '{title: Delta}\n{artist: ann}');
    Future<List<String>> titles(SongSort sort) async =>
        (await songs.watchSongList(sort: sort).first)
            .map((s) => s.title)
            .toList();

    expect(await titles(SongSort.title), [
      'Alpha',
      'Bravo',
      'Charlie',
      'Delta',
    ]);
    // Accents do not move a title to the end.
    final umlaut = await songs.createSong(source: '{title: Ärger}');
    expect((await titles(SongSort.title))[1], 'Ärger');
    await songs.deleteSong(umlaut);
    // Without artist last; case-insensitive; then by title.
    expect(await titles(SongSort.artist), [
      'Bravo',
      'Delta',
      'Alpha',
      'Charlie',
    ]);
    // C to B, major before minor, without key last.
    expect(await titles(SongSort.key), ['Bravo', 'Charlie', 'Alpha', 'Delta']);
    // Times are stored in seconds: the others were edited long ago.
    await db
        .update(db.songs)
        .write(SongsCompanion(updatedAt: Value(DateTime(2020))));
    await songs.updateSource(c, '{title: Charlie}\n{key: Em}\nedited');
    expect((await titles(SongSort.recent)).first, 'Charlie');
  });

  test('the song list has what lists show, filtered like the songs', () async {
    final a = await songs.createSong(
      source:
          '{title: Alpha}\n{artist: Ann}\n{key: G}\n{tempo: 96}\n{tag: Rock}\n'
          '{x_sequence: V, C x2}\n[G]sun',
    );
    await songs.createSong(source: '{title: Beta}\n[C]rain');
    final list = await songs.watchSongList().first;
    expect(list.map((s) => s.title), ['Alpha', 'Beta']);
    expect(
      list.first,
      SongListEntry(
        id: a,
        title: 'Alpha',
        artist: 'Ann',
        songKey: 'G',
        tempo: 96,
        sequence: 'V, C x2',
        tags: '\nRock\n',
      ),
    );
    expect(list.last.sequence, isNull);
    expect(list.first.tagList, ['Rock']);
    expect(
      (await songs.watchSongList(query: 'rain').first).map((s) => s.title),
      ['Beta'],
    );
    expect((await songs.watchSongList(tag: 'rock').first).map((s) => s.id), [
      a,
    ]);
  });

  group('personal adjustments per person (ADR-0020)', () {
    SongRepository org(String? user) =>
        SongRepository(db, songs.storage, libraryId: 'o1', userId: user);

    test('each person sees their own adjustments on a shared device', () async {
      final id = await org('ann').createSong(source: '{title: Shared}');
      final ann = org('ann');
      await ann.saveOverlay((await ann.getOverlay(id)).copyWith(transpose: 2));
      final bob = org('bob');
      expect((await bob.getOverlay(id)).transpose, 0);
      await bob.saveOverlay(
        (await bob.getOverlay(id)).copyWith(notes: const Value('Solo')),
      );
      expect((await ann.getOverlay(id)).transpose, 2);
      expect((await ann.getOverlay(id)).notes, isNull);
      expect((await bob.getOverlay(id)).ownerId, 'bob');
    });

    test('the local library keeps the local owner when signed in', () async {
      final id = await songs.createSong(source: '{title: Mine}');
      await songs.saveOverlay((await songs.getOverlay(id)).copyWith(capo: 1));
      final signedIn = SongRepository(db, songs.storage, userId: 'ann');
      expect(signedIn.overlayOwner, localOwnerId);
      expect((await signedIn.getOverlay(id)).capo, 1);
    });

    test('adjustments follow the library of the song, not of the '
        'repository', () async {
      final orgSong = await org('ann').createSong(source: '{title: Org}');
      final localSong = await songs.createSong(source: '{title: Mine}');
      // A repository of the local library used for an organization song,
      // e.g. Live mode of a set while the songs tab shows another library.
      final local = SongRepository(db, songs.storage, userId: 'ann');
      await local.saveOverlay(
        (await local.getOverlay(orgSong)).copyWith(transpose: 3),
      );
      expect((await local.getOverlay(orgSong)).ownerId, 'ann');
      expect((await org('ann').getOverlay(orgSong)).transpose, 3);
      expect(await local.watchOverlay(orgSong).first, isA<SongOverlay>());
      expect((await local.watchOverlay(orgSong).first).transpose, 3);
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox.where((o) => o.recordId.contains(orgSong)), isNotEmpty);

      // And the other way round: the local song stays with the local owner.
      final ann = org('ann');
      await ann.saveOverlay(
        (await ann.getOverlay(localSong)).copyWith(capo: 2),
      );
      expect((await songs.getOverlay(localSong)).capo, 2);
      expect((await ann.getOverlay(localSong)).ownerId, localOwnerId);
    });

    test(
      'the first user takes over local adjustments of organization songs',
      () async {
        final orgSong = await org(null).createSong(source: '{title: Org}');
        final localSong = await songs.createSong(source: '{title: Mine}');
        // As after the upgrade: everything belongs to the local owner.
        for (final id in [orgSong, localSong]) {
          await db
              .into(db.personalOverlays)
              .insert(
                PersonalOverlaysCompanion.insert(
                  songId: id,
                  transpose: const Value(5),
                ),
              );
        }
        expect(await adoptLocalOverlays(db, 'ann'), 1);
        expect((await org('ann').getOverlay(orgSong)).transpose, 5);
        expect((await org('bob').getOverlay(orgSong)).transpose, 0);
        expect((await songs.getOverlay(localSong)).transpose, 5);
      },
    );
  });

  group('SetRepository', () {
    test('adds, reorders and removes items', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final setId = await sets.createSet(name: 'Gig', venue: 'Club');
      await sets.addSongs(setId, [a, b]);
      await sets.addMarker(setId, SetItemType.pause, 'Break');

      var items = await sets.getItems(setId);
      expect(items.map((v) => v.song?.title ?? v.item.note), [
        'A',
        'B',
        'Break',
      ]);

      await sets.reorder(setId, [
        items[2].item.id,
        items[0].item.id,
        items[1].item.id,
      ]);
      items = await sets.getItems(setId);
      expect(items.map((v) => v.song?.title ?? v.item.note), [
        'Break',
        'A',
        'B',
      ]);

      await sets.removeItem(setId, items[0].item.id);
      items = await sets.getItems(setId);
      expect(items.map((v) => v.item.position), [0, 1]);

      final summary = (await sets.watchSets().first).single;
      expect(summary.itemCount, 2);
    });

    test('deleting a song removes it from sets', () async {
      final a = await songs.createSong(source: '{title: A}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      await songs.deleteSong(a);
      expect(await sets.getItems(setId), isEmpty);
    });

    test('offline ready requires attachment files', () async {
      final a = await songs.createSong(title: 'A');
      await songs.addAttachment(a, name: 'P', bytes: Uint8List.fromList([1]));
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      expect(await sets.isOfflineReady(setId), isTrue);

      final file = (await songs.getAttachments(a)).single.fileName;
      await File('${dir.path}/$file').delete();
      expect(await sets.isOfflineReady(setId), isFalse);
    });

    test('offline status of all sets comes from one stream', () async {
      final a = await songs.createSong(title: 'A');
      await songs.addAttachment(a, name: 'P', bytes: Uint8List.fromList([1]));
      final b = await songs.createSong(title: 'B');
      final ready = await sets.createSet(name: 'Ready');
      await sets.addSongs(ready, [a]);
      await sets.addMarker(ready, SetItemType.pause, 'Break');
      final empty = await sets.createSet(name: 'Empty');
      final missingFile = await sets.createSet(name: 'Missing file');
      await sets.addSongs(missingFile, [b]);
      await songs.addAttachment(b, name: 'Q', bytes: Uint8List.fromList([2]));
      final missingSong = await sets.createSet(name: 'Missing song');
      // A set item whose song is not on this device (e.g. not synced yet).
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: 'item-x',
              setId: missingSong,
              position: 0,
              type: SetItemType.song,
            ),
          );

      final fileB = (await songs.getAttachments(b)).single.fileName;
      await File('${dir.path}/$fileB').delete();
      // Another band's set is not part of this band's status.
      final other = SetRepository(db, sets.storage, bandId: 'other');
      await db
          .into(db.bands)
          .insert(BandsCompanion.insert(id: 'other', name: 'Other'));
      final otherSet = await other.createSet(name: 'Other');
      await other.addSongs(otherSet, [b]);

      final stream = sets.watchNotOfflineReady();
      expect(await stream.first, {missingFile, missingSong});
      expect(await sets.isOfflineReady(ready), isTrue);
      expect(await sets.isOfflineReady(empty), isTrue);
      expect(await sets.isOfflineReady(missingFile), isFalse);
      expect(await sets.isOfflineReady(missingSong), isFalse);
      expect(await other.isOfflineReady(otherSet), isFalse);

      // Removing the song with the missing file makes the set ready.
      await songs.deleteSong(b);
      expect(await sets.watchNotOfflineReady().first, {missingSong});
    });
  });
}
