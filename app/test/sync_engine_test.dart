import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show TableUpdateQuery, UpdateKind, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/engine/annotation_sync.dart';
import 'package:setding/sync/engine/arrangement_sync.dart';
import 'package:setding/sync/engine/overlay_sync.dart';
import 'package:setding/sync/engine/sync_store.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend server;
  late SyncEngine engine;
  late SongRepository songs;
  late SetRepository sets;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_sync');
    final storage = FileAttachmentStorage(dir);
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
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();

  RemoteSong remoteSong(
    String id,
    String source, {
    String title = 'Remote',
    bool deleted = false,
  }) => RemoteSong(
    id: id,
    organizationId: 'o1',
    title: title,
    chordpro: source,
    deleted: deleted,
  );

  group('songs', () {
    test('pushes new and changed songs of the organization', () async {
      final id = await songs.createSong(source: '{title: New}\n[C]x');
      expect(await outbox(), hasLength(1));

      final report = await engine.sync();
      expect(report.pushed, 1);
      expect(report.error, isNull);
      expect(server.songs[id]!.title, 'New');
      final local = (await songs.getSong(id))!;
      expect(local.revision, server.songs[id]!.revision);
      expect(await outbox(), isEmpty);

      await songs.updateSource(id, '{title: Changed}\n[D]y');
      await engine.sync();
      expect(server.songs[id]!.chordpro, contains('[D]y'));
      expect((await songs.getSong(id))!.revision, server.songs[id]!.revision);
    });

    test('a sync without band refresh uses the stored bands', () async {
      final calls = server.fetchOrganizationsCalls;
      server.putSong(remoteSong('s1', '{title: Quick}'));
      final report = await engine.sync(refreshBands: false);
      expect(report.pulled, 1);
      expect(server.fetchOrganizationsCalls, calls);
      await engine.sync();
      expect(server.fetchOrganizationsCalls, calls + 1);
    });

    test('pulled songs are found by the search', () async {
      server.putSong(remoteSong('s1', '{title: Pulled}\n[C]Moon[G]light'));
      await engine.sync();
      expect(
        (await songs.watchSongs(query: 'moonlight').first).single.id,
        's1',
      );
    });

    test('never syncs the local library', () async {
      final local = SongRepository(db, FileAttachmentStorage(dir));
      await local.createSong(source: '{title: Private}');
      expect(await outbox(), isEmpty);
      await engine.sync();
      expect(server.songs, isEmpty);
    });

    test(
      'pulls songs with their metadata, only changes since the cursor',
      () async {
        server.putSong(
          remoteSong('s1', '{title: Hello}\n{key: G}\n{tag: Rock}'),
        );
        var report = await engine.sync();
        expect(report.pulled, 1);
        final song = (await songs.getSong('s1'))!;
        expect(song.title, 'Hello');
        expect(song.songKey, 'G');
        expect(songTags(song), ['Rock']);
        expect(
          await outbox(),
          isEmpty,
          reason: 'pulled songs are not pushed back',
        );

        report = await engine.sync();
        expect(report.pulled, 0);
        expect(server.pushCount, 0);
      },
    );

    test(
      'a song deleted on the server disappears and leaves its sets',
      () async {
        server.putSong(remoteSong('s1', '{title: Gone}'));
        await engine.sync();
        final setId = await sets.createSet(name: 'Gig');
        await sets.addSongs(setId, ['s1']);
        await engine.sync();

        server.putSong(remoteSong('s1', '{title: Gone}', deleted: true));
        await engine.sync();
        expect(await songs.getSong('s1'), isNull);
        expect(await sets.getItems(setId), isEmpty);
      },
    );

    test('a song created and deleted before syncing is never sent', () async {
      final id = await songs.createSong(source: '{title: Oops}');
      await songs.deleteSong(id);
      await engine.sync();
      expect(server.songs, isEmpty);
      expect(await outbox(), isEmpty);
    });

    test('offline: changes stay in the outbox', () async {
      await songs.createSong(source: '{title: Later}');
      server.failWith = BackendErrorKind.network;
      final report = await engine.sync();
      expect(report.error, BackendErrorKind.network);
      expect(await outbox(), hasLength(1));

      server.failWith = null;
      expect((await engine.sync()).pushed, 1);
      expect(await outbox(), isEmpty);
    });

    test('a create whose answer got lost is retried as update', () async {
      final id = await songs.createSong(source: '{title: Twice}\n[C]local');
      // The server has it already (first attempt), but the device never
      // got the answer; the cursor is past it, so the pull does not see it.
      final stored = server.putSong(remoteSong(id, '{title: Twice}'));
      await db
          .into(db.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              scope: 'o1',
              collection: 'songs',
              revision: Value(stored.revision),
            ),
          );
      final report = await engine.sync();
      expect(report.error, isNull);
      expect(server.songs[id]!.chordpro, contains('local'));
      expect(await outbox(), isEmpty);
    });
  });

  group('conflicts', () {
    Future<String> pulledSong() async {
      server.putSong(remoteSong('s1', '{title: Base}\n[C]base'));
      await engine.sync();
      return 's1';
    }

    Future<SongConflict?> conflict(String id) => (db.select(
      db.songConflicts,
    )..where((c) => c.songId.equals(id))).getSingleOrNull();

    test('a song changed on both sides is never overwritten', () async {
      final id = await pulledSong();
      await songs.updateSource(id, '{title: Base}\n[C]mine');
      server.putSong(remoteSong(id, '{title: Base}\n[C]theirs'));

      final report = await engine.sync();
      expect(report.conflicts, 1);
      expect((await songs.getSong(id))!.chordproSource, contains('mine'));
      expect(server.songs[id]!.chordpro, contains('theirs'));
      expect((await conflict(id))!.chordproSource, contains('theirs'));

      // Nothing is pushed while the conflict is open.
      await engine.sync();
      expect(server.songs[id]!.chordpro, contains('theirs'));
    });

    test('keep mine: the local version replaces the server version', () async {
      final id = await pulledSong();
      await songs.updateSource(id, '{title: Base}\n[C]mine');
      server.putSong(remoteSong(id, '{title: Base}\n[C]theirs'));
      await engine.sync();

      await engine.keepLocal(id);
      await engine.sync();
      expect(await conflict(id), isNull);
      expect(server.songs[id]!.chordpro, contains('mine'));
      expect(await outbox(), isEmpty);
    });

    test('take server: the local change is dropped', () async {
      final id = await pulledSong();
      await songs.updateSource(id, '{title: Base}\n[C]mine');
      server.putSong(remoteSong(id, '{title: Base}\n[C]theirs'));
      await engine.sync();

      await engine.takeServer(id);
      expect((await songs.getSong(id))!.chordproSource, contains('theirs'));
      expect(await conflict(id), isNull);
      expect(await outbox(), isEmpty);
      await engine.sync();
      expect(server.songs[id]!.chordpro, contains('theirs'));
    });

    test('keep both: the local version becomes a new song', () async {
      final id = await pulledSong();
      await songs.updateSource(id, '{title: Base}\n[C]mine');
      server.putSong(remoteSong(id, '{title: Base}\n[C]theirs'));
      await engine.sync();

      final copy = await engine.keepBoth(id);
      await engine.sync();
      expect(server.songs[id]!.chordpro, contains('theirs'));
      expect(server.songs[copy]!.chordpro, contains('mine'));
      expect((await songs.getSong(id))!.chordproSource, contains('theirs'));
    });

    test('a conflict found when pushing is stored too', () async {
      final id = await pulledSong();
      await songs.updateSource(id, '{title: Base}\n[C]mine');
      // The server moved on, but the cursor already says "seen".
      final newer = server.putSong(remoteSong(id, '{title: Base}\n[C]theirs'));
      await db
          .into(db.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              scope: 'o1',
              collection: 'songs',
              revision: Value(newer.revision),
            ),
          );
      final report = await engine.sync();
      expect(report.conflicts, 1);
      expect((await conflict(id))!.revision, newer.revision);
    });
  });

  group('sets', () {
    test('pushes a set with its items as JSON', () async {
      server.putSong(remoteSong('s1', '{title: A}'));
      await engine.sync();
      final setId = await sets.createSet(name: 'Gig', venue: 'Bern');
      await sets.addSongs(setId, ['s1']);
      await sets.addMarker(setId, SetItemType.pause, 'Break');
      final item = (await sets.getItems(setId)).first.item;
      await sets.setItemTranspose(item.id, 2);

      await engine.sync();
      final remote = server.sets[setId]!;
      expect(remote.name, 'Gig');
      expect(remote.venue, 'Bern');
      // The wire format (ADR-0015).
      expect(
        [for (final i in remote.items) i.toJson()],
        [
          {'id': item.id, 'type': 'song', 'song': 's1', 'transpose': 2},
          {
            'id': (await sets.getItems(setId)).last.item.id,
            'type': 'pause',
            'note': 'Break',
          },
        ],
      );
      expect(await outbox(), isEmpty);
    });

    test('pulls sets; unknown songs become missing items', () async {
      server.putSong(remoteSong('s1', '{title: A}'));
      server.putSet(
        const RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Remote gig',
          items: [
            RemoteSetItem(
              id: 'i1',
              type: SetItemType.song,
              songId: 's1',
              sequence: 'V, C',
            ),
            RemoteSetItem(id: 'i2', type: SetItemType.song, songId: 'unknown'),
            RemoteSetItem(id: 'i3', type: SetItemType.text, note: 'Encore'),
          ],
        ),
      );
      await engine.sync();
      final items = await sets.getItems('set1');
      expect(items.map((i) => i.item.id), ['i1', 'i2', 'i3']);
      expect(items[0].song?.id, 's1');
      expect(items[0].item.sequence, 'V, C');
      expect(items[1].song, isNull);
      expect(items[2].item.note, 'Encore');
      expect((await sets.watchSets().first).single.set.name, 'Remote gig');
      expect(await outbox(), isEmpty);
    });

    test('keeps the last editor of sets (ADR-0045)', () async {
      server.putSet(
        const RemoteSet(id: 'set1', bandId: 'b1', name: 'Gig'),
        by: 'bob',
      );
      await engine.sync();
      expect((await sets.getSet('set1'))!.updatedBy, 'bob');

      // A local change names the signed-in user until the server answers.
      final mine = SetRepository(
        db,
        FileAttachmentStorage(dir),
        bandId: 'b1',
        userId: 'ann',
      );
      await mine.updateSet('set1', name: 'Mine');
      expect((await sets.getSet('set1'))!.updatedBy, 'ann');
      final id = await mine.createSet(name: 'New');
      expect((await sets.getSet(id))!.updatedBy, 'ann');
      await engine.sync();
      expect(server.sets['set1']!.updatedBy, 'ann');
      expect(server.sets[id]!.updatedBy, 'ann');

      // The server's answer is kept, also when the change named nobody.
      await sets.updateSet(id, name: 'Renamed');
      expect((await sets.getSet(id))!.updatedBy, isNull);
      await engine.sync();
      expect((await sets.getSet(id))!.updatedBy, 'ann');

      server.putSet(
        const RemoteSet(id: 'set1', bandId: 'b1', name: 'Theirs'),
        by: 'carol',
      );
      await engine.sync();
      expect((await sets.getSet('set1'))!.updatedBy, 'carol');

      // The local band has no editor.
      final local = SetRepository(
        db,
        FileAttachmentStorage(dir),
        userId: 'ann',
      );
      final localId = await local.createSet(name: 'Private');
      expect((await local.getSet(localId))!.updatedBy, isNull);
    });

    test(
      'last writer wins: a pending local change is kept and pushed',
      () async {
        server.putSet(const RemoteSet(id: 'set1', bandId: 'b1', name: 'Old'));
        await engine.sync();
        await sets.updateSet('set1', name: 'Mine');
        server.putSet(
          const RemoteSet(id: 'set1', bandId: 'b1', name: 'Theirs'),
        );
        await engine.sync();
        expect(server.sets['set1']!.name, 'Mine');
        expect((await sets.watchSets().first).single.set.name, 'Mine');
      },
    );

    test('a set deleted on the server disappears', () async {
      server.putSet(const RemoteSet(id: 'set1', bandId: 'b1', name: 'Gig'));
      await engine.sync();
      server.putSet(
        const RemoteSet(id: 'set1', bandId: 'b1', name: 'Gig', deleted: true),
      );
      await engine.sync();
      expect(await sets.watchSets().first, isEmpty);
    });

    test('changes without permission stay local', () async {
      final setId = await sets.createSet(name: 'Gig');
      // Ann lost her admin roles meanwhile.
      server.members.single.role = BandRole.member;
      server.orgMembers.single.role = OrgRole.member;
      server.addMember(
        'b1',
        const AuthUser(id: 'x', email: 'x', name: 'X'),
        BandRole.admin,
      );
      final report = await engine.sync();
      expect(report.error, isNull);
      expect(server.sets.containsKey(setId), isFalse);
      expect(await outbox(), isEmpty);
      expect((await sets.watchSets().first).single.set.id, setId);
    });
  });

  group('attachments (ADR-0009)', () {
    late AttachmentStorage storage;
    final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    setUp(() => storage = FileAttachmentStorage(dir));

    test('uploads PDFs after their song; images stay on the device', () async {
      final id = await songs.createSong(source: '{title: With score}');
      final a = await songs.addAttachment(
        id,
        name: 'Score',
        bytes: pdf,
        pages: 2,
      );
      await songs.addAttachment(
        id,
        name: 'cover.png',
        bytes: Uint8List.fromList([1, 2]),
        extension: 'png',
      );
      await engine.sync();
      expect(server.attachments.keys, [a]);
      final remote = server.attachments[a]!;
      expect(remote.name, 'Score');
      expect(remote.pages, 2);
      expect(server.files[remote.file], pdf);
      final local = (await songs.getAttachments(id))
          .firstWhere((x) => x.id == a);
      expect(local.remoteFile, remote.file);
      expect(local.revision, remote.revision);
      expect(await outbox(), isEmpty);
    });

    test('downloads PDFs of other devices', () async {
      server.putSong(remoteSong('s1', '{title: Song}'));
      server.putAttachment(
        const RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: 'Lead sheet',
          sizeBytes: 13,
        ),
        bytes: pdf,
      );
      final report = await engine.sync();
      expect(report.downloaded, 1);
      final local = (await songs.getAttachments('s1')).single;
      expect(local.name, 'Lead sheet');
      expect(await storage.file(local.fileName).readAsBytes(), pdf);

      // Already there: not downloaded again.
      await engine.sync();
      expect(server.downloads, 1);
    });

    void putAttachments(int count, {List<int>? bytes}) {
      server.putSong(remoteSong('s1', '{title: Song}'));
      for (var i = 0; i < count; i++) {
        server.putAttachment(
          RemoteAttachment(
            id: 'a$i',
            organizationId: 'o1',
            songId: 's1',
            name: 'Sheet $i',
          ),
          bytes: bytes,
        );
      }
    }

    test(
      'downloads several files in one session; refused ones are skipped',
      () async {
        putAttachments(5, bytes: pdf);
        server.files.remove('a2_abc.pdf'); // refused by the server

        final report = await engine.sync();
        expect(report.downloaded, 4);
        expect(report.error, isNull);
        expect(server.downloadsOpened, 1);
        expect(server.downloadsClosed, 1);
        for (final a in await songs.getAttachments('s1')) {
          expect(await storage.exists(a.fileName), a.id != 'a2', reason: a.id);
        }
        expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
      },
    );

    test('a broken connection stops the downloads, no partial file', () async {
      putAttachments(SyncEngine.parallelDownloads + 3, bytes: pdf);
      server.offlineFiles.add('a0_abc.pdf');

      final report = await engine.sync();
      expect(report.error, BackendErrorKind.network);
      expect(server.downloadsClosed, 1);
      // The workers stop taking new files; the broken one is not stored.
      expect(server.downloads, lessThan(SyncEngine.parallelDownloads + 3));
      final a0 = (await songs.getAttachments('s1'))
          .firstWhere((a) => a.id == 'a0');
      expect(await storage.exists(a0.fileName), isFalse);
      expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);

      // Back online: the rest arrives.
      server.offlineFiles.clear();
      final retry = await engine.sync();
      expect(retry.error, isNull);
      for (final a in await songs.getAttachments('s1')) {
        expect(await storage.exists(a.fileName), isTrue);
      }
    });

    test('renames and deletions travel both ways', () async {
      server.putSong(remoteSong('s1', '{title: Song}'));
      server.putAttachment(
        const RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: 'Old',
        ),
        bytes: pdf,
      );
      await engine.sync();
      final local = (await songs.getAttachments('s1')).single;

      await songs.renameAttachment('a1', 'New');
      await engine.sync();
      expect(server.attachments['a1']!.name, 'New');

      final current = server.attachments['a1']!;
      server.putAttachment(
        RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: current.name,
          file: current.file,
          deleted: true,
        ),
      );
      await engine.sync();
      expect(await songs.getAttachments('s1'), isEmpty);
      expect(await storage.exists(local.fileName), isFalse);
    });

    test('a local deletion is pushed', () async {
      final id = await songs.createSong(source: '{title: Song}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      await engine.sync();
      final a = (await songs.getAttachments(id)).single;
      await songs.deleteAttachment(a);
      await engine.sync();
      expect(server.attachments[a.id]!.deleted, isTrue);
    });

    test('a failed download does not stop the others', () async {
      server.putSong(remoteSong('s1', '{title: Song}'));
      server.putAttachment(
        const RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: 'Broken',
          file: 'missing.pdf',
        ),
      );
      server.putAttachment(
        const RemoteAttachment(
          id: 'a2',
          organizationId: 'o1',
          songId: 's1',
          name: 'Fine',
        ),
        bytes: pdf,
      );
      final report = await engine.sync();
      expect(report.error, isNull);
      expect(report.downloaded, 1);
    });

    test('attachments of the local library are never uploaded', () async {
      final local = SongRepository(db, storage);
      final id = await local.createSong(source: '{title: Private}');
      await local.addAttachment(id, name: 'Score', bytes: pdf);
      await engine.sync();
      expect(server.attachments, isEmpty);
      expect(await outbox(), isEmpty);
    });
  });
  group('undo of deletions (#267)', () {
    final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    test('a pushed song deletion is undone without a conflict', () async {
      final id = await songs.createSong(source: '{title: Back}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [id]);
      await engine.sync();

      final deleted = await songs.deleteSong(id);
      await engine.sync();
      expect(server.songs[id]!.deleted, isTrue);
      expect(server.sets[setId]!.items, isEmpty);

      await songs.restoreSong(deleted);
      // The next run first pulls the deletion it pushed itself.
      final report = await engine.sync();
      expect(report.error, isNull);
      expect(report.conflicts, 0);
      expect(await db.select(db.songConflicts).get(), isEmpty);
      expect(server.songs[id]!.deleted, isFalse);
      expect(server.sets[setId]!.items.single.songId, id);
      expect(await outbox(), isEmpty);

      // Stays restored, with its attachment, after the next pull.
      await engine.sync();
      expect((await songs.getSong(id))!.title, 'Back');
      expect((await songs.getAttachments(id)).single.name, 'Score');
      expect(server.attachments.values.single.deleted, isFalse);
    });

    test('an undo before the sync leaves the server unchanged', () async {
      final id = await songs.createSong(source: '{title: Stay}');
      await engine.sync();
      final revision = server.songs[id]!.revision;
      await songs.restoreSong(await songs.deleteSong(id));
      final report = await engine.sync();
      expect(report.conflicts, 0);
      expect(server.songs[id]!.deleted, isFalse);
      expect(server.songs[id]!.revision, greaterThan(revision));
    });

    test('a new song deleted and restored around a sync is created', () async {
      final id = await songs.createSong(source: '{title: Late}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      final deleted = await songs.deleteSong(id);
      await engine.sync();
      expect(server.songs, isEmpty);

      await songs.restoreSong(deleted);
      await engine.sync();
      expect(server.songs[id]!.title, 'Late');
      // The file was kept for the undo, so it is uploaded.
      final a = server.attachments.values.single;
      expect(a.deleted, isFalse);
      expect(server.files[a.file], pdf);
    });

    test('a pushed attachment deletion is undone', () async {
      final id = await songs.createSong(source: '{title: Song}');
      await songs.addAttachment(id, name: 'Score', bytes: pdf);
      await engine.sync();
      final a = (await songs.getAttachments(id)).single;
      final deleted = await songs.deleteAttachment(a);
      await engine.sync();
      expect(server.attachments[a.id]!.deleted, isTrue);

      await songs.restoreAttachment(deleted);
      await engine.sync();
      expect(server.attachments[a.id]!.deleted, isFalse);
      expect((await songs.getAttachments(id)).single.id, a.id);
      await songs.purgeFiles([a]);
      expect(await FileAttachmentStorage(dir).exists(a.fileName), isTrue);
    });

    test('a pushed set deletion is undone with its items', () async {
      final id = await songs.createSong(source: '{title: A}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [id]);
      await sets.addMarker(setId, SetItemType.pause, 'Break');
      await engine.sync();
      final deleted = await sets.deleteSet(setId);
      await engine.sync();
      expect(server.sets[setId]!.deleted, isTrue);

      await sets.restoreSet(deleted);
      await engine.sync();
      final remote = server.sets[setId]!;
      expect(remote.deleted, isFalse);
      expect([for (final i in remote.items) i.songId ?? i.note], [id, 'Break']);
      await engine.sync();
      expect((await sets.watchSets().first).single.itemCount, 2);
    });
  });

  group('records from before the outbox (#29)', () {
    final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    test('songs, sets and PDFs that never synced are uploaded', () async {
      final songId = await songs.createSong(source: '{title: Old}');
      final a = await songs.addAttachment(songId, name: 'Score', bytes: pdf);
      final setId = await sets.createSet(name: 'Old gig');
      final local = SongRepository(db, FileAttachmentStorage(dir));
      await local.createSong(source: '{title: Private}');
      // Created by an app version without the outbox.
      await db.delete(db.syncOutbox).go();

      final report = await engine.sync();
      expect(report.error, isNull);
      expect(server.songs.keys, [songId]);
      expect(server.sets.keys, [setId]);
      expect(server.attachments.keys, [a]);
      expect(await outbox(), isEmpty);
    });

    test('a sync with nothing to add reports no new outbox entries', () async {
      await songs.createSong(source: '{title: Synced}');
      await engine.sync();
      var events = 0;
      final sub = db
          .tableUpdates(
            TableUpdateQuery.onTable(
              db.syncOutbox,
              limitUpdateKind: UpdateKind.insert,
            ),
          )
          .listen((_) => events++);
      await engine.sync();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, 0);
    });

    test('records without permission are not retried every sync', () async {
      await sets.createSet(name: 'Gig');
      await db.delete(db.syncOutbox).go();
      server.members.single.role = BandRole.member;
      server.orgMembers.single.role = OrgRole.member;
      server.addMember(
        'b1',
        const AuthUser(id: 'x', email: 'x', name: 'X'),
        BandRole.admin,
      );
      await engine.sync();
      await engine.sync();
      expect(server.pushCount, 0);
      expect(await outbox(), isEmpty);
    });
  });

  test('pulls a large library with sets and a conflict in one run', () async {
    // The first sync of a library: many songs (parsed outside the UI
    // isolate), sets referring to them, one song changed on both sides.
    final local = await songs.createSong(source: '{title: Mine}');
    await engine.sync();
    await songs.updateSource(local, '{title: Mine, changed here}');
    server.putSong(remoteSong(local, '{title: Mine, changed there}'));
    for (var i = 0; i < 60; i++) {
      server.putSong(remoteSong('s$i', '{title: Song $i}\n{key: A}'));
    }
    server.putSet(
      const RemoteSet(
        id: 'set1',
        bandId: 'b1',
        name: 'Gig',
        items: [
          RemoteSetItem(id: 'i1', type: SetItemType.song, songId: 's7'),
          RemoteSetItem(id: 'i2', type: SetItemType.song, songId: 'unknown'),
        ],
      ),
    );

    final report = await engine.sync();
    expect(report.conflicts, 1);
    expect((await songs.getSong('s59'))!.title, 'Song 59');
    expect((await songs.getSong('s59'))!.songKey, 'A');
    expect((await songs.getSong(local))!.title, 'Mine, changed here');
    final items = await sets.getItems('set1');
    expect(items.map((v) => v.song?.id), ['s7', null]);
  });

  group('band arrangements (ADR-0025)', () {
    late ArrangementRepository arrangements;

    setUp(() => arrangements = ArrangementRepository(db));

    test(
      'pushes an arrangement after its song, once per band and song',
      () async {
        final id = await songs.createSong(source: '{title: A}\n{key: G}\n[G]x');
        await arrangements.save(
          'b1',
          id,
          transpose: 2,
          sequence: 'V C',
          tempo: 90,
        );
        final report = await engine.sync();
        expect(report.error, isNull);
        final stored = server.arrangements.values.single;
        expect(stored.id, ArrangementSync.serverId('b1', id));
        expect(
          (stored.bandId, stored.songId, stored.transpose, stored.sequence),
          ('b1', id, 2, 'V C'),
        );
        expect(stored.tempo, 90);
        expect((await arrangements.get('b1', id))!.revision, stored.revision);
        expect(await outbox(), isEmpty);

        // Back to the song: the removal reaches the server.
        await arrangements.reset('b1', id);
        expect(await arrangements.get('b1', id), isNull);
        await engine.sync();
        expect(server.arrangements.values.single.deleted, isTrue);
      },
    );

    test('an unchanged arrangement is no arrangement', () async {
      final id = await songs.createSong(source: '{title: A}');
      await arrangements.save('b1', id, transpose: 0, sequence: ' ');
      expect(await arrangements.get('b1', id), isNull);
      expect(await outbox(), hasLength(1)); // only the song
    });

    test('pulls arrangements of the band; last writer wins', () async {
      final id = await songs.createSong(source: '{title: A}');
      await engine.sync();
      server.putArrangement(
        RemoteArrangement(
          id: ArrangementSync.serverId('b1', id),
          bandId: 'b1',
          songId: id,
          transpose: -3,
          tempo: 120,
        ),
      );
      await engine.sync();
      final local = (await arrangements.get('b1', id))!;
      expect((local.transpose, local.tempo), (-3, 120));

      // A pending local change wins over the server and is pushed.
      await arrangements.save('b1', id, transpose: 5);
      server.putArrangement(
        RemoteArrangement(
          id: ArrangementSync.serverId('b1', id),
          bandId: 'b1',
          songId: id,
          transpose: 1,
        ),
      );
      await engine.sync();
      expect((await arrangements.get('b1', id))!.transpose, 5);
      expect(server.arrangements.values.single.transpose, 5);
    });

    test('keeps the last editor of arrangements (ADR-0045)', () async {
      final id = await songs.createSong(source: '{title: A}');
      await engine.sync();
      server.putArrangement(
        RemoteArrangement(
          id: ArrangementSync.serverId('b1', id),
          bandId: 'b1',
          songId: id,
          transpose: 2,
        ),
        by: 'bob',
      );
      await engine.sync();
      expect((await arrangements.get('b1', id))!.updatedBy, 'bob');

      // A local change names the signed-in user; the server's answer is
      // kept.
      final mine = ArrangementRepository(db, userId: 'ann');
      await mine.save('b1', id, transpose: 3);
      expect((await arrangements.get('b1', id))!.updatedBy, 'ann');
      await engine.sync();
      expect(server.arrangements.values.single.updatedBy, 'ann');
      expect((await arrangements.get('b1', id))!.updatedBy, 'ann');

      server.putArrangement(
        RemoteArrangement(
          id: ArrangementSync.serverId('b1', id),
          bandId: 'b1',
          songId: id,
          transpose: 4,
        ),
        by: 'carol',
      );
      await engine.sync();
      expect((await arrangements.get('b1', id))!.updatedBy, 'carol');

      // Removing it names the user too; the local band has no editor.
      await mine.reset('b1', id);
      final removed = await (db.select(
        db.bandArrangements,
      )..where((a) => a.songId.equals(id))).getSingle();
      expect(removed.updatedBy, 'ann');
      await mine.save(localBandId, id, transpose: 1);
      expect((await mine.get(localBandId, id))!.updatedBy, isNull);
    });

    test('members cannot push arrangements; the change stays local', () async {
      final id = await songs.createSong(source: '{title: A}');
      await engine.sync();
      server.members.single.role = BandRole.member;
      server.orgMembers.single.role = OrgRole.member;
      server.addMember(
        'b1',
        const AuthUser(id: 'x', email: 'x', name: 'X'),
        BandRole.admin,
      );
      await arrangements.save('b1', id, transpose: 2);
      await engine.sync();
      expect(server.arrangements, isEmpty);
      expect(await outbox(), isEmpty);
    });
  });

  group('personal adjustments (ADR-0020)', () {
    late SongRepository mine;

    setUp(() async {
      mine = SongRepository(
        db,
        FileAttachmentStorage(dir),
        libraryId: 'o1',
        userId: 'ann',
      );
      server.putSong(remoteSong('s1', '{title: Song}\n{key: G}'));
      await engine.sync();
    });

    Future<void> adjust(
      SongRepository repo,
      SongOverlay Function(SongOverlay) f,
    ) async => repo.saveOverlay(f(await repo.getOverlay('s1')));

    test(
      'pushes own adjustments with a record ID shared by all devices',
      () async {
        await adjust(
          mine,
          (o) => o.copyWith(
            transpose: 2,
            notes: const Value('Solo'),
            verseChords: VerseChords.stacked,
          ),
        );
        final report = await engine.sync();
        expect(report.error, isNull);
        final id = SyncEngine.overlayServerId('ann', 's1');
        final remote = server.overlays[id]!;
        expect(remote.userId, 'ann');
        expect(remote.data['transpose'], 2);
        expect(remote.data['notes'], 'Solo');
        expect(remote.data['verse_chords'], 'stacked');
        expect((await mine.getOverlay('s1')).revision, remote.revision);
        expect(await outbox(), isEmpty);
      },
    );

    test('pulls adjustments made on another device', () async {
      server.putOverlay(
        RemoteOverlay(
          id: SyncEngine.overlayServerId('ann', 's1'),
          userId: 'ann',
          songId: 's1',
          data: const {
            'transpose': -3,
            'capo_fret': 2,
            'font_scale': 1.2,
            'verse_chords': 'stacked',
          },
        ),
      );
      await engine.sync();
      final o = await mine.getOverlay('s1');
      expect((o.transpose, o.capoFret, o.fontScale), (-3, 2, 1.2));
      expect(o.verseChords, VerseChords.stacked);
      expect(
        await outbox(),
        isEmpty,
        reason: 'pulled changes are not pushed back',
      );

      // Removed on the other device.
      final id = SyncEngine.overlayServerId('ann', 's1');
      server.putOverlay(
        RemoteOverlay(id: id, userId: 'ann', songId: 's1', deleted: true),
      );
      await engine.sync();
      expect((await mine.getOverlay('s1')).transpose, 0);
    });

    test(
      'pushes and pulls the keyboard programs per profile (ADR-0042)',
      () async {
        const program = MidiProgram(msb: 0, lsb: 2, program: 12);
        await mine.setMidiProgram(
          's1',
          'nordStage3',
          program,
          deviceProfile: 'nordStage3',
        );
        await engine.sync();
        final id = SyncEngine.overlayServerId('ann', 's1');
        expect(
          server.overlays[id]!.midiPrograms,
          const MidiPrograms({'nordStage3': program}),
        );
        expect(server.overlays[id]!.midi, isNull, reason: 'never written');
        expect(
          server.overlays[id]!.data.containsKey('midi'),
          isFalse,
          reason: 'its own server field, not a key in data',
        );

        // Changed on another device.
        const other = MidiProgram(msb: 1, program: 7);
        server.putOverlay(
          RemoteOverlay(
            id: id,
            userId: 'ann',
            songId: 's1',
            data: server.overlays[id]!.data,
            midiPrograms: const MidiPrograms({'nordStage3': other}),
          ),
        );
        await engine.sync();
        expect(await mine.midiProgram('s1', 'nordStage3'), other);
        expect(await outbox(), isEmpty);

        // Removed here.
        await mine.removeMidiProgram(
          's1',
          'nordStage3',
          deviceProfile: 'nordStage3',
        );
        await engine.sync();
        expect(server.overlays[id]!.midiPrograms, const MidiPrograms());

        // Removed on another device.
        await mine.setMidiProgram(
          's1',
          'nordStage3',
          program,
          deviceProfile: 'nordStage3',
        );
        await engine.sync();
        server.putOverlay(
          RemoteOverlay(
            id: id,
            userId: 'ann',
            songId: 's1',
            data: server.overlays[id]!.data,
            midiPrograms: const MidiPrograms(),
          ),
        );
        await engine.sync();
        expect(await mine.midiProgram('s1', 'nordStage3'), isNull);
      },
    );

    test('a v0.16.0 program pulled from the server counts until the '
        'programs change (ADR-0042)', () async {
      final id = SyncEngine.overlayServerId('ann', 's1');
      const legacy = MidiProgram(msb: 0, lsb: 2, program: 12);
      server.putOverlay(
        RemoteOverlay(id: id, userId: 'ann', songId: 's1', midi: legacy),
      );
      await engine.sync();
      expect(await mine.midiProgram('s1', 'nordStage3'), legacy);
      await mine.setMidiProgram(
        's1',
        'generic',
        const MidiProgram(program: 1),
        deviceProfile: 'nordStage3',
      );
      await engine.sync();
      expect(server.overlays[id]!.midi, legacy, reason: 'kept for v0.16.0');
      expect(
        server.overlays[id]!.midiPrograms,
        const MidiPrograms({
          'nordStage3': legacy,
          'generic': MidiProgram(program: 1),
        }),
      );
    });

    test('the last writer wins for the keyboard program too', () async {
      await mine.setMidiProgram(
        's1',
        'nordStage3',
        const MidiProgram(program: 1),
        deviceProfile: 'nordStage3',
      );
      await engine.sync();
      final id = SyncEngine.overlayServerId('ann', 's1');
      server.putOverlay(
        RemoteOverlay(
          id: id,
          userId: 'ann',
          songId: 's1',
          midiPrograms: const MidiPrograms({
            'nordStage3': MidiProgram(program: 2),
          }),
        ),
      );
      await mine.setMidiProgram(
        's1',
        'nordStage3',
        const MidiProgram(program: 3),
        deviceProfile: 'nordStage3',
      );
      await engine.sync();
      expect(
        await mine.midiProgram('s1', 'nordStage3'),
        const MidiProgram(program: 3),
      );
      expect(
        server.overlays[id]!.midiPrograms,
        const MidiPrograms({'nordStage3': MidiProgram(program: 3)}),
      );
    });

    test('reads the verse chords of older and newer clients', () {
      expect(
        OverlaySync.verseChordsOf({'first_verse_chords_only': true}),
        VerseChords.first,
      );
      expect(OverlaySync.verseChordsOf({}), VerseChords.all);
      expect(
        OverlaySync.verseChordsOf({'verse_chords': 'first'}),
        VerseChords.first,
      );
      // A value of a newer client shows all chords.
      expect(
        OverlaySync.verseChordsOf({'verse_chords': 'other'}),
        VerseChords.all,
      );
    });

    test(
      'the last writer wins: a pending local change is kept and pushed',
      () async {
        await adjust(mine, (o) => o.copyWith(transpose: 1));
        await engine.sync();
        final id = SyncEngine.overlayServerId('ann', 's1');
        server.putOverlay(
          RemoteOverlay(
            id: id,
            userId: 'ann',
            songId: 's1',
            data: const {'transpose': 5},
          ),
        );
        await adjust(mine, (o) => o.copyWith(transpose: 7));
        await engine.sync();
        expect((await mine.getOverlay('s1')).transpose, 7);
        expect(server.overlays[id]!.data['transpose'], 7);
      },
    );

    test(
      "on a shared device, another person's change waits for them",
      () async {
        final bob = SongRepository(
          db,
          FileAttachmentStorage(dir),
          libraryId: 'o1',
          userId: 'bob',
        );
        await adjust(bob, (o) => o.copyWith(transpose: 4));
        await adjust(mine, (o) => o.copyWith(transpose: 1));
        await engine.sync();
        expect(server.overlays.values.map((o) => o.userId), ['ann']);
        expect((await outbox()).single.recordId, 'bob:s1');
      },
    );

    test('taken-over and local-library adjustments', () async {
      // Taken over after the upgrade: never on the server yet.
      await db
          .into(db.personalOverlays)
          .insert(
            PersonalOverlaysCompanion.insert(
              ownerId: const Value('ann'),
              songId: 's1',
              capoFret: const Value(3),
            ),
          );
      final local = SongRepository(
        db,
        FileAttachmentStorage(dir),
        userId: 'ann',
      );
      final own = await local.createSong(source: '{title: Mine}');
      await local.saveOverlay(
        (await local.getOverlay(own)).copyWith(transpose: 2),
      );
      await engine.sync();
      expect(server.overlays.values.single.data['capo_fret'], 3);
      expect(await outbox(), isEmpty);
    });
  });

  group('freehand annotations (ADR-0032)', () {
    late AnnotationRepository mine;

    setUp(() async {
      mine = AnnotationRepository(db, userId: 'ann');
      server.putSong(remoteSong('s1', '{title: Song}\n[C]Hello'));
      await engine.sync();
    });

    AnnotationStroke stroke(String id, {int color = 0}) => AnnotationStroke(
      id: id,
      tool: AnnotationTool.pen,
      color: color,
      width: 0.004,
      points: const [0.1, 0.1, 0.2, 0.2],
    );

    String recordId([String target = '']) =>
        AnnotationSync.serverId('ann', 's1', target);

    Future<List<String>> shown() async => [
      for (final s in await mine.watch('s1').first) '${s.id}:${s.color}',
    ];

    test('pushes new strokes in one record shared by all devices', () async {
      await mine.apply('s1', put: [stroke('a'), stroke('b')]);
      expect(await mine.watchCount('s1').first, 2);
      final report = await engine.sync();
      expect(report.error, isNull);
      final remote = server.annotations[recordId()]!;
      expect(remote.userId, 'ann');
      expect(remote.attachmentId, isNull);
      expect(remote.data.keys, unorderedEquals(['a', 'b']));
      expect((remote.data['a'] as Map)['t'], isA<int>());
      expect(await outbox(), isEmpty);
      final rows = await db.select(db.annotations).get();
      expect(rows.map((r) => r.pending), [0, 0]);
    });

    test('erasing sends a tombstone and forgets the stroke here', () async {
      await mine.apply('s1', put: [stroke('a'), stroke('b')]);
      await engine.sync();
      await mine.apply('s1', remove: ['a']);
      expect(await shown(), ['b:0']);
      await engine.sync();
      expect(server.annotations[recordId()]!.data['a'], {
        'deleted': true,
        't': isA<int>(),
      });
      expect((await db.select(db.annotations).get()).map((r) => r.id), ['b']);
    });

    test('strokes of two devices are merged per stroke', () async {
      await mine.apply('s1', put: [stroke('a'), stroke('b')]);
      await engine.sync();
      // The other device recolours b and adds c.
      server.putAnnotations(
        RemoteAnnotations(
          id: recordId(),
          userId: 'ann',
          songId: 's1',
          data: {
            'b': stroke('b', color: 3).toJson(),
            'c': stroke('c', color: 1).toJson(),
          },
        ),
      );
      // Meanwhile here: a recoloured, not pushed yet.
      await mine.apply('s1', put: [stroke('a', color: 5)]);
      await engine.sync();
      expect(await shown(), unorderedEquals(['a:5', 'b:3', 'c:1']));
      final data = server.annotations[recordId()]!.data;
      expect((data['a'] as Map)['color'], 5);
      expect((data['c'] as Map)['color'], 1);
    });

    test('a pending local change wins over the pulled stroke', () async {
      await mine.apply('s1', put: [stroke('a')]);
      await engine.sync();
      await mine.apply('s1', put: [stroke('a', color: 4)]);
      server.putAnnotations(
        RemoteAnnotations(
          id: recordId(),
          userId: 'ann',
          songId: 's1',
          data: {'a': stroke('a', color: 2).toJson()},
        ),
      );
      await engine.sync();
      expect(await shown(), ['a:4']);
      expect((server.annotations[recordId()]!.data['a'] as Map)['color'], 4);
    });

    test('pulls strokes and erases of another device', () async {
      server.putAnnotations(
        RemoteAnnotations(
          id: recordId(),
          userId: 'ann',
          songId: 's1',
          data: {'x': stroke('x').toJson()},
        ),
      );
      await engine.sync();
      expect(await shown(), ['x:0']);
      expect(await outbox(), isEmpty);

      server.putAnnotations(
        RemoteAnnotations(
          id: recordId(),
          userId: 'ann',
          songId: 's1',
          data: {'x': annotationTombstone(1)},
        ),
      );
      await engine.sync();
      expect(await shown(), isEmpty);
    });

    test('a record deleted with its song is removed here', () async {
      server.putAnnotations(
        RemoteAnnotations(
          id: recordId(),
          userId: 'ann',
          songId: 's1',
          data: {'x': stroke('x').toJson()},
        ),
      );
      await engine.sync();
      server.putAnnotations(server.annotations[recordId()]!, deleted: true);
      await engine.sync();
      expect(await db.select(db.annotations).get(), isEmpty);
    });

    test('delete all and undo', () async {
      await mine.apply('s1', put: [stroke('a'), stroke('b')]);
      await engine.sync();
      final removed = await mine.deleteAll('s1');
      expect(removed.map((s) => s.stroke.id), ['a', 'b']);
      expect(await shown(), isEmpty);
      await mine.restoreAll('s1', removed);
      expect(await shown(), ['a:0', 'b:0']);
      await engine.sync();
      final data = server.annotations[recordId()]!.data;
      expect(data.values.every((v) => (v as Map)['deleted'] != true), isTrue);
    });

    test('the local library and other people are never pushed', () async {
      final local = SongRepository(
        db,
        FileAttachmentStorage(dir),
        userId: 'ann',
      );
      final own = await local.createSong(source: '{title: Mine}');
      await mine.apply(own, put: [stroke('l')]);
      final bob = AnnotationRepository(db, userId: 'bob');
      await bob.apply('s1', put: [stroke('bob')]);
      expect(await mine.watch(own).first, hasLength(1));
      expect(await shown(), isEmpty, reason: "Bob's strokes are his own");
      await engine.sync();
      expect(server.annotations, isEmpty);
      expect((await outbox()).single.recordId, 'bob:s1:');
    });
  });

  group('atomic writes', () {
    Future<void> failOutbox(String event) => db.customStatement(
      'CREATE TRIGGER fail_outbox BEFORE $event ON sync_outbox '
      "BEGIN SELECT RAISE(ABORT, 'outbox unavailable'); END",
    );

    test('a change is rolled back when its outbox entry fails', () async {
      final kept = await songs.createSong(source: '{title: Kept}');
      final setId = await sets.createSet(name: 'Gig');
      await failOutbox('INSERT');

      await expectLater(
        songs.createSong(source: '{title: New}'),
        throwsA(anything),
      );
      expect((await songs.watchSongs().first).map((s) => s.title), ['Kept']);

      await expectLater(
        songs.updateSource(kept, '{title: Changed}'),
        throwsA(anything),
      );
      expect((await songs.getSong(kept))!.title, 'Kept');

      await expectLater(sets.addSongs(setId, [kept]), throwsA(anything));
      expect(await sets.getItems(setId), isEmpty);
    });

    test('removing a set item marks the set once', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a, b]);
      await engine.sync();
      expect(await outbox(), isEmpty);

      final items = await sets.getItems(setId);
      await sets.removeItem(setId, items.first.item.id);
      final entry = (await outbox()).single;
      expect(entry.recordId, setId);
      expect(entry.version, 1);
      expect((await sets.getItems(setId)).single.item.position, 0);
    });

    test('a pushed revision is only stored with the outbox removal', () async {
      final id = await songs.createSong(source: '{title: New}');
      await failOutbox('DELETE');

      await expectLater(engine.sync(), throwsA(anything));
      expect(server.songs[id], isNotNull);
      // Neither the revision nor the removal of the outbox entry is stored.
      expect((await songs.getSong(id))!.revision, 0);
      expect((await outbox()).single.recordId, id);
    });
  });

  test('set items read and write the JSON of the server', () {
    const json = {
      'id': 'i1',
      'type': 'song',
      'song': 's1',
      'transpose': -2,
      'sequence': 'V, C',
    };
    final item = RemoteSetItem.fromJson(json);
    expect(item.type, SetItemType.song);
    expect(item.transpose, -2);
    expect(item.toJson(), json);
    // Unknown types (newer clients) become text items; no ID gets a new one.
    final odd = RemoteSetItem.fromJson({'type': 'medley', 'note': 'x'});
    expect((odd.type, odd.id, odd.note), (SetItemType.text, '', 'x'));
    expect(const RemoteSetItem(id: 'i2', type: SetItemType.pause).toJson(), {
      'id': 'i2',
      'type': 'pause',
    });
  });

  test('the sync store looks up large batches in chunks', () async {
    final store = SyncStore(db);
    final ids = [for (var i = 0; i < 1200; i++) 'song-$i'];
    for (final id in ids.where((id) => id.endsWith('7'))) {
      await markDirty(db, SyncCollection.songs, id, scope: 'o1');
    }
    final dirty = await store.dirty(SyncCollection.songs, ids);
    expect(dirty, hasLength(120));
    expect(dirty, contains('song-1197'));
    expect(await store.cursor('o1', 'nothing'), 0);
    await store.setCursor('o1', 'nothing', 42);
    expect(await store.cursor('o1', 'nothing'), 42);
  });

  group('song play history (ADR-0046)', () {
    final today = DateTime.now();
    DateTime daysAgo(int days) =>
        DateTime(today.year, today.month, today.day - days);

    RemoteSet gig(String id, DateTime date, {String bandId = 'b1'}) =>
        RemoteSet(
          id: id,
          bandId: bandId,
          name: id,
          gigDate: date,
          items: [
            RemoteSetItem(id: '$id-item', type: SetItemType.song, songId: 's1'),
          ],
        );

    test('freezes how the songs of a gig that took place were played and '
        'pushes it', () async {
      server.putSong(remoteSong('s1', '{title: A}\n{key: D}\n{tempo: 90}'));
      server.putSet(gig('yesterday', daysAgo(1)));
      server.putSet(gig('long-ago', daysAgo(60)));
      server.putSet(gig('tomorrow', daysAgo(-1)));
      await engine.sync();
      await ArrangementRepository(db).save('b1', 's1', transpose: 2);
      await engine.sync();

      // Frozen with the arrangement of the first sync, the later change of
      // the band's key does not rewrite it.
      final played = server.sets['yesterday']!.items.single.played;
      expect(played, const PlayedValues(key: 'D', tempo: 90));
      expect(server.sets['long-ago']!.items.single.played, isNull);
      expect(server.sets['tomorrow']!.items.single.played, isNull);
    });

    test(
      'unknown item fields and the played values survive a local change',
      () async {
        server.putSong(remoteSong('s1', '{title: A}'));
        server.putSet(
          RemoteSet(
            id: 'set1',
            bandId: 'b1',
            name: 'Old',
            gigDate: daysAgo(90),
            items: const [
              RemoteSetItem(
                id: 'item',
                type: SetItemType.song,
                songId: 's1',
                played: PlayedValues(key: 'Bb', tempo: 120),
                extra: {'x_future': 1},
              ),
            ],
          ),
        );
        await engine.sync();
        await sets.updateSet('set1', name: 'Renamed');
        await engine.sync();
        final item = server.sets['set1']!.items.single;
        expect(server.sets['set1']!.name, 'Renamed');
        expect(item.played, const PlayedValues(key: 'Bb', tempo: 120));
        expect(item.toJson()['x_future'], 1);
      },
    );

    test('members without set rights freeze nothing', () async {
      const bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');
      // In an organization of its own: Ann is an admin of o1.
      server.addBand('b2', 'Jazz', admin: bob, organizationId: 'o2');
      server.addMember('b2', _ann, BandRole.member);
      server.putSong(
        const RemoteSong(
          id: 's1',
          organizationId: 'o2',
          title: 'A',
          chordpro: '{title: A}\n{key: D}',
        ),
      );
      server.putSet(gig('jazz', daysAgo(1), bandId: 'b2'));
      await engine.sync();
      final item = await (db.select(
        db.setItems,
      )..where((i) => i.setId.equals('jazz'))).getSingle();
      expect(item.played, isNull);
      expect(server.sets['jazz']!.items.single.played, isNull);
      expect(await outbox(), isEmpty);
    });
  });

  test('set items keep the played values and unknown fields in their JSON', () {
    const json = {
      'x_future': {'a': 1},
      'id': 'i1',
      'type': 'song',
      'song': 's1',
      'played': {'key': 'D', 'tempo': 96, 'sequence': 'V C'},
    };
    final item = RemoteSetItem.fromJson(json);
    expect(
      item.played,
      const PlayedValues(key: 'D', tempo: 96, sequence: 'V C'),
    );
    expect(item.extra, {
      'x_future': {'a': 1},
    });
    expect(item.toJson(), json);
    expect(RemoteSetItem.decodeExtra(item.extraJson), item.extra);
    expect(RemoteSetItem.decodeExtra('not json'), isEmpty);
    // Known fields win over unknown ones of the same name.
    expect(
      const RemoteSetItem(
        id: 'i2',
        type: SetItemType.pause,
        extra: {'type': 'medley'},
      ).toJson()['type'],
      'pause',
    );
  });
}
