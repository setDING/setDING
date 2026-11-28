import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'change_recorder.dart';
import 'refused_changes.dart';
import 'sync_store.dart';

const _log = Log('sync');
const _uuid = Uuid();

/// Sync of band arrangements (ADR-0025): delta pull per band, one server
/// record per band and song, last writer wins (like sets).
class ArrangementSync {
  ArrangementSync(
    this.db,
    this.backend,
    this.store, {
    this.changes,
    RefusedChanges? undone,
  }) : undone = undone ?? RefusedChanges(store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Changes of arrangements the server refused for good (#1264).
  final RefusedChanges undone;

  /// Records changes of other people (ADR-0045).
  final ChangeRecorder? changes;

  /// Server record ID of the arrangement of [bandId] for [songId]: the same
  /// on every device, so two devices never create two records.
  static String serverId(String bandId, String songId) =>
      _uuid.v5(Namespace.url.value, 'setding:arrangement:$bandId:$songId');

  /// Changes by others than [logChangesFor] (the signed-in user) are
  /// recorded in the change log (ADR-0045); null records nothing, e.g. on
  /// the first sync of the library or band.
  Future<int> pull(BandView band, {String? logChangesFor}) async =>
      (await _pull(band.id, logChangesFor: logChangesFor)).length;

  /// [pull]; returns the record IDs of the arrangements the server sent.
  /// Changes of the records [quiet] are not recorded (ADR-0045).
  Future<Set<String>> _pull(
    String bandId, {
    String? logChangesFor,
    Set<String> quiet = const {},
  }) async {
    final since = await store.cursor(bandId, SyncCollection.arrangements);
    final remote = await backend.pullArrangements(bandId, since);
    if (remote.isEmpty) return const {};
    await db.transaction(() async {
      final songIds = [for (final a in remote) a.songId];
      final locals = await SyncStore.byId(
        songIds,
        (chunk) => (db.select(
          db.bandArrangements,
        )..where((a) => a.bandId.equals(bandId) & a.songId.isIn(chunk))).get(),
        (a) => a.songId,
      );
      final dirty = await store.dirty(SyncCollection.arrangements, [
        for (final id in songIds) arrangementRecordId(bandId, id),
      ]);
      final songs = await store.existingSongs(songIds);
      for (final a in remote) {
        final local = locals[a.songId];
        if (local != null && a.revision <= local.revision) continue;
        // Last writer wins: a pending local change is pushed afterwards.
        if (dirty.contains(arrangementRecordId(bandId, a.songId))) continue;
        if (!songs.contains(a.songId)) continue; // the song is not here
        if (ChangeRecorder.records(a.updatedBy, logChangesFor) &&
            !quiet.contains(arrangementRecordId(bandId, a.songId))) {
          await changes?.arrangement(local, a);
        }
        await db
            .into(db.bandArrangements)
            .insertOnConflictUpdate(
              BandArrangementsCompanion.insert(
                bandId: bandId,
                songId: a.songId,
                transpose: Value(a.transpose),
                sequence: Value(a.sequence),
                tempo: Value(a.tempo),
                revision: Value(a.revision),
                deleted: Value(a.deleted),
                updatedBy: Value(a.updatedBy),
              ),
            );
      }
      await store.setCursor(
        bandId,
        SyncCollection.arrangements,
        remote.last.revision,
      );
    });
    return {for (final a in remote) arrangementRecordId(bandId, a.songId)};
  }

  /// Pulls the server's version of the arrangements whose change the
  /// server refused in this run (#1264), so that they are undone at once;
  /// an arrangement the server does not send back (never created, or not
  /// visible any more) is removed from this device. Undone arrangements
  /// are not recorded as changes of others (ADR-0045).
  Future<int> pullUndone({String? logChangesFor}) => undone.pullAgain(
    SyncCollection.arrangements,
    RefusedRecord.arrangement,
    pull: (band, quiet) =>
        _pull(band, logChangesFor: logChangesFor, quiet: quiet),
    remove: (ids) => db.transaction(() async {
      for (final id in ids) {
        final (bandId, songId) = parseArrangementRecordId(id);
        await (db.delete(db.bandArrangements)
              ..where((a) => a.bandId.equals(bandId) & a.songId.equals(songId)))
            .go();
      }
      await (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(SyncCollection.arrangements) &
                o.recordId.isIn(ids),
          ))
          .go();
      _log.info('Removed ${ids.length} arrangements the server does not have');
    }),
  );

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
        // Created on another device meanwhile (same record ID); an error
        // that may go away is sent again as it is (#1264).
        if (!create || !e.retryCreateAsUpdate) rethrow;
        stored = await backend.pushArrangement(remote, create: false);
      }
      await db.transaction(() async {
        await (db.update(db.bandArrangements)
              ..where((a) => a.bandId.equals(bandId) & a.songId.equals(songId)))
            .write(
              BandArrangementsCompanion(
                revision: Value(stored.revision),
                updatedBy: Value(stored.updatedBy),
              ),
            );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.refused) {
        // No (longer) permission, or a validation error: sending it again
        // gets the same answer, so the change is undone (#1264).
        _log.warning('Arrangement ${entry.recordId} refused, undone', e);
        await undone.undo(
          entry,
          (
            kind: RefusedRecord.arrangement,
            id: entry.recordId,
            name: song.title,
            songTitle: song.title,
          ),
          collection: SyncCollection.arrangements,
          scope: bandId,
          revision: arrangement.revision,
          setRevision: (before) =>
              (db.update(db.bandArrangements)..where(
                    (a) => a.bandId.equals(bandId) & a.songId.equals(songId),
                  ))
                  .write(BandArrangementsCompanion(revision: Value(before))),
        );
        return PushResult.skipped;
      }
      rethrow;
    }
  }
}
