import 'package:drift/drift.dart';

import '../data/attachment_storage.dart';
import '../data/database.dart';
import 'sync_backend.dart';

/// Loads attachment files when they are opened instead of preloading them
/// (web client, ADR-0018): the file is downloaded from the server with a
/// file token and kept in the [storage] until signing out.
class AttachmentFetcher {
  AttachmentFetcher(this.db, this.backend, this.storage);

  final AppDatabase db;
  final SyncBackend backend;
  final AttachmentStorage storage;

  final _running = <String, Future<StoredFile?>>{};

  /// The file of attachment [attachmentId], downloaded first if it is not
  /// stored yet. Null if the attachment does not exist or has no file on the
  /// server yet. Concurrent calls for the same attachment share one
  /// download. Throws a [BackendException] if the download fails.
  Future<StoredFile?> fetch(String attachmentId) =>
      _running[attachmentId] ??= _fetch(attachmentId).whenComplete(() {
        // A block: returning the removed future would wait for itself.
        _running.remove(attachmentId);
      });

  Future<StoredFile?> _fetch(String attachmentId) async {
    final row =
        await (db.select(db.attachments).join([
              innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
            ])..where(
              db.attachments.id.equals(attachmentId) &
                  db.attachments.deleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final attachment = row.readTable(db.attachments);
    final file = storage.file(attachment.fileName);
    if (await file.exists()) return file;
    final remoteFile = attachment.remoteFile;
    if (remoteFile == null) return null;
    final downloads = backend.openDownloads();
    try {
      await storage.writeWith(
        attachment.fileName,
        (sink) => downloads.download(
          RemoteAttachment(
            id: attachment.id,
            organizationId: row.readTable(db.songs).libraryId,
            songId: attachment.songId,
            name: attachment.name,
            file: remoteFile,
          ),
          sink,
        ),
      );
    } finally {
      downloads.close();
    }
    return file;
  }
}
