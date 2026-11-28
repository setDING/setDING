import 'package:drift/drift.dart';

import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'change_recorder.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// An attachment upload the server refused in a sync run (#1225): the
/// attachment stays on this device only.
typedef RefusedUpload = ({
  String attachmentId,
  String name,
  String songTitle,
  UploadRefusal reason,
});

/// A change of an attachment already on the server (rename, deletion,
/// restore or purge) that the server refused in a sync run (#1229): it is
/// undone on this device, which gets the server's version back.
typedef RefusedChange = ({String attachmentId, String name, String songTitle});

/// Sync of attachments (ADR-0009): PDFs and images for `{image}` (#1227).
/// Metadata by delta pull and push, files uploaded with their record and
/// downloaded to every device.
class AttachmentSync {
  AttachmentSync(
    this.db,
    this.backend,
    this.store,
    this.storage, {
    this.changes,
  });

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Where attachment files are stored; without it, files are neither
  /// uploaded nor downloaded.
  final AttachmentStorage? storage;

  /// Records changes of other people (ADR-0045).
  final ChangeRecorder? changes;

  var _refused = <RefusedUpload>[];
  var _undone = <RefusedChange>[];

  /// Organizations with refused changes whose server version has not been
  /// pulled again yet ([pullUndone]).
  final _undoneOrgs = <String>{};

  /// The uploads refused since the last call, for the report of a sync run
  /// (#1225).
  List<RefusedUpload> takeRefused() {
    final refused = _refused;
    _refused = [];
    return refused;
  }

  /// The changes refused and undone since the last call, for the report of
  /// a sync run (#1229).
  List<RefusedChange> takeUndone() {
    final undone = _undone;
    _undone = [];
    _undoneOrgs.clear();
    return undone;
  }

  /// Pulls the server's version of the attachments whose change the server
  /// refused in this run, so that they are undone at once and not only
  /// with the next sync (#1229). Undone changes are not recorded as
  /// changes of others (ADR-0045).
  ///
  /// An undone attachment the server does not send back is not visible to
  /// the person any more (the server answered 404, e.g. its song was moved
  /// out of reach): it is removed from this device at once, so that the
  /// device agrees with the "undone" message and not only after the next
  /// band refresh (#1248).
  Future<int> pullUndone({String? logChangesFor}) async {
    final orgs = _undoneOrgs.toList();
    _undoneOrgs.clear();
    final quiet = {for (final c in _undone) c.attachmentId};
    final pulled = <String>{};
    for (final org in orgs) {
      pulled.addAll(
        await _pull(org, logChangesFor: logChangesFor, quiet: quiet),
      );
    }
    await _removeInvisible(quiet.difference(pulled));
    return pulled.length;
  }

  /// Removes the attachments [ids] from this device, with their files: the
  /// server does not show them to the person any more (#1248). Personal
  /// annotations on them stay (ADR-0006).
  Future<void> _removeInvisible(Set<String> ids) async {
    if (ids.isEmpty) return;
    final gone = await db.transaction(() async {
      final rows = await (db.select(
        db.attachments,
      )..where((a) => a.id.isIn(ids))).get();
      await (db.update(db.personalOverlays)..where((o) => o.liveView.isIn(ids)))
          .write(const PersonalOverlaysCompanion(liveView: Value(null)));
      await (db.delete(db.attachments)..where((a) => a.id.isIn(ids))).go();
      return [for (final a in rows) a.fileName];
    });
    _log.info('Removed ${gone.length} attachments the server no longer shows');
    for (final f in gone) {
      await storage?.delete(f);
    }
  }

  /// Why the server refused an upload with [e] ([BackendException.refused]).
  /// Lasting answers that are not listed here are [UploadRefusal.refused]
  /// until they get a value of their own.
  static UploadRefusal refusalOf(BackendException e) {
    if (e.kind == BackendErrorKind.notAllowed) return UploadRefusal.notAllowed;
    // The organization's storage limit (ADR-0070).
    if (e.fieldCode('file') == 'storage_limit_reached') {
      return UploadRefusal.storageFull;
    }
    if (e.statusCode == 413 ||
        e.fieldCode('file') == 'validation_file_size_limit') {
      return UploadRefusal.tooLarge;
    }
    return UploadRefusal.refused;
  }

