// A change of a song, set or personal adjustment the server refuses for
// good is undone on this device and reported once, as attachment changes
// are (#1260). Before, a 403/404 dropped it from the outbox and kept it on
// this device in silence, and a 400 (validation error) stopped every later
// sync at the same outbox entry.

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// The lasting refusals: no permission, and a validation error.
const _forbidden = BackendException(BackendErrorKind.notAllowed, null, 403);
const _invalid = BackendException(BackendErrorKind.server, {
  'data': {
    'title': {'code': 'validation_invalid'},
  },
}, 400);

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
    dir = Directory.systemTemp.createTempSync('setding_refused');
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
    songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
    sets = SetRepository(db, storage, bandId: 'b1');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();
  Future<SongEntry?> song(String id) =>
      (db.select(db.songs)..where((s) => s.id.equals(id))).getSingleOrNull();
  Future<SetlistEntry?> set(String id) =>
      (db.select(db.setlists)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Asserts that [report] lists exactly [change], and that the next sync
  /// neither sends nor reports it again.
  Future<void> reportedOnce(SyncReport report, RefusedChange change) async {
    expect(report.error, isNull, reason: 'the sync goes on');
    expect(report.undoneChanges, [change]);
    expect(await outbox(), isEmpty, reason: 'not sent again');
    expect(
      await db.select(db.changeLog).get(),
      isEmpty,
      reason: 'not a change of someone else',
    );
    final pushes = server.pushCount;
    final again = await engine.sync();
    expect(again.undoneChanges, isEmpty, reason: 'told once');
    expect(server.pushCount, pushes);
  }

  Future<String> syncedSong() async {
    final id = await songs.createSong(source: '{title: Song}\n[C]server');
    await engine.sync();
    expect(server.songs[id], isNotNull);
    return id;
  }

  group('a refused song change (#1260)', () {
    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('is undone and reported once ($label)', () async {
        final id = await syncedSong();
        await songs.updateSource(id, '{title: Mine}\n[C]mine');
        server.songPushError = refusal;

        final report = await engine.sync();
        expect((await song(id))!.chordproSource, contains('server'));
        expect((await song(id))!.title, 'Song');
        await reportedOnce(report, (
          kind: RefusedRecord.song,
          id: id,
          name: 'Mine',
          songTitle: 'Mine',
        ));
      });
    }

    test('a 400 no longer stops the sync of the other changes', () async {
      final id = await syncedSong();
      await songs.updateSource(id, '{title: Mine}');
      final setId = await sets.createSet(name: 'Gig');
      server.songPushError = _invalid;

      final report = await engine.sync();
      expect(report.error, isNull);
      expect(server.sets[setId], isNotNull, reason: 'pushed after the song');
      expect(await outbox(), isEmpty);
    });

    test('a song the server no longer shows is removed (404)', () async {
      final id = await syncedSong();
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [id]);
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(transpose: 2),
      );
      await engine.sync();
      await songs.updateSource(id, '{title: Mine}');
      server.songs.remove(id); // out of reach: 404 on the update

      final report = await engine.sync();
      expect(await song(id), isNull, reason: 'not kept with the change');
      expect(await sets.getItems(setId), isEmpty);
      expect(
        await (db.select(
          db.personalOverlays,
        )..where((o) => o.songId.equals(id))).get(),
        isEmpty,
      );
      await reportedOnce(report, (
        kind: RefusedRecord.song,
        id: id,
        name: 'Mine',
        songTitle: 'Mine',
      ));
    });

    test('a new song the server refuses is removed', () async {
      final id = await songs.createSong(source: '{title: New}');
      server.songPushError = _forbidden;

      final report = await engine.sync();
      expect(await song(id), isNull);
      expect(server.songs[id], isNull);
      await reportedOnce(report, (
        kind: RefusedRecord.song,
        id: id,
        name: 'New',
        songTitle: 'New',
      ));
    });

    test('a refused link field undoes the song', () async {
      final id = await syncedSong();
      await songs.setLanguage(id, 'pt');
      server.songs.remove(id);

      final report = await engine.sync();
      expect(await song(id), isNull);
      expect(report.undoneChanges.single.id, id);
      expect(await outbox(), isEmpty);
    });

    test('a server error is sent again in the next sync', () async {
      final id = await syncedSong();
      await songs.updateSource(id, '{title: Mine}');
      server.songPushError = const BackendException(
        BackendErrorKind.server,
        null,
        503,
      );
      final report = await engine.sync();
      expect(report.undoneChanges, isEmpty);
      expect((await song(id))!.title, 'Mine');
      expect(await outbox(), hasLength(1));

      server.songPushError = null;
      await engine.sync();
      expect(server.songs[id]!.title, 'Mine');
      expect(await outbox(), isEmpty);
    });
  });

  group('a refused set change (#1260)', () {
    Future<String> syncedSet() async {
      final id = await sets.createSet(name: 'Gig');
      await engine.sync();
      expect(server.sets[id], isNotNull);
      return id;
    }

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('is undone and reported once ($label)', () async {
        final id = await syncedSet();
        await sets.updateSet(id, name: 'Mine');
        server.setPushError = refusal;

        final report = await engine.sync();
        expect((await set(id))!.name, 'Gig');
        await reportedOnce(report, (
          kind: RefusedRecord.set,
          id: id,
          name: 'Mine',
          songTitle: null,
        ));
      });
    }

    test('a set the server no longer shows is removed (404)', () async {
      final songId = await syncedSong();
      final id = await syncedSet();
      await sets.addSongs(id, [songId]);
      server.sets.remove(id);

      final report = await engine.sync();
      expect(await set(id), isNull);
      expect(
        await (db.select(db.setItems)..where((i) => i.setId.equals(id))).get(),
        isEmpty,
      );
      await reportedOnce(report, (
        kind: RefusedRecord.set,
        id: id,
        name: 'Gig',
        songTitle: null,
      ));
    });

    test('a new set the server refuses is removed', () async {
      final id = await sets.createSet(name: 'New');
      server.setPushError = _forbidden;

      final report = await engine.sync();
      expect(await set(id), isNull);
      await reportedOnce(report, (
        kind: RefusedRecord.set,
        id: id,
        name: 'New',
        songTitle: null,
      ));
    });
  });

  group('a refused change of personal adjustments (#1260)', () {
    late String songId;

    setUp(() async {
      songId = await syncedSong();
      await songs.saveOverlay(
        (await songs.getOverlay(songId))
            .copyWith(transpose: 2, notes: const Value('Server')),
      );
      await engine.sync();
      expect(server.overlays.values.single.data['transpose'], 2);
    });

    Future<void> change() async => songs.saveOverlay(
      (await songs.getOverlay(songId))
          .copyWith(transpose: -1, notes: const Value('Mine')),
    );

    for (final (label, refusal) in [('403', _forbidden), ('400', _invalid)]) {
      test('is undone and reported once ($label)', () async {
        await change();
        server.overlayPushError = refusal;

        final report = await engine.sync();
        final o = await songs.getOverlay(songId);
        expect((o.transpose, o.notes), (2, 'Server'));
        await reportedOnce(report, (
          kind: RefusedRecord.adjustment,
          id: songId,
          name: 'Song',
          songTitle: 'Song',
        ));
        expect(
          (await song(songId))!.chordproSource,
          contains('server'),
          reason: 'the shared song is untouched (ADR-0006)',
        );
      });
    }

    test('adjustments the server no longer shows are removed (404)', () async {
      await change();
      server.overlays.clear();

      final report = await engine.sync();
      expect(
        await (db.select(
          db.personalOverlays,
        )..where((o) => o.songId.equals(songId))).get(),
        isEmpty,
      );
      expect(await song(songId), isNotNull, reason: 'the song stays');
      await reportedOnce(report, (
        kind: RefusedRecord.adjustment,
        id: songId,
        name: 'Song',
        songTitle: 'Song',
      ));
    });
  });
}
