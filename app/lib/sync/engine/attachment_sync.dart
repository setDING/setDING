import 'package:drift/drift.dart';

import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of PDF attachments (ADR-0009): metadata by delta pull and push,
/// files uploaded with their record and downloaded to every device.
class AttachmentSync {
  AttachmentSync(this.db, this.backend, this.store, this.storage);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Where attachment files are stored; without it, files are neither
  /// uploaded nor downloaded.
  final AttachmentStorage? storage;

  Future<int> pull(String orgId) async {
    final since = await store.cursor(orgId, SyncCollection.attachments);
    final remote = await backend.pullAttachments(orgId, since);
    if (remote.isEmpty) return 0;
    final removedFiles = <String>[];
    await db.transaction(() async {
      final ids = [for (final a in remote) a.id];
      final locals = await SyncStore.byId(
        ids,
        (chunk) =>
            (db.select(db.attachments)..where((a) => a.id.isIn(chunk))).get(),
        (a) => a.id,
      );
      final dirty = await store.dirty(SyncCollection.attachments, ids);
      final songs = await store.existingSongs([
        for (final a in remote) a.songId,
      ]);
      for (final a in remote) {
        final file = await _applyAttachment(
          a,
          local: locals[a.id],
          dirty: dirty.contains(a.id),
          songExists: songs.contains(a.songId),
        );
        if (file != null) removedFiles.add(file);
      }
      if (remote.isNotEmpty) {
        await store.setCursor(
          orgId,
          SyncCollection.attachments,
          remote.last.revision,
        );
      }
    });
    for (final f in removedFiles) {
      await storage?.delete(f);
    }
    return remote.length;
  }

  /// Applies server metadata; returns a local file to delete, if any.
  Future<String?> _applyAttachment(
    RemoteAttachment remote, {
    required AttachmentEntry? local,
    required bool dirty,
    required bool songExists,
  }) async {
    if (local != null && remote.revision <= local.revision) return null;
    // A pending local change (rename, delete) wins and is pushed.
    if (local != null && dirty) return null;
    if (!songExists) return null; // the song is gone
    final fileName = local?.fileName ?? '${remote.id}.pdf';
    await db
        .into(db.attachments)
        .insertOnConflictUpdate(
          AttachmentsCompanion.insert(
            id: remote.id,
            songId: remote.songId,
            name: remote.name,
            fileName: fileName,
            remoteFile: Value(remote.file),
            pages: Value(remote.pages),
            sizeBytes: remote.sizeBytes,
            revision: Value(remote.revision),
            updatedAt: DateTime.now(),
            deleted: Value(remote.deleted),
          ),
        );
    if (!remote.deleted) return null;
    await (db.update(db.personalOverlays)
          ..where((o) => o.liveView.equals(remote.id)))
        .write(const PersonalOverlaysCompanion(liveView: Value(null)));
    return fileName;
  }

  /// Attachment files downloaded at the same time.
  static const parallelDownloads = 3;

  /// Downloads attachment files that are not on this device yet
  /// (ADR-0009: all attachments are available offline).
  Future<int> downloadMissing() async {
    final storage = this.storage;
    if (storage == null) return 0;
    final rows =
        await (db.select(db.attachments).join([
              innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
            ])..where(
              db.attachments.deleted.equals(false) &
                  db.attachments.remoteFile.isNotNull() &
                  db.songs.deleted.equals(false),
            ))
            .get();
    final missing = [
      for (final r in rows)
        if (!await storage.exists(r.readTable(db.attachments).fileName))
          (r.readTable(db.attachments), r.readTable(db.songs).libraryId),
    ];
    if (missing.isEmpty) return 0;
    final downloads = backend.openDownloads();
    var count = 0;
    var next = 0;
    BackendException? offline;
    // A few workers take the next missing file until all are done or the
    // network is gone.
    Future<void> worker() async {
      while (offline == null && next < missing.length) {
        final (a, libraryId) = missing[next++];
        try {
          await storage.writeWith(
            a.fileName,
            (temp) => downloads.download(
              RemoteAttachment(
                id: a.id,
                organizationId: libraryId,
                songId: a.songId,
                name: a.name,
                file: a.remoteFile,
              ),
              temp,
            ),
          );
          count++;
        } on BackendException catch (e) {
          if (e.kind == BackendErrorKind.network) {
            offline ??= e;
            return;
          }
          // This file only; the others are still downloaded.
          _log.warning('Attachment ${a.id} not downloaded', e);
        }
      }
    }

    try {
      await Future.wait([for (var i = 0; i < parallelDownloads; i++) worker()]);
    } finally {
      downloads.close();
    }
    if (offline case final e?) throw e;
    return count;
  }

  Future<PushResult> push(OutboxEntry entry) async {
    final storage = this.storage;
    final row = await (db.select(db.attachments).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
    ])..where(db.attachments.id.equals(entry.recordId))).getSingleOrNull();
    if (row == null || storage == null) {
      if (row == null) await store.done(entry);
      return PushResult.skipped;
    }
    final a = row.readTable(db.attachments);
    final song = row.readTable(db.songs);
    if (song.libraryId == localBandId || !isPdfFile(a.fileName)) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final create = a.revision == 0;
    if (create && a.deleted) {
      await store.done(entry);
      return PushResult.skipped;
    }
    // The song must be on the server first (pushed in this run or before).
    if (song.revision == 0) return PushResult.skipped;
    List<int>? bytes;
    if (create) {
      if (!await storage.exists(a.fileName)) {
        await store.done(entry);
        return PushResult.skipped;
      }
      bytes = await storage.file(a.fileName).readAsBytes();
    }
    final remote = RemoteAttachment(
      id: a.id,
      organizationId: song.libraryId,
      songId: a.songId,
      name: a.name,
      pages: a.pages,
      sizeBytes: a.sizeBytes,
      revision: a.revision,
      deleted: a.deleted,
    );
    try {
      final stored = await backend.pushAttachment(
        remote,
        create: create,
        bytes: bytes,
      );
      await db.transaction(() async {
        await (db.update(
          db.attachments,
        )..where((x) => x.id.equals(a.id))).write(
          AttachmentsCompanion(
            revision: Value(stored.revision),
            remoteFile: Value(stored.file ?? a.remoteFile),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.network ||
          e.kind == BackendErrorKind.signedOut) {
        rethrow;
      }
      // Not allowed, too large or refused: the attachment stays local.
      _log.warning('Attachment ${a.id} not pushed', e);
      await store.done(entry);
      return PushResult.skipped;
    }
  }
}
