import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'sync_store.dart';

const _log = Log('sync');
const _uuid = Uuid();

/// Sync of band arrangements (ADR-0025): delta pull per band, one server
/// record per band and song, last writer wins (like sets).
class ArrangementSync {
  ArrangementSync(this.db, this.backend, this.store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Server record ID of the arrangement of [bandId] for [songId]: the same
  /// on every device, so two devices never create two records.
  static String serverId(String bandId, String songId) =>
      _uuid.v5(Namespace.url.value, 'setding:arrangement:$bandId:$songId');

  Future<int> pull(BandView band) async {
    final since = await store.cursor(band.id, SyncCollection.arrangements);
    final remote = await backend.pullArrangements(band.id, since);
    if (remote.isEmpty) return 0;
    await db.transaction(() async {
      final songIds = [for (final a in remote) a.songId];
      final locals = await SyncStore.byId(
        songIds,
        (chunk) => (db.select(
          db.bandArrangements,
        )..where((a) => a.bandId.equals(band.id) & a.songId.isIn(chunk))).get(),
        (a) => a.songId,
      );
      final dirty = await store.dirty(SyncCollection.arrangements, [
        for (final id in songIds) arrangementRecordId(band.id, id),
      ]);
      final songs = await store.existingSongs(songIds);
      for (final a in remote) {
        final local = locals[a.songId];
        if (local != null && a.revision <= local.revision) continue;
        // Last writer wins: a pending local change is pushed afterwards.
        if (dirty.contains(arrangementRecordId(band.id, a.songId))) continue;
        if (!songs.contains(a.songId)) continue; // the song is not here
        await db
            .into(db.bandArrangements)
            .insertOnConflictUpdate(
              BandArrangementsCompanion.insert(
                bandId: band.id,
                songId: a.songId,
                transpose: Value(a.transpose),
                sequence: Value(a.sequence),
                tempo: Value(a.tempo),
                revision: Value(a.revision),
                deleted: Value(a.deleted),
              ),
            );
      }
      await store.setCursor(
        band.id,
        SyncCollection.arrangements,
        remote.last.revision,
      );
    });
    return remote.length;
  }

  Future<PushResult> push(OutboxEntry entry) async {
    final (bandId, songId) = parseArrangementRecordId(entry.recordId);
    final row =
        await (db.select(db.bandArrangements).join([
              innerJoin(
                db.songs,
                db.songs.id.equalsExp(db.bandArrangements.songId),
              ),
            ])..where(
              db.bandArrangements.bandId.equals(bandId) &
                  db.bandArrangements.songId.equals(songId),
            ))
            .getSingleOrNull();
    if (row == null || bandId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final arrangement = row.readTable(db.bandArrangements);
    final song = row.readTable(db.songs);
    final create = arrangement.revision == 0;
    if (song.deleted || (create && arrangement.deleted)) {
      // The server deletes it with the song; never pushed removals are done.
      await store.done(entry);
      return PushResult.skipped;
    }
    if (song.revision == 0) return PushResult.skipped; // the song comes first
    final remote = RemoteArrangement(
      id: serverId(bandId, songId),
      bandId: bandId,
      songId: songId,
      transpose: arrangement.transpose,
      sequence: arrangement.sequence,
      tempo: arrangement.tempo,
      deleted: arrangement.deleted,
    );
    try {
      RemoteArrangement stored;
      try {
        stored = await backend.pushArrangement(remote, create: create);
      } on BackendException catch (e) {
        // Created on another device meanwhile (same record ID).
        if (!create || e.kind != BackendErrorKind.server) rethrow;
        stored = await backend.pushArrangement(remote, create: false);
      }
      await db.transaction(() async {
        await (db.update(db.bandArrangements)
              ..where((a) => a.bandId.equals(bandId) & a.songId.equals(songId)))
            .write(BandArrangementsCompanion(revision: Value(stored.revision)));
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        _log.warning('Arrangement ${entry.recordId} not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
      }
      rethrow;
    }
  }
}
