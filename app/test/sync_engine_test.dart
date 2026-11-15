import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
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
      expect(remote.items, [
        {'id': item.id, 'type': 'song', 'song': 's1', 'transpose': 2},
        {
          'id': (await sets.getItems(setId)).last.item.id,
          'type': 'pause',
          'note': 'Break',
        },
      ]);
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
            {'id': 'i1', 'type': 'song', 'song': 's1', 'sequence': 'V, C'},
            {'id': 'i2', 'type': 'song', 'song': 'unknown'},
            {'id': 'i3', 'type': 'text', 'note': 'Encore'},
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
}
