import 'package:drift/drift.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

/// How long deleted songs and sets can be restored (ADR-0043). The server
/// purges synced records after this time; the device purges the local
/// library.
const trashRetention = Duration(days: 30);

/// Deleted songs and sets that can still be restored (ADR-0043): deleted
/// less than [trashRetention] ago and not purged by the server. Restoring
/// is a normal local change, synced like an edit; the server then restores
/// the personal adjustments, arrangements and annotations the song's
/// deletion removed (ADR-0015).
class TrashRepository {
  TrashRepository(this.db, this.storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final AttachmentStorage storage;
  final DateTime Function() _clock;

  DateTime get _cutoff => _clock().subtract(trashRetention);

  /// The last day a record deleted at [deletedAt] can be restored.
  static DateTime restorableUntil(DateTime deletedAt) =>
      deletedAt.add(trashRetention);

  /// Deleted songs of [libraryId], most recently deleted first.
  Stream<List<SongEntry>> watchSongs(String libraryId) =>
      (db.select(db.songs)
            ..where(
              (s) =>
                  s.libraryId.equals(libraryId) &
                  s.deleted.equals(true) &
                  s.purged.equals(false) &
                  s.deletedAt.isBiggerThanValue(_cutoff),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.deletedAt)]))
          .watch();

  /// Deleted sets of [bandId], most recently deleted first.
  Stream<List<SetlistEntry>> watchSets(String bandId) =>
      (db.select(db.setlists)
            ..where(
              (s) =>
                  s.bandId.equals(bandId) &
                  s.deleted.equals(true) &
                  s.purged.equals(false) &
                  s.deletedAt.isBiggerThanValue(_cutoff),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.deletedAt)]))
          .watch();

  /// Restores a deleted song with the attachments deleted together with it
  /// (same deletion time, stored in seconds). Items removed from sets by the deletion are not
  /// put back (only the undo right after the deletion does that).
  Future<void> restoreSong(String id) => db.transaction(() async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (song == null || !song.deleted || song.purged) return;
    await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(_clock()),
      ),
    );
    await markDirty(db, SyncCollection.songs, id, scope: song.libraryId);
    final deletedAt = song.deletedAt;
    if (deletedAt == null) return;
    final attachments =
        await (db.select(db.attachments)..where(
              (a) =>
                  a.songId.equals(id) &
                  a.deleted.equals(true) &
                  a.purged.equals(false) &
                  a.deletedAt.equals(deletedAt),
            ))
            .get();
    for (final a in attachments) {
      await (db.update(db.attachments)..where((x) => x.id.equals(a.id))).write(
        AttachmentsCompanion(
          deleted: const Value(false),
          deletedAt: const Value(null),
          updatedAt: Value(_clock()),
        ),
      );
      await markDirty(
        db,
        SyncCollection.attachments,
        a.id,
        scope: song.libraryId,
      );
    }
  });

  /// Restores a deleted set with its items.
  Future<void> restoreSet(String id) => db.transaction(() async {
    final set = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (set == null || !set.deleted || set.purged) return;
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(_clock()),
      ),
    );
    await markDirty(db, SyncCollection.setlists, id, scope: set.bandId);
  });

  /// Removes songs, sets and attachments of the local library deleted more
  /// than [trashRetention] ago, with their files; run at start. Synced
  /// records are purged by the server. Returns the number of records.
  Future<int> purgeLocal() async {
    final cutoff = _cutoff;
    final files = <String>[];
    var count = 0;
    await db.transaction(() async {
      final songs =
          await (db.select(db.songs)..where(
                (s) =>
                    s.libraryId.equals(localBandId) &
                    s.deleted.equals(true) &
                    s.deletedAt.isSmallerThanValue(cutoff),
              ))
              .get();
      final songIds = [for (final s in songs) s.id];
      final attachments =
          await (db.select(db.attachments).join([
                innerJoin(
                  db.songs,
                  db.songs.id.equalsExp(db.attachments.songId),
                ),
              ])..where(
                db.songs.libraryId.equals(localBandId) &
                    (db.attachments.songId.isIn(songIds) |
                        (db.attachments.deleted.equals(true) &
                            db.attachments.deletedAt.isSmallerThanValue(
                              cutoff,
                            ))),
              ))
              .map((r) => r.readTable(db.attachments))
              .get();
      final attachmentIds = [for (final a in attachments) a.id];
      files.addAll([for (final a in attachments) a.fileName]);
      await (db.delete(db.annotations)..where(
            (a) => a.songId.isIn(songIds) | a.target.isIn(attachmentIds),
          ))
          .go();
      await (db.delete(
        db.personalOverlays,
      )..where((o) => o.songId.isIn(songIds))).go();
      await (db.delete(
        db.bandArrangements,
      )..where((a) => a.songId.isIn(songIds))).go();
      await (db.delete(db.setItems)..where((i) => i.songId.isIn(songIds))).go();
      await (db.delete(
        db.attachments,
      )..where((a) => a.id.isIn(attachmentIds))).go();
      await (db.delete(db.songs)..where((s) => s.id.isIn(songIds))).go();
      final sets =
          await (db.select(db.setlists)..where(
                (s) =>
                    s.bandId.equals(localBandId) &
                    s.deleted.equals(true) &
                    s.deletedAt.isSmallerThanValue(cutoff),
              ))
              .get();
      final setIds = [for (final s in sets) s.id];
      await (db.delete(db.setItems)..where((i) => i.setId.isIn(setIds))).go();
      await (db.delete(db.setlists)..where((s) => s.id.isIn(setIds))).go();
      count = songIds.length + attachmentIds.length + setIds.length;
    });
    // After the transaction: a failed transaction leaves the files.
    for (final file in files) {
      if (await storage.exists(file)) await storage.delete(file);
    }
    return count;
  }
}
