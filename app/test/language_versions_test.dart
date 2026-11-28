import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Language versions of a song (ADR-0053, #804): the group and the
/// language are stored, linked and synced last writer wins per field,
/// never as a conflict of the song.
void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend server;
  late SyncEngine engine;
  late SongRepository songs;
  late BandCopyService copies;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_versions');
    final storage = FileAttachmentStorage(dir);
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    final bands = BandService(db, server);
    await bands.refresh();
    copies = BandCopyService(db, storage);
    engine = SyncEngine(db, server, bands, copies: copies);
    songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  // Also songs in the trash.
  Future<SongEntry> local(String id) =>
      (db.select(db.songs)..where((s) => s.id.equals(id))).getSingle();
  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();
  Future<List<SongConflict>> conflicts() => db.select(db.songConflicts).get();

  Future<String> synced(String title) async {
    final id = await songs.createSong(source: '{title: $title}\n[G]La');
    await engine.sync();
    return id;
  }

  group('linking (repository)', () {
    test('two songs without a group get a new shared one', () async {
      final a = await songs.createSong(source: '{title: Amazing Grace}');
      final b = await songs.createSong(source: '{title: O Gnade}');
      await songs.linkLanguageVersions(a, b);
      final work = (await local(a)).workId;
      expect(work, isNotNull);
      expect((await local(b)).workId, work);
      expect([for (final s in await songs.languageVersions(a)) s.id], [b]);
    });

    test('a song joins the group of the other', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final c = await songs.createSong(source: '{title: C}');
      await songs.linkLanguageVersions(a, b);
      final work = (await local(a)).workId;
      await songs.linkLanguageVersions(c, a);
      expect((await local(c)).workId, work);
      expect([
        for (final s in await songs.languageVersions(c)) s.id,
      ], unorderedEquals([a, b]));
    });

    test('linking two groups moves the smaller one', () async {
      final big = [
        for (final t in ['A', 'B', 'C'])
          await songs.createSong(source: '{title: $t}'),
      ];
      final small = [
        for (final t in ['D', 'E'])
          await songs.createSong(source: '{title: $t}'),
      ];
      await songs.linkLanguageVersions(big[0], big[1]);
      await songs.linkLanguageVersions(big[0], big[2]);
      await songs.linkLanguageVersions(small[0], small[1]);
      final work = (await local(big[0])).workId;
      await songs.linkLanguageVersions(small[0], big[2]);
      for (final id in [...big, ...small]) {
        expect((await local(id)).workId, work);
      }
    });

    test('unlinking removes only that song', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final c = await songs.createSong(source: '{title: C}');
      await songs.linkLanguageVersions(a, b);
      await songs.linkLanguageVersions(a, c);
      await songs.unlinkLanguageVersion(b);
      expect((await local(b)).workId, isNull);
      expect([for (final s in await songs.languageVersions(a)) s.id], [c]);
      expect(await songs.languageVersions(b), isEmpty);
    });

    test('songs in the trash keep their group but are no versions', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      await songs.linkLanguageVersions(a, b);
      final deleted = await songs.deleteSong(b);
      expect(await songs.languageVersions(a), isEmpty);
      expect((await local(b)).workId, (await local(a)).workId);
      await songs.restoreSong(deleted);
      expect([for (final s in await songs.languageVersions(a)) s.id], [b]);
    });

    test('songs of different libraries are not linked', () async {
      final a = await songs.createSong(source: '{title: A}');
      final other = SongRepository(
        db,
        FileAttachmentStorage(dir),
        libraryId: 'o2',
      );
      final b = await other.createSong(source: '{title: B}');
      expect(() => songs.linkLanguageVersions(a, b), throwsArgumentError);
      expect((await local(a)).workId, isNull);
    });

    test('the language is one of the known codes or none', () async {
      final a = await songs.createSong(source: '{title: A}');
      await songs.setLanguage(a, 'gsw');
      expect((await local(a)).language, 'gsw');
      expect(() => songs.setLanguage(a, 'xx'), throwsArgumentError);
      await songs.setLanguage(a, null);
      expect((await local(a)).language, isNull);
    });

    test('only songs the person may edit are moved', () async {
      final mine = await songs.createSong(source: '{title: Mine}');
      final theirs = await songs.createSong(source: '{title: Theirs}');
      final third = await songs.createSong(source: '{title: Third}');
      bool mayEdit(SongEntry s) => s.id != theirs && s.id != third;
      // Neither has a group: a new one would move both.
      expect(
        await songs.linkLanguageVersions(mine, theirs, mayEdit: mayEdit),
        isFalse,
      );
      expect((await local(mine)).workId, isNull);
      expect(await outbox(), hasLength(3)); // only the creates

      // Theirs has a group: mine joins it instead of the other way round.
      await songs.linkLanguageVersions(theirs, third);
      final work = (await local(theirs)).workId;
      expect(
        await songs.linkLanguageVersions(theirs, mine, mayEdit: mayEdit),
        isTrue,
      );
      expect((await local(mine)).workId, work);
    });

    test('several versions are added and removed at once, with undo', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final c = await songs.createSong(source: '{title: C}');
      final d = await songs.createSong(source: '{title: D}');
      final e = await songs.createSong(source: '{title: E}');
      await songs.linkLanguageVersions(a, b);
      await songs.linkLanguageVersions(d, e);
      final work = (await local(a)).workId;
      final other = (await local(d)).workId;

      final result = await songs.updateLanguageVersions(
        a,
        add: [c, d],
        remove: [b],
      );
      expect(result.notLinked, isEmpty);
      expect((await local(b)).workId, isNull);
      // Linking d brings its group along.
      final now = (await local(a)).workId;
      for (final id in [c, d, e]) {
        expect((await local(id)).workId, now);
      }

      // Undo puts every touched song back.
      for (final MapEntry(:key, :value) in result.before.entries) {
        await songs.setWorkId(key, value);
      }
      expect((await local(a)).workId, work);
      expect((await local(b)).workId, work);
      expect((await local(c)).workId, isNull);
      expect((await local(d)).workId, other);
      expect((await local(e)).workId, other);
    });

    test(
      'songs the person may not edit are neither removed nor moved',
      () async {
        final a = await songs.createSong(source: '{title: A}');
        final b = await songs.createSong(source: '{title: B}');
        final c = await songs.createSong(source: '{title: C}');
        final d = await songs.createSong(source: '{title: D}');
        await songs.linkLanguageVersions(a, b);
        await songs.linkLanguageVersions(c, d);
        bool mayEdit(SongEntry s) => s.id != b && s.id != d;
        final result = await songs.updateLanguageVersions(
          a,
          add: [c],
          remove: [b],
          mayEdit: mayEdit,
        );
        // b stays; a's group holds b and c's group holds d: neither can move.
        expect(result.notLinked, [c]);
        expect((await local(b)).workId, (await local(a)).workId);
        expect((await local(c)).workId, (await local(d)).workId);
      },
    );

    test('the versions are watched, the song included', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      expect(await songs.watchLanguageVersions(a).first, isEmpty);
      await songs.linkLanguageVersions(a, b);
      expect(
        [for (final s in await songs.watchLanguageVersions(a).first) s.id],
        [a, b],
      );
      expect(await songs.watchWorkCounts().first, {
        (await local(a)).workId!: 2,
      });
      await songs.unlinkLanguageVersion(b);
      expect([
        for (final s in await songs.watchLanguageVersions(b).first) s.id,
      ], isEmpty);
      final work = (await local(a)).workId;
      await songs.setWorkId(b, work);
      expect((await local(b)).workId, work);
    });

    test('a copy is no version of the original', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      await songs.linkLanguageVersions(a, b);
      await songs.setLanguage(a, 'en');
      final copy = (await copies.copySongs([a], 'o1')).single;
      expect((await local(copy)).workId, isNull);
      expect((await local(copy)).language, 'en');
    });

    test('versions copied together are linked again in the target '
        '(#878)', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final c = await songs.createSong(source: '{title: C}');
      await songs.linkLanguageVersions(a, b);
      await songs.linkLanguageVersions(a, c);
      final work = (await local(a)).workId;
      final [ca, cb] = await copies.copySongs([a, b], 'o2');
      final copyWork = (await local(ca)).workId;
      expect(copyWork, isNotNull);
      expect(copyWork, isNot(work));
      expect((await local(cb)).workId, copyWork);
      // The originals keep their group.
      expect((await local(a)).workId, work);
      expect((await local(c)).workId, work);
    });

    test('versions in a copied set are linked again in the target '
        '(#878)', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final d = await songs.createSong(source: '{title: D}');
      await songs.linkLanguageVersions(a, b);
      const setId = 'set1';
      await db
          .into(db.setlists)
          .insert(
            SetlistsCompanion.insert(
              id: setId,
              bandId: 'b1',
              name: 'S',
              updatedAt: DateTime.now(),
            ),
          );
      for (final (i, id) in [a, b, d].indexed) {
        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                id: 'i$i',
                setId: setId,
                position: i,
                type: SetItemType.song,
                songId: Value(id),
              ),
            );
      }
      final newSet = await copies.copySet(
        setId,
        targetBandId: 'b1',
        targetLibraryId: 'o2',
      );
      final items =
          await (db.select(db.setItems)
                ..where((i) => i.setId.equals(newSet))
                ..orderBy([(i) => OrderingTerm.asc(i.position)]))
              .get();
      final [ca, cb, cd] = [for (final i in items) await local(i.songId!)];
      expect(ca.workId, isNotNull);
      expect(cb.workId, ca.workId);
      expect(ca.workId, isNot((await local(a)).workId));
      expect(cd.workId, isNull);
    });

    test('the local library is never queued for the sync', () async {
      final local = SongRepository(db, FileAttachmentStorage(dir));
      final a = await local.createSong(source: '{title: A}');
      final b = await local.createSong(source: '{title: B}');
      await local.linkLanguageVersions(a, b);
      await local.setLanguage(a, 'de');
      expect(await outbox(), isEmpty);
    });
  });

  group('sync', () {
    test('new songs are created with their group and language', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      await songs.linkLanguageVersions(a, b);
      await songs.setLanguage(b, 'fr');
      await engine.sync();
      expect(server.songs[a]!.workId, isNotNull);
      expect(server.songs[b]!.workId, server.songs[a]!.workId);
      expect(server.songs[b]!.language, 'fr');
      expect(await outbox(), isEmpty);
    });

    test('linking synced songs pushes only the link fields', () async {
      final a = await synced('A');
      final b = await synced('B');
      await songs.linkLanguageVersions(a, b);
      await songs.setLanguage(a, 'de');
      final textPushes = server.songs[a]!.contentRevision;
      await engine.sync();
      expect(server.songs[a]!.workId, isNotNull);
      expect(server.songs[b]!.workId, server.songs[a]!.workId);
      expect(server.songs[a]!.language, 'de');
      expect(server.songs[a]!.contentRevision, textPushes);
      expect(
        server.songLinkPushes.map((p) => (p.$1, p.$2)),
        unorderedEquals([
          (a, SongLinkField.workId),
          (b, SongLinkField.workId),
          (a, SongLinkField.language),
        ]),
      );
      // The new revision is the base of the next change: no conflict.
      expect((await local(a)).revision, server.songs[a]!.revision);
      await songs.updateSource(a, '{title: A}\n[C]Changed');
      await engine.sync();
      expect(await conflicts(), isEmpty);
      expect(server.songs[a]!.chordpro, contains('Changed'));
      expect(server.songs[a]!.language, 'de');
    });

    test(
      'a link by someone else is no conflict with a local text change',
      () async {
        final a = await synced('A');
        await songs.updateSource(a, '{title: A}\n[C]Mine');
        server.putSongLink(a, SongLinkField.workId, 'w-1');
        await engine.sync();
        expect(await conflicts(), isEmpty);
        expect(server.songs[a]!.chordpro, contains('Mine'));
        expect(server.songs[a]!.workId, 'w-1');
        expect((await local(a)).workId, 'w-1');
        expect((await local(a)).chordproSource, contains('Mine'));
      },
    );

    test('a local link survives a text change by someone else', () async {
      final a = await synced('A');
      await songs.setLanguage(a, 'en');
      final s = server.songs[a]!;
      server.putSong(
        RemoteSong(
          id: a,
          organizationId: 'o1',
          title: 'A',
          chordpro: '{title: A}\n[D]Theirs',
        ),
        by: 'bob',
      );
      expect(s.language, isNull);
      await engine.sync();
      expect(await conflicts(), isEmpty);
      expect((await local(a)).chordproSource, contains('Theirs'));
      expect((await local(a)).language, 'en');
      expect(server.songs[a]!.language, 'en');
      expect(server.songs[a]!.chordpro, contains('Theirs'));
    });

    test('the last writer of a field wins', () async {
      final a = await synced('A');
      server.putSongLink(a, SongLinkField.language, 'fr');
      await songs.setLanguage(a, 'it');
      await engine.sync();
      expect(server.songs[a]!.language, 'it');
      expect((await local(a)).language, 'it');

      // A pulled change of the other field is taken meanwhile.
      server.putSongLink(a, SongLinkField.workId, 'w-2');
      await engine.sync();
      expect((await local(a)).workId, 'w-2');
      expect((await local(a)).language, 'it');
    });

    test('a text conflict still takes the pulled link fields', () async {
      final a = await synced('A');
      await songs.updateSource(a, '{title: A}\n[C]Mine');
      server.putSong(
        RemoteSong(
          id: a,
          organizationId: 'o1',
          title: 'A',
          chordpro: '{title: A}\n[D]Theirs',
        ),
        by: 'bob',
      );
      server.putSongLink(a, SongLinkField.language, 'nl');
      await engine.sync();
      expect(await conflicts(), hasLength(1));
      expect((await local(a)).language, 'nl');
      // Taking the server version keeps the link fields.
      await engine.takeServer(a);
      expect((await local(a)).language, 'nl');
      expect((await local(a)).chordproSource, contains('Theirs'));
    });

    // Before #1260 the refused link stayed on this device in silence.
    test('a link of a song the server no longer shows removes the song '
        '(#1260)', () async {
      final a = await synced('A');
      server.songs.remove(a);
      await songs.setLanguage(a, 'pt');
      final report = await engine.sync();
      expect(report.undoneChanges.single.id, a);
      expect(
        await (db.select(db.songs)..where((s) => s.id.equals(a))).get(),
        isEmpty,
      );
      expect(
        (await outbox()).where((e) => e.collection == SyncCollection.songLinks),
        isEmpty,
      );
    });
  });
}
