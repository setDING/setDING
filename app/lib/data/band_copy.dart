import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

const _uuid = Uuid();

/// Copies songs into another song library and sets into another band, e.g.
/// from the local library ("On this device") into an organization's library
/// and one of its bands. Copies are independent records with new IDs
/// (ADR-0017: nothing is shared across organizations); attachment files and
/// the personal adjustments are copied along.
class BandCopyService {
  BandCopyService(this.db, this.storage);

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Copies [songIds] into the library [targetLibraryId]; returns the IDs of
  /// the copies in the same order.
  Future<List<String>> copySongs(
    List<String> songIds,
    String targetLibraryId,
  ) async {
    final copies = <String>[];
    await db.transaction(() async {
      for (final id in songIds) {
        copies.add(await _copySong(id, targetLibraryId));
      }
    });
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
      await markDirty(
        db,
        SyncCollection.setlists,
        newSetId,
        scope: targetBandId,
      );
    });
    return newSetId;
  }

  Future<String> _copySong(String songId, String targetLibraryId) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingle();
    final newId = _uuid.v4();
    await db
        .into(db.songs)
        .insert(
          song.copyWith(
            id: newId,
            libraryId: targetLibraryId,
            revision: 0,
            updatedAt: DateTime.now(),
          ),
        );

    final attachments = await (db.select(
      db.attachments,
    )..where((a) => a.songId.equals(songId) & a.deleted.equals(false))).get();
    final attachmentCopies = <String, String>{};
    for (final a in attachments) {
      final id = _uuid.v4();
      final dot = a.fileName.lastIndexOf('.');
      final fileName = dot < 0 ? id : '$id${a.fileName.substring(dot)}';
      final source = storage.file(a.fileName);
      if (await source.exists()) {
        await storage.write(fileName, await source.readAsBytes());
      }
      await db
          .into(db.attachments)
          .insert(
            a.copyWith(
              id: id,
              songId: newId,
              fileName: fileName,
              revision: 0,
              updatedAt: DateTime.now(),
            ),
          );
      attachmentCopies[a.id] = id;
    }

    final overlay = await (db.select(
      db.personalOverlays,
    )..where((o) => o.songId.equals(songId))).getSingleOrNull();
    if (overlay != null) {
      final liveView = overlay.liveView;
      await db
          .into(db.personalOverlays)
          .insert(
            overlay.copyWith(
              songId: newId,
              liveView: Value(
                liveView == null ? null : attachmentCopies[liveView],
              ),
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
