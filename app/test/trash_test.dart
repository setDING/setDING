import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/trash.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

// Trash of ADR-0043.
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  var now = DateTime(2026, 11, 20, 12);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_trash');
    storage = FileAttachmentStorage(dir);
    now = DateTime(2026, 11, 20, 12);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  TrashRepository trash() => TrashRepository(db, storage, clock: () => now);

  /// Moves the deletion of all deleted records [days] into the past.
  Future<void> age(int days) async {
    final at = DateTime.now().subtract(Duration(days: days));
    await (db.update(db.songs)..where((s) => s.deleted.equals(true))).write(
      SongsCompanion(deletedAt: Value(at)),
    );
    await (db.update(db.setlists)..where((s) => s.deleted.equals(true))).write(
      SetlistsCompanion(deletedAt: Value(at)),
    );
    await (db.update(db.attachments)..where((a) => a.deleted.equals(true)))
        .write(AttachmentsCompanion(deletedAt: Value(at)));
  }

  group('local library', () {
    late SongRepository songs;
    late SetRepository sets;

    setUp(() {
      now = DateTime.now();
      songs = SongRepository(db, storage);
      sets = SetRepository(db, storage);
    });

    test('a deleted song is in the trash and comes back with its '
        'attachments', () async {
      final id = await songs.createSong(source: '{title: Gone}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final older = await songs.addAttachment(id, name: 'Old', bytes: pdf);
      final first = (await songs.getAttachments(id))
          .firstWhere((a) => a.id == older);
      await songs.deleteAttachment(first);
      // Deletion times are stored in seconds: deleted a while before.
      await (db.update(db.attachments)..where((a) => a.id.equals(older))).write(
        AttachmentsCompanion(
          deletedAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
        ),
      );
      await songs.deleteSong(id);

      final deleted = await trash().watchSongs(localBandId).first;
      expect([for (final s in deleted) s.title], ['Gone']);
      expect(deleted.single.deletedAt, isNotNull);

      await trash().restoreSong(id);
      expect(await trash().watchSongs(localBandId).first, isEmpty);
      expect((await songs.getSong(id))!.deleted, isFalse);
      expect(
        [for (final a in await songs.getAttachments(id)) a.name],
        ['Score'],
        reason: 'the attachment deleted before stays deleted',
      );
    });

    test('a deleted set keeps its items and comes back complete', () async {
      final song = await songs.createSong(source: '{title: A}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [song]);
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await sets.deleteSet(setId);
      expect(await sets.watchSets().first, isEmpty);
      expect(
        [for (final s in await trash().watchSets(localBandId).first) s.name],
        ['Gig'],
      );

      await trash().restoreSet(setId);
      final restored = (await sets.watchSets().first).single;
      expect(restored.itemCount, 2);
      expect(await trash().watchSets(localBandId).first, isEmpty);
    });

    test('the undo still works on a set that keeps its items', () async {
      final setId = await sets.createSet(name: 'Gig');
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      final deleted = await sets.deleteSet(setId);
      await sets.restoreSet(deleted);
      expect((await sets.watchSets().first).single.itemCount, 1);
    });

    test('files of deleted songs are kept for the trash', () async {
      final id = await songs.createSong(source: '{title: Gone}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final file = (await songs.getAttachments(id)).single.fileName;
      final deleted = await songs.deleteSong(id);
      await songs.purgeFiles(deleted.attachments);
      await songs.purgeDeletedFiles();
      expect(await storage.exists(file), isTrue);
    });

    test('after 30 days everything is removed with its files', () async {
      final id = await songs.createSong(source: '{title: Gone}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final file = (await songs.getAttachments(id)).single.fileName;
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(transpose: 2),
      );
      final kept = await songs.createSong(source: '{title: Kept}');
      final setId = await sets.createSet(name: 'Old gig');
      await sets.addSongs(setId, [kept]);
      await songs.deleteSong(id);
      await sets.deleteSet(setId);
      await age(29);
      expect(await trash().purgeLocal(), 0);
      await age(31);

      expect(await trash().purgeLocal(), 3);
      expect(await songs.getSong(id), isNull);
      expect(await storage.exists(file), isFalse);
      expect(await db.select(db.personalOverlays).get(), isEmpty);
      expect(await db.select(db.setlists).get(), isEmpty);
      expect(await db.select(db.setItems).get(), isEmpty);
      expect((await songs.getSong(kept))!.deleted, isFalse);
      expect(await trash().watchSongs(localBandId).first, isEmpty);
    });

    test('deleting permanently removes songs and sets with their files '
        '(#866)', () async {
      final id = await songs.createSong(source: '{title: Gone}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final file = (await songs.getAttachments(id)).single.fileName;
      final kept = await songs.createSong(source: '{title: Kept}');
      final setId = await sets.createSet(name: 'Old gig');
      await sets.addSongs(setId, [kept]);
      await songs.deleteSong(id);
      await sets.deleteSet(setId);

      await trash().purgeSongs([id, kept]);
      await trash().purgeSets([setId]);
      expect(await songs.getSong(id), isNull);
      expect(await storage.exists(file), isFalse);
      expect(await db.select(db.attachments).get(), isEmpty);
      expect(await db.select(db.setlists).get(), isEmpty);
      expect(await db.select(db.setItems).get(), isEmpty);
      expect(
        (await songs.getSong(kept))!.deleted,
        isFalse,
        reason: 'only deleted songs are purged',
      );
      expect(await trash().watchSongs(localBandId).first, isEmpty);
    });

    test('records deleted more than 30 days ago are not shown', () async {
      final id = await songs.createSong(source: '{title: Gone}');
      await songs.deleteSong(id);
      await age(31);
      expect(await trash().watchSongs(localBandId).first, isEmpty);
    });
  });

  group('synced library', () {
    late FakeSyncBackend server;
    late SyncEngine engine;
    late SongRepository songs;
    late SetRepository sets;

    setUp(() async {
      now = DateTime.now();
      server = FakeSyncBackend(user: _ann);
      server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      final bands = BandService(db, server);
      await bands.refresh();
      engine = SyncEngine(
        db,
        server,
        bands,
        copies: BandCopyService(db, storage),
      );
      songs = SongRepository(db, storage, libraryId: 'o1');
      sets = SetRepository(db, storage, bandId: 'b1');
    });

    test('the deletion time and the items of a deleted set reach the '
        'server', () async {
      final setId = await sets.createSet(name: 'Gig');
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await engine.sync();
      await sets.deleteSet(setId);
      final local = (await (db.select(
        db.setlists,
      )..where((s) => s.id.equals(setId))).getSingle());
      await engine.sync();

      final remote = server.sets[setId]!;
      expect(remote.deleted, isTrue);
      expect(remote.deletedAt, local.deletedAt);
      expect([for (final i in remote.items) i.note], ['Break']);
    });

    test('a set deleted on another device is in the trash with its items '
        'and can be restored', () async {
      final setId = await sets.createSet(name: 'Gig');
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await engine.sync();
      final remote = server.sets[setId]!;
      server.putSet(
        RemoteSet(
          id: setId,
          bandId: 'b1',
          name: 'Gig',
          items: remote.items,
          deleted: true,
          deletedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      await engine.sync();
      expect(
        [for (final s in await trash().watchSets('b1').first) s.name],
        ['Gig'],
      );

      await trash().restoreSet(setId);
      await engine.sync();
      expect(server.sets[setId]!.deleted, isFalse);
      expect(server.sets[setId]!.items, hasLength(1));
      expect((await sets.watchSets().first).single.itemCount, 1);
    });

    test('a song restored from the trash is pushed and its files are '
        'downloaded again', () async {
      final id = await songs.createSong(source: '{title: Song}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      await engine.sync();
      final a = (await songs.getAttachments(id)).single;
      final deleted = await songs.deleteSong(id);
      await engine.sync();
      await songs.purgeFiles(deleted.attachments);
      expect(await storage.exists(a.fileName), isFalse);

      await trash().restoreSong(id);
      await engine.sync();
      expect(server.songs[id]!.deleted, isFalse);
      expect(server.songs[id]!.deletedAt, isNull);
      expect((await songs.getAttachments(id)).single.id, a.id);
      expect(await storage.exists(a.fileName), isTrue);
    });

    test(
      'a song deleted permanently is pushed as a tombstone (#866)',
      () async {
        final id = await songs.createSong(source: '{title: Song}');
        await songs.addAttachment(id, name: 'Score', bytes: pdf);
        await engine.sync();
        final file = (await songs.getAttachments(id)).single.fileName;
        await songs.deleteSong(id);
        await engine.sync();

        await trash().purgeSongs([id]);
        expect(await trash().watchSongs('o1').first, isEmpty);
        expect(await storage.exists(file), isFalse);
        await engine.sync();
        expect(server.songs[id]!.purged, isTrue);
        expect(server.songs[id]!.deleted, isTrue);
      },
    );

    test('a set deleted permanently is pushed as a tombstone (#866)', () async {
      final setId = await sets.createSet(name: 'Gig');
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await engine.sync();
      await sets.deleteSet(setId);
      await engine.sync();

      await trash().purgeSets([setId]);
      expect(await trash().watchSets('b1').first, isEmpty);
      await engine.sync();
      expect(server.sets[setId]!.purged, isTrue);
      expect(server.sets[setId]!.items, isEmpty);
    });

    // ADR-0070: a single deleted PDF counts against the storage until it is
    // purged; organization admins and librarians purge it at once.
    test('a PDF deleted on its own is in the trash, comes back, and is '
        'purged as a tombstone', () async {
      final id = await songs.createSong(source: '{title: Song}');
      final kept = await songs.addAttachment(id, name: 'Kept', bytes: pdf);
      final gone = await songs.addAttachment(id, name: 'Horns', bytes: pdf);
      final other = await songs.createSong(source: '{title: Other}');
      await songs.addAttachment(other, name: 'With song', bytes: pdf);
      await engine.sync();
      Future<AttachmentEntry> row(String a) =>
          (db.select(db.attachments)..where((x) => x.id.equals(a))).getSingle();
      await songs.deleteAttachment(await row(gone));
      // The attachments of a deleted song go with their song.
      await songs.deleteSong(other);
      await engine.sync();
      expect(
        [
          for (final (a, song) in await trash().watchAttachments('o1').first)
            (a.name, song),
        ],
        [('Horns', 'Song')],
      );
      // The local library's attachments are not listed.
      expect(await trash().watchAttachments(localBandId).first, isEmpty);

      await trash().restoreAttachments([gone]);
      expect((await row(gone)).deleted, isFalse);
      await engine.sync();
      expect(server.attachments[gone]!.deleted, isFalse);

      await songs.deleteAttachment(await row(gone));
      await engine.sync();
      final file = (await row(gone)).fileName;
      await trash().purgeAttachments([gone]);
      expect(await trash().watchAttachments('o1').first, isEmpty);
      expect(await storage.exists(file), isFalse);
      await engine.sync();
      expect(server.attachments[gone]!.purged, isTrue);
      expect(server.attachments[kept]!.purged, isFalse);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    });

    test('a PDF that is not deleted is not purged', () async {
      final id = await songs.createSong(source: '{title: Song}');
      final a = await songs.addAttachment(id, name: 'Score', bytes: pdf);
      await engine.sync();
      await trash().purgeAttachments([a]);
      await engine.sync();
      expect(server.attachments[a]!.purged, isFalse);
      expect((await songs.getAttachments(id)).single.purged, isFalse);
    });

    test('purged records leave the trash', () async {
      final id = await songs.createSong(source: '{title: Song}');
      await engine.sync();
      await songs.deleteSong(id);
      await engine.sync();
      final remote = server.songs[id]!;
      server.putSong(
        RemoteSong(
          id: id,
          organizationId: 'o1',
          title: remote.title,
          chordpro: '',
          deleted: true,
          deletedAt: remote.deletedAt,
          purged: true,
        ),
      );
      await engine.sync();
      expect(await trash().watchSongs('o1').first, isEmpty);
      final song = await (db.select(
        db.songs,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(song.purged, isTrue);
    });
  });
}
