import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show TableUpdateQuery, UpdateKind, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/band_copy.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/sync/band_service.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/sync/sync_engine.dart';

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
    dir = Directory.systemTemp.createTempSync('realchord_sync');
    final storage = AttachmentStorage(dir);
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

    test('never syncs the local library', () async {
      final local = SongRepository(db, AttachmentStorage(dir));
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
      server.orgMembers.single.role = BandRole.member;
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

    setUp(() => storage = AttachmentStorage(dir));

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
  group('records from before the outbox (#29)', () {
    final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    test('songs, sets and PDFs that never synced are uploaded', () async {
      final songId = await songs.createSong(source: '{title: Old}');
      final a = await songs.addAttachment(songId, name: 'Score', bytes: pdf);
      final setId = await sets.createSet(name: 'Old gig');
      final local = SongRepository(db, AttachmentStorage(dir));
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
      server.orgMembers.single.role = BandRole.member;
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

  group('personal adjustments (ADR-0020)', () {
    late SongRepository mine;

    setUp(() async {
      mine = SongRepository(
        db,
        AttachmentStorage(dir),
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
          (o) => o.copyWith(transpose: 2, notes: const Value('Solo')),
        );
        final report = await engine.sync();
        expect(report.error, isNull);
        final id = SyncEngine.overlayServerId('ann', 's1');
        final remote = server.overlays[id]!;
        expect(remote.userId, 'ann');
        expect(remote.data['transpose'], 2);
        expect(remote.data['notes'], 'Solo');
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
          data: const {'transpose': -3, 'capo_fret': 2, 'font_scale': 1.2},
        ),
      );
      await engine.sync();
      final o = await mine.getOverlay('s1');
      expect((o.transpose, o.capoFret, o.fontScale), (-3, 2, 1.2));
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
          AttachmentStorage(dir),
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
      final local = SongRepository(db, AttachmentStorage(dir), userId: 'ann');
      final own = await local.createSong(source: '{title: Mine}');
      await local.saveOverlay(
        (await local.getOverlay(own)).copyWith(transpose: 2),
      );
      await engine.sync();
      expect(server.overlays.values.single.data['capo_fret'], 3);
      expect(await outbox(), isEmpty);
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
}
