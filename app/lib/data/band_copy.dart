import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';
import 'song_repository.dart' show overlayOwnerFor;

const _uuid = Uuid();

/// Copies songs into another song library and sets into another band, e.g.
/// from the local library ("On this device") into an organization's library
/// and one of its bands. Copies are independent records with new IDs
/// (ADR-0017: nothing is shared across organizations); attachment files and
/// the personal adjustments are copied along.
class BandCopyService {
  BandCopyService(this.db, this.storage, {this.userId});

  final AppDatabase db;
  final AttachmentStorage storage;

  /// The signed-in user: the copy gets their adjustments (ADR-0020).
  final String? userId;

  /// Copies [songIds] into the library [targetLibraryId]; returns the IDs of
  /// the copies in the same order.
  Future<List<String>> copySongs(
    List<String> songIds,
    String targetLibraryId,
  ) async {
    final copies = <String>[];
    final files = <(String, String)>[];
    await db.transaction(() async {
      final works = <String, List<String>>{};
      for (final id in songIds) {
        copies.add(await _copySong(id, targetLibraryId, files, works));
      }
      await _linkCopies(works);
    });
    await _copyFiles(files);
    return copies;
  }

  /// Copies a set into [targetBandId] and its songs into the band's library
  /// [targetLibraryId]; songs that occur several times in the set are copied
  /// once. With [copySongs] false (target band in the same library), the
  /// copy references the same songs. Returns the new set ID.
  Future<String> copySet(
    String setId, {
    required String targetBandId,
    required String targetLibraryId,
    bool copySongs = true,
  }) async {
    final newSetId = _uuid.v4();
    final files = <(String, String)>[];
    await db.transaction(() async {
      final set = await (db.select(
        db.setlists,
      )..where((s) => s.id.equals(setId))).getSingle();
      await db
          .into(db.setlists)
          .insert(
            set.copyWith(
              id: newSetId,
              bandId: targetBandId,
              revision: 0,
              updatedAt: DateTime.now(),
            ),
          );
      final items =
          await (db.select(db.setItems)
                ..where((i) => i.setId.equals(setId))
                ..orderBy([(i) => OrderingTerm.asc(i.position)]))
              .get();
      final songCopies = <String, String>{};
      final works = <String, List<String>>{};
      for (final item in items) {
        String? songId;
        if (item.songId case final original?) {
          final song = await (db.select(
            db.songs,
          )..where((s) => s.id.equals(original))).getSingleOrNull();
          if (song == null || song.deleted) continue;
          songId = copySongs
              ? songCopies[original] ??= await _copySong(
                  original,
                  targetLibraryId,
                  files,
                  works,
                )
              : original;
        }
        await db
            .into(db.setItems)
            .insert(
              item.copyWith(
                id: _uuid.v4(),
                setId: newSetId,
                songId: Value(songId),
              ),
            );
      }
      await _linkCopies(works);
      await markDirty(
        db,
        SyncCollection.setlists,
        newSetId,
        scope: targetBandId,
      );
    });
    await _copyFiles(files);
    return newSetId;
  }

  /// Copies the attachment files ([files]: source, copy) after the database
  /// transaction: file I/O does not hold the transaction open, and a failed
  /// transaction leaves no files behind. A missing source is skipped (not
  /// downloaded yet); the copy is then missing like an undownloaded file.
  Future<void> _copyFiles(List<(String, String)> files) async {
    for (final (from, to) in files) {
      await storage.copy(from, to);
    }
  }

  /// Links the copies that were language versions of one work among the
  /// copied songs ([works]: original group, copies) under a new group of the
  /// target library, as an archive import does (ADR-0053, #878); never with
  /// songs already there. Set before the copies' first push, so they are
  /// created with their group.
  Future<void> _linkCopies(Map<String, List<String>> works) async {
    for (final ids in works.values) {
      if (ids.length < 2) continue;
      final work = _uuid.v4();
      await (db.update(db.songs)..where((s) => s.id.isIn(ids))).write(
        SongsCompanion(workId: Value(work)),
      );
    }
  }

  /// Copies a song into the database; its attachment files are added to
  /// [files] for [_copyFiles], the copy to its original's group in [works]
  /// for [_linkCopies].
  Future<String> _copySong(
    String songId,
    String targetLibraryId,
    List<(String, String)> files, [
    Map<String, List<String>>? works,
  ]) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingle();
    final newId = _uuid.v4();
    final now = DateTime.now();
    await db
        .into(db.songs)
        .insert(
          song.copyWith(
            id: newId,
            libraryId: targetLibraryId,
            revision: 0,
            updatedAt: now,
            // A copy is a new song of the target library (#868).
            createdAt: Value(now),
            // A copy is no language version of the original's work; a group
            // never spans libraries (ADR-0053). Its language stays; copies
            // of versions copied together are linked by [_linkCopies].
            workId: const Value(null),
          ),
        );
    if ((song.workId, works) case (final work?, final works?)) {
      (works[work] ??= []).add(newId);
    }

    final attachments = await (db.select(
      db.attachments,
    )..where((a) => a.songId.equals(songId) & a.deleted.equals(false))).get();
    final attachmentCopies = <String, String>{};
    for (final a in attachments) {
      final id = _uuid.v4();
      final dot = a.fileName.lastIndexOf('.');
      final fileName = dot < 0 ? id : '$id${a.fileName.substring(dot)}';
      files.add((a.fileName, fileName));
      await db
          .into(db.attachments)
          .insert(
            a.copyWith(
              id: id,
              songId: newId,
              fileName: fileName,
              // A new record: its file is uploaded, not the original's.
              remoteFile: const Value(null),
              revision: 0,
              updatedAt: DateTime.now(),
            ),
          );
      attachmentCopies[a.id] = id;
    }

    // The current person's adjustments, for their owner in the target
    // library (ADR-0020).
    final overlay =
        await (db.select(db.personalOverlays)..where(
              (o) =>
                  o.songId.equals(songId) &
                  o.ownerId.equals(overlayOwnerFor(song.libraryId, userId)),
            ))
            .getSingleOrNull();
    if (overlay != null) {
      final liveView = overlay.liveView;
      await db
          .into(db.personalOverlays)
          .insert(
            overlay.copyWith(
              ownerId: overlayOwnerFor(targetLibraryId, userId),
              songId: newId,
              liveView: Value(
                liveView == null ? null : attachmentCopies[liveView],
              ),
            ),
          );
    }
    // The current person's freehand annotations (ADR-0032), as new strokes
    // on the copies of the song and its attachments; synced as records that
    // never reached the server.
    final strokes =
        await (db.select(db.annotations)..where(
              (x) =>
                  x.songId.equals(songId) &
                  x.ownerId.equals(overlayOwnerFor(song.libraryId, userId)) &
                  x.stroke.isNotNull(),
            ))
            .get();
    for (final x in strokes) {
      final target = x.target.isEmpty ? '' : attachmentCopies[x.target];
      if (target == null) continue;
      await db
          .into(db.annotations)
          .insert(
            x.copyWith(
              id: _uuid.v4(),
              ownerId: overlayOwnerFor(targetLibraryId, userId),
              songId: newId,
              target: target,
              pending: 1,
            ),
          );
    }
    await markDirty(db, SyncCollection.songs, newId, scope: targetLibraryId);
    for (final a in attachments) {
      if (!isPdfFile(a.fileName)) continue;
      final id = attachmentCopies[a.id]!;
      await markDirty(
        db,
        SyncCollection.attachments,
        id,
        scope: targetLibraryId,
      );
    }
    return newId;
  }
}
