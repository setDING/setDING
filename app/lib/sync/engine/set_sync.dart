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

/// Sync of sets (ADR-0004, ADR-0015): delta pull per band, a set with its
/// items as one record, last writer wins.
class SetSync {
  SetSync(this.db, this.backend, this.store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  Future<int> pull(BandView band) async {
    final since = await store.cursor(band.id, SyncCollection.setlists);
    final remote = await backend.pullSets(band.id, since);
    if (remote.isEmpty) return 0;
    await db.transaction(() async {
      final ids = [for (final s in remote) s.id];
      final locals = await SyncStore.byId(
        ids,
        (chunk) =>
            (db.select(db.setlists)..where((s) => s.id.isIn(chunk))).get(),
        (s) => s.id,
      );
      final dirty = await store.dirty(SyncCollection.setlists, ids);
      final songs = await store.existingSongs([
        for (final s in remote)
          for (final item in s.items) ?item.songId,
      ]);
      for (final set in remote) {
        await _applySet(
          set,
          local: locals[set.id],
          dirty: dirty.contains(set.id),
          songExists: songs.contains,
        );
      }
      if (remote.isNotEmpty) {
        await store.setCursor(
          band.id,
          SyncCollection.setlists,
          remote.last.revision,
        );
      }
    });
    return remote.length;
  }

  Future<void> _applySet(
    RemoteSet remote, {
    required SetlistEntry? local,
    required bool dirty,
    required bool Function(String songId) songExists,
  }) async {
    if (local != null && remote.revision <= local.revision) return;
    // Last writer wins: a pending local change is pushed afterwards.
    if (local != null && dirty) return;
    await db
        .into(db.setlists)
        .insertOnConflictUpdate(
          SetlistsCompanion.insert(
            id: remote.id,
            bandId: remote.bandId,
            name: remote.name,
            gigDate: Value(remote.gigDate),
            venue: Value(remote.venue),
            revision: Value(remote.revision),
            updatedAt: DateTime.now(),
            deleted: Value(remote.deleted),
            deletedAt: Value(remote.deletedAt),
            purged: Value(remote.purged),
            updatedBy: Value(remote.updatedBy),
          ),
        );
    await (db.delete(
      db.setItems,
    )..where((i) => i.setId.equals(remote.id))).go();
    // A deleted set keeps its items for the trash (ADR-0043).
    for (final (position, item) in remote.items.indexed) {
      var songId = item.songId;
      if (songId != null && !songExists(songId)) {
        songId = null; // not (yet) available: shown as "song missing"
      }
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: item.id.isEmpty ? _uuid.v4() : item.id,
              setId: remote.id,
              songId: Value(songId),
              position: position,
              transpose: Value(item.transpose),
              sequence: Value(item.sequence),
              note: Value(item.note),
              type: item.type,
              played: Value(item.played),
              extra: Value(item.extraJson),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<PushResult> push(OutboxEntry entry) async {
    final set = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(entry.recordId))).getSingleOrNull();
    if (set == null || set.bandId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final create = set.revision == 0;
    if (create && set.deleted) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final items =
        await (db.select(db.setItems)
              ..where((i) => i.setId.equals(set.id))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final remote = RemoteSet(
      id: set.id,
      bandId: set.bandId,
      name: set.name,
      gigDate: set.gigDate,
      venue: set.venue,
      items: [for (final i in items) RemoteSetItem.fromEntry(i)],
      revision: set.revision,
      deleted: set.deleted,
      deletedAt: set.deletedAt,
    );
    try {
      RemoteSet stored;
      try {
        stored = await backend.pushSet(remote, create: create);
      } on BackendException catch (e) {
        if (!create || e.kind != BackendErrorKind.server) rethrow;
        stored = await backend.pushSet(remote, create: false);
      }
      await db.transaction(() async {
        await (db.update(db.setlists)..where((s) => s.id.equals(set.id))).write(
          SetlistsCompanion(
            revision: Value(stored.revision),
            updatedBy: Value(stored.updatedBy),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        _log.warning('Set ${set.id} not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
      }
      rethrow;
    }
  }
}
