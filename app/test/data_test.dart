import 'dart:io';
import 'dart:typed_data';

import 'dart:convert';

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
    final storage = AttachmentStorage(dir);
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

    test('updateSource bumps revision and keeps title if missing', () async {
      final id = await songs.createSong(title: 'Keep me');
      await songs.updateSource(id, '[C]No title here');
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Keep me');
      expect(song.revision, 1);
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
      expect(summary.set.revision, greaterThan(0));
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
  });
}