  /// Sends the attachments of [orgId] that the server refused because its
  /// storage was full (ADR-0070 §7) again when the storage route shows
  /// enough room: the oldest first, as many as fit. Without such
  /// attachments, nothing is asked.
  Future<int> retryWhenRoom(String orgId) async {
    final waiting =
        await (db.select(db.attachments).join([
                innerJoin(
                  db.songs,
                  db.songs.id.equalsExp(db.attachments.songId),
                ),
              ])
              ..where(
                db.attachments.uploadRefused.equalsValue(
                      UploadRefusal.storageFull,
                    ) &
                    db.attachments.deleted.equals(false) &
                    db.songs.libraryId.equals(orgId),
              )
              ..orderBy([OrderingTerm.asc(db.attachments.updatedAt)]))
            .map((r) => r.readTable(db.attachments))
            .get();
    if (waiting.isEmpty) return 0;
    final OrgStorage? storage;
    try {
      storage = await backend.fetchOrgStorage(orgId);
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.signedOut) rethrow;
      return 0;
    }
    if (storage == null) return 0;
    var free = storage.freeBytes;
    var retried = 0;
    for (final a in waiting) {
      if (free != null) {
        if (a.sizeBytes > free) continue;
        free -= a.sizeBytes;
      }
      await db.transaction(() async {
        await (db.update(db.attachments)..where((x) => x.id.equals(a.id)))
            .write(const AttachmentsCompanion(uploadRefused: Value(null)));
        await markDirty(db, SyncCollection.attachments, a.id, scope: orgId);
      });
      retried++;
    }
    if (retried > 0) _log.info('Uploading $retried attachments again: room');
    return retried;
  }

  /// The name of the local file of [remote], a new attachment from the
  /// server: its ID with the extension of the server's file, so that an
  /// image keeps its type and `{image}` finds it (#1227); `.pdf` when the
  /// server's file has none of the synced types (e.g. a purged one).
  static String localFileName(RemoteAttachment remote) {
    final file = remote.file ?? '';
    final dot = file.lastIndexOf('.');
    final ext = dot < 0 ? '' : file.substring(dot + 1).toLowerCase();
    final known = ext.isNotEmpty && isSyncedFile('file.$ext');
    return '${remote.id}.${known ? ext : 'pdf'}';
  }

  /// Changes by others than [logChangesFor] (the signed-in user) are
  /// recorded in the change log (ADR-0045); null records nothing, e.g. on
  /// the first sync of the library or band.
  /// Attachments in [quiet] are never recorded.
  Future<int> pull(
    String orgId, {
    String? logChangesFor,
    Set<String> quiet = const {},
  }) async =>
      (await _pull(orgId, logChangesFor: logChangesFor, quiet: quiet)).length;

  /// [pull]; returns the IDs of the attachments the server sent.
  Future<Set<String>> _pull(
    String orgId, {
    String? logChangesFor,
    Set<String> quiet = const {},
  }) async {
    final since = await store.cursor(orgId, SyncCollection.attachments);
    final remote = await backend.pullAttachments(orgId, since);
    if (remote.isEmpty) return const {};
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
          log:
              !quiet.contains(a.id) &&
              ChangeRecorder.records(a.updatedBy, logChangesFor),
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
    return {for (final a in remote) a.id};
  }

  /// Applies server metadata; returns a local file to delete, if any.
  Future<String?> _applyAttachment(
    RemoteAttachment remote, {
    required AttachmentEntry? local,
    required bool dirty,
    required bool songExists,
    bool log = false,
  }) async {
    if (local != null && remote.revision <= local.revision) return null;
    // A pending local change (rename, delete) wins and is pushed.
    if (local != null && dirty) return null;
    if (!songExists) return null; // the song is gone
    if (log) await changes?.attachment(local, remote);
    final fileName = local?.fileName ?? localFileName(remote);
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
            deletedAt: Value(remote.deletedAt),
            purged: Value(remote.purged),
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
          await storage.writeWith(a.fileName, (temp) async {
            try {
              await downloads.download(
                RemoteAttachment(
                  id: a.id,
                  organizationId: libraryId,
                  songId: a.songId,
                  name: a.name,
                  file: a.remoteFile,
                ),
                temp,
              );
            } on BackendException catch (e) {
              // Recorded at once, not after the partial file is removed:
              // meanwhile the other workers must not take new files (#935).
              if (e.kind == BackendErrorKind.network) offline ??= e;
              rethrow;
            }
          });
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
    if (song.libraryId == localBandId || !isSyncedFile(a.fileName)) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final create = a.revision == 0;
    // Deleted before it reached the server, or refused by the server: sent
    // again only when the person retries (#1225).
    if (create && (a.deleted || a.uploadRefused != null)) {
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
      // A new file is uploaded under the local file's name, which keeps
      // its type (#1227).
      file: create ? a.fileName : a.remoteFile,
      pages: a.pages,
      sizeBytes: a.sizeBytes,
      revision: a.revision,
      deleted: a.deleted,
      deletedAt: a.deletedAt,
      purged: a.purged,
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
            uploadRefused: const Value(null),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (!e.refused) {
        // A server error or a rate limit: the entry stays and is sent again
        // in the next sync; the other changes are sent meanwhile.
        if (e.kind == BackendErrorKind.server) {
          _log.warning('Attachment ${a.id} not pushed, trying again later', e);
          return PushResult.skipped;
        }
        rethrow; // no network, signed out, update needed
      }
      // Not allowed, too large or refused otherwise: a lasting answer
      // (#1225). A new file stays on this device, marked, until the person
      // retries or removes it.
      _log.warning('Attachment ${a.id} refused by the server', e);
      if (create) {
        final reason = refusalOf(e);
        await db.transaction(() async {
          await (db.update(db.attachments)..where((x) => x.id.equals(a.id)))
              .write(AttachmentsCompanion(uploadRefused: Value(reason)));
          await store.done(entry);
        });
        _refused.add((
          attachmentId: a.id,
          name: a.name,
          songTitle: song.title,
          reason: reason,
        ));
        return PushResult.skipped;
      }
      // A refused rename, deletion, restore or purge is undone (#1229): the
      // server decides, and sending it again would get the same answer.
      // This device's copy counts as older, so the server's version is
      // pulled again ([pullUndone]).
      await db.transaction(() async {
        final before = a.revision - 1;
        await (db.update(db.attachments)..where((x) => x.id.equals(a.id)))
            .write(AttachmentsCompanion(revision: Value(before)));
        final cursor = await store.cursor(
          song.libraryId,
          SyncCollection.attachments,
        );
        if (cursor > before) {
          await store.setCursor(
            song.libraryId,
            SyncCollection.attachments,
            before,
          );
        }
        await store.done(entry);
      });
      _undoneOrgs.add(song.libraryId);
      _undone.add((attachmentId: a.id, name: a.name, songTitle: song.title));
      return PushResult.skipped;
    }
  }
}
