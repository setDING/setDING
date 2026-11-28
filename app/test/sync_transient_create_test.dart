// A new song, set or personal adjustment whose create fails with an error
// that may go away by itself (a 5xx, a rate limit) is sent again in the
// next sync (#1268). Before, the create was retried as an update at once;
// that update's 404/403 counted as a refusal for good, so the new set or
// adjustment was removed from this device, although the server only had
// a hiccup.
// A new song was already safe (its update is sent only when the server
// has the song); its test keeps it so with the shared rule.

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

/// Errors that may go away by themselves.
const _transient = [
  ('500', BackendException(BackendErrorKind.server, null, 500)),
  ('503', BackendException(BackendErrorKind.server, null, 503)),
  ('429', BackendException(BackendErrorKind.server, null, 429)),
  ('408', BackendException(BackendErrorKind.server, null, 408)),
];

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
    dir = Directory.systemTemp.createTempSync('setding_transient_create');
    final storage = FileAttachmentStorage(dir);
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    final bands = BandService(db, server);
    await bands.refresh();
    engine = SyncEngine(
      db,
      server,
      bands,
      copies: BandCopyService(db, storage, userId: 'ann'),
    );
    songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
    sets = SetRepository(db, storage, bandId: 'b1');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();

  /// Syncs with [error] on the first create: nothing is undone, the entry
  /// stays; the next sync creates the record.
  Future<void> failsOnceThenSyncs(BackendException error) async {
    server.nextCreateError = error;
    final report = await engine.sync();
    expect(server.nextCreateError, isNull, reason: 'the create was sent');
    expect(report.undoneChanges, isEmpty, reason: 'before: undone');
    expect(await outbox(), isNotEmpty, reason: 'sent again');

    final again = await engine.sync();
    expect(again.error, isNull);
    expect(again.undoneChanges, isEmpty);
    expect(await outbox(), isEmpty);
  }

  for (final (label, error) in _transient) {
    group('a $label on a create (#1268)', () {
      test('a new song is created in the next sync', () async {
        final id = await songs.createSong(source: '{title: New}\n[C]x');

        await failsOnceThenSyncs(error);
        expect(server.songs[id]?.chordpro, contains('[C]x'));
        final row = await (db.select(
          db.songs,
        )..where((s) => s.id.equals(id))).getSingle();
        expect(row.libraryId, 'o1', reason: 'not moved to this device');
      });

      test('a new set is created in the next sync', () async {
        await engine.sync();
        final id = await sets.createSet(name: 'Gig');

        await failsOnceThenSyncs(error);
        expect(server.sets[id]?.name, 'Gig');
        expect(
          await (db.select(
            db.setlists,
          )..where((s) => s.id.equals(id))).getSingleOrNull(),
          isNotNull,
          reason: 'before: removed',
        );
      });

      test('new personal adjustments are created in the next sync', () async {
        final songId = await songs.createSong(source: '{title: Song}\n[C]x');
        await engine.sync();
        await songs.saveOverlay(
          (await songs.getOverlay(songId))
              .copyWith(transpose: 2, notes: const Value('Mine')),
        );

        await failsOnceThenSyncs(error);
        expect(server.overlays.values.single.data['transpose'], 2);
        final o = await songs.getOverlay(songId);
        expect(o.transpose, 2, reason: 'before: undone');
        expect(o.notes, 'Mine');
      });
    });
  }

  test('a create the server refuses (4xx) is still retried as an update: '
      'the record may exist already (#1268)', () async {
    final id = await sets.createSet(name: 'Gig');
    await engine.sync();
    // Created by another device, or its answer got lost: the local set is
    // still new.
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      const SetlistsCompanion(revision: Value(0)),
    );
    await sets.updateSet(id, name: 'Show');
    await engine.sync();
    expect(server.sets[id]?.name, 'Show');
    expect(await outbox(), isEmpty);
  });
}
