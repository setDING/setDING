import 'package:drift/drift.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';
import 'song_review.dart' show isReportScreenshot, removeReportsOf;

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

  /// Attachments of [libraryId] deleted on their own (their song is still
  /// in the library) that are on the server, with the title of their song,
  /// most recently deleted first. They still count against the
  /// organization's storage until purged (ADR-0070); attachments of the
  /// local library are not listed, their file goes with the undo.
  Stream<List<(AttachmentEntry, String)>> watchAttachments(String libraryId) {
    if (libraryId == localBandId) return Stream.value(const []);
    final q =
        db.select(db.attachments).join([
            innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
          ])
          ..where(
            db.songs.libraryId.equals(libraryId) &
                db.songs.deleted.equals(false) &
                db.attachments.deleted.equals(true) &
                db.attachments.purged.equals(false) &
                db.attachments.revision.isBiggerThanValue(0) &
                db.attachments.deletedAt.isBiggerThanValue(_cutoff),
          )
          ..orderBy([OrderingTerm.desc(db.attachments.deletedAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          (r.readTable(db.attachments), r.readTable(db.songs).title),
      ],
    );
  }

  /// Restores attachments deleted on their own; synced like an edit.
  Future<void> restoreAttachments(Iterable<String> ids) =>
      db.transaction(() async {
        for (final (a, song) in await _attachmentsWithSong(ids)) {
          await (db.update(
            db.attachments,
          )..where((x) => x.id.equals(a.id))).write(
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

  /// Deletes deleted attachments permanently (ADR-0070, organization admins
  /// and librarians, which the server checks): they become tombstones
  /// (`purged`), synced like an edit, so the server removes the file and it
  /// no longer counts against the storage. The file on this device goes at
  /// once.
  Future<void> purgeAttachments(Iterable<String> ids) async {
    final files = <String>[];
    await db.transaction(() async {
      for (final (a, song) in await _attachmentsWithSong(ids)) {
        if (!a.deleted || a.purged) continue;
        await (db.update(
          db.attachments,
        )..where((x) => x.id.equals(a.id))).write(
          AttachmentsCompanion(
            purged: const Value(true),
            updatedAt: Value(_clock()),
          ),
        );
        await markDirty(
          db,
          SyncCollection.attachments,
          a.id,
          scope: song.libraryId,
        );
        files.add(a.fileName);
      }
    });
    await _deleteFiles(files);
  }

  Future<List<(AttachmentEntry, SongEntry)>> _attachmentsWithSong(
    Iterable<String> ids,
  ) async {
    final rows =
        await (db.select(db.attachments).join([
              innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
            ])..where(
              db.attachments.id.isIn(ids) &
                  db.songs.libraryId.equals(localBandId).not(),
            ))
            .get();
    return [
      for (final r in rows)
        (r.readTable(db.attachments), r.readTable(db.songs)),
    ];
  }

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

  /// Deletes deleted songs permanently (#866), with their attachments; the
  /// right is the right to delete them (ADR-0023), which the server checks.
  /// In the local library they are removed with their files; in a synced
  /// library they become tombstones (`purged`, without text) and the purge
  /// is synced like an edit, the server then purges the attachments too.
  Future<void> purgeSongs(Iterable<String> ids) async {
    final files = <String>[];
    await db.transaction(() async {
      final songs =
          await (db.select(db.songs)..where(
                (s) =>
                    s.id.isIn(ids) &
                    s.deleted.equals(true) &
                    s.purged.equals(false),
              ))
              .get();
      final local = [
        for (final s in songs)
          if (s.libraryId == localBandId) s.id,
      ];
      files.addAll(await _removeSongs(local));
      for (final song in songs.where((s) => s.libraryId != localBandId)) {
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(
            purged: const Value(true),
            chordproSource: const Value(''),
            updatedAt: Value(_clock()),
          ),
        );
        await markDirty(
          db,
          SyncCollection.songs,
          song.id,
          scope: song.libraryId,
        );
        final attachments = await (db.select(
          db.attachments,
        )..where((a) => a.songId.equals(song.id))).get();
        files.addAll([for (final a in attachments) a.fileName]);
        await (db.update(
          db.attachments,
        )..where((a) => a.songId.equals(song.id))).write(
          AttachmentsCompanion(
            deleted: const Value(true),
            deletedAt: Value(song.deletedAt),
            purged: const Value(true),
          ),
        );
      }
    });
    await _deleteFiles(files);
  }

  /// Deletes deleted sets permanently (#866), with their items: removed in
  /// the local library, tombstones (`purged`) synced like an edit
  /// otherwise.
  Future<void> purgeSets(Iterable<String> ids) => db.transaction(() async {
    final sets =
        await (db.select(db.setlists)..where(
              (s) =>
                  s.id.isIn(ids) &
                  s.deleted.equals(true) &
                  s.purged.equals(false),
            ))
            .get();
    await _removeSets([
      for (final s in sets)
        if (s.bandId == localBandId) s.id,
    ]);
    for (final set in sets.where((s) => s.bandId != localBandId)) {
      await (db.delete(db.setItems)..where((i) => i.setId.equals(set.id))).go();
      await (db.update(db.setlists)..where((s) => s.id.equals(set.id))).write(
        SetlistsCompanion(
          purged: const Value(true),
          updatedAt: Value(_clock()),
        ),
      );
      await markDirty(db, SyncCollection.setlists, set.id, scope: set.bandId);
    }
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
      // Attachments deleted on their own long enough ago, too.
      final old =
          await (db.select(db.attachments).join([
                innerJoin(
                  db.songs,
                  db.songs.id.equalsExp(db.attachments.songId),
                ),
              ])..where(
                db.songs.libraryId.equals(localBandId) &
                    db.attachments.deleted.equals(true) &
                    db.attachments.deletedAt.isSmallerThanValue(cutoff) &
                    db.attachments.songId.isNotIn(songIds),
              ))
              .map((r) => r.readTable(db.attachments))
              .get();
      files.addAll(await _removeSongs(songIds));
      files.addAll(await _removeAttachments(old));
      final sets =
          await (db.select(db.setlists)..where(
                (s) =>
                    s.bandId.equals(localBandId) &
                    s.deleted.equals(true) &
                    s.deletedAt.isSmallerThanValue(cutoff),
              ))
              .get();
      final setIds = [for (final s in sets) s.id];
      await _removeSets(setIds);
      // Screenshots of mistake reports are no records of the trash.
      final attachmentFiles = files.where((f) => !isReportScreenshot(f));
      count = songIds.length + attachmentFiles.length + setIds.length;
    });
    await _deleteFiles(files);
    return count;
  }

  /// Removes songs of the local library with everything that belongs to
  /// them; returns the files of their attachments.
  Future<List<String>> _removeSongs(List<String> songIds) async {
    if (songIds.isEmpty) return const [];
    final attachments = await (db.select(
      db.attachments,
    )..where((a) => a.songId.isIn(songIds))).get();
    final files = [
      ...await _removeAttachments(attachments),
      ...await removeReportsOf(db, songIds),
    ];
    await (db.delete(
      db.annotations,
    )..where((a) => a.songId.isIn(songIds))).go();
    await (db.delete(
      db.personalOverlays,
    )..where((o) => o.songId.isIn(songIds))).go();
    await (db.delete(
      db.bandArrangements,
    )..where((a) => a.songId.isIn(songIds))).go();
    await (db.delete(db.setItems)..where((i) => i.songId.isIn(songIds))).go();
    await (db.delete(db.songs)..where((s) => s.id.isIn(songIds))).go();
    return files;
  }

  /// Removes attachments with their annotations; returns their files.
  Future<List<String>> _removeAttachments(
    List<AttachmentEntry> attachments,
  ) async {
    if (attachments.isEmpty) return const [];
    final ids = [for (final a in attachments) a.id];
    await (db.delete(db.annotations)..where((a) => a.target.isIn(ids))).go();
    await (db.delete(db.attachments)..where((a) => a.id.isIn(ids))).go();
    return [for (final a in attachments) a.fileName];
  }

  /// Removes sets of the local library with their items.
  Future<void> _removeSets(List<String> setIds) async {
    if (setIds.isEmpty) return;
    await (db.delete(db.setItems)..where((i) => i.setId.isIn(setIds))).go();
    await (db.delete(db.setlists)..where((s) => s.id.isIn(setIds))).go();
  }

  /// Deletes files after the transaction: a failed transaction leaves them.
  Future<void> _deleteFiles(List<String> files) async {
    for (final file in files) {
      if (await storage.exists(file)) await storage.delete(file);
    }
  }
}
