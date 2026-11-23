import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of mistake reports (ADR-0060): delta pull per organization (the
/// server only returns what the person may read), push of the reporter's
/// and the resolver's changes, last writer wins. Screenshots are uploaded
/// with the report, or added later when the report was created without one
/// reaching the server; they are downloaded only when a report is opened.
class ReportSync {
  ReportSync(this.db, this.backend, this.store, this.storage);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Where screenshots are stored; without it, none are uploaded.
  final AttachmentStorage? storage;

  Future<int> pull(String orgId) async {
    final since = await store.cursor(orgId, SyncCollection.songReports);
    final remote = await backend.pullSongReports(orgId, since);
    if (remote.isEmpty) return 0;
    final removedFiles = <String>[];
    await db.transaction(() async {
      final ids = [for (final r in remote) r.id];
      final locals = await SyncStore.byId(
        ids,
        (chunk) =>
            (db.select(db.songReports)..where((r) => r.id.isIn(chunk))).get(),
        (r) => r.id,
      );
      final dirty = await store.dirty(SyncCollection.songReports, ids);
      for (final r in remote) {
        final local = locals[r.id];
        if (local != null && r.revision <= local.revision) continue;
        // A pending local change wins and is pushed.
        if (local != null && dirty.contains(r.id)) continue;
        if ((r.purged || r.deleted && local == null) &&
            local?.screenshotFile != null) {
          removedFiles.add(local!.screenshotFile!);
        }
        await db
            .into(db.songReports)
            .insertOnConflictUpdate(
              SongReportsCompanion.insert(
                id: r.id,
                songId: r.songId,
                libraryId: r.organizationId,
                authorId: Value(r.authorId),
                category: r.category,
                comment: Value(r.comment),
                location: Value(
                  r.location == null ? null : jsonEncode(r.location),
                ),
                screenshotFile: Value(r.purged ? null : local?.screenshotFile),
                remoteScreenshot: Value(r.screenshot),
                status: Value(r.status),
                resolution: Value(r.resolution),
                resolvedBy: Value(r.resolvedBy),
                resolvedAt: Value(r.resolvedAt),
                createdAt: r.created ?? local?.createdAt ?? DateTime.now(),
                revision: Value(r.revision),
                deleted: Value(r.deleted),
                purged: Value(r.purged),
              ),
            );
      }
      await store.setCursor(
        orgId,
        SyncCollection.songReports,
        remote.last.revision,
      );
    });
    for (final f in removedFiles) {
      if (await storage?.exists(f) ?? false) await storage?.delete(f);
    }
    return remote.length;
  }

  Future<PushResult> push(OutboxEntry entry, String userId) async {
    final row = await (db.select(db.songReports).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.songReports.songId)),
    ])..where(db.songReports.id.equals(entry.recordId))).getSingleOrNull();
    if (row == null) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final report = row.readTable(db.songReports);
    final song = row.readTable(db.songs);
    if (report.libraryId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    // The song must be on the server first.
    if (song.revision == 0) {
      if (song.deleted) await store.done(entry);
      return PushResult.skipped;
    }
    final create = report.revision == 0;
    // A screenshot not on the server yet goes with the create, or is added
    // to the report afterwards (never replaced, ADR-0060).
    List<int>? screenshot;
    final file = report.screenshotFile;
    final storage = this.storage;
    if (file != null &&
        report.remoteScreenshot == null &&
        storage != null &&
        await storage.exists(file)) {
      screenshot = await storage.file(file).readAsBytes();
    }
    final asAuthor = report.authorId == userId;
    Object? location;
    try {
      location = report.location == null ? null : jsonDecode(report.location!);
    } on FormatException {
      location = null;
    }
    final remote = RemoteSongReport(
      id: report.id,
      songId: report.songId,
      organizationId: report.libraryId,
      category: report.category,
      comment: report.comment,
      location: location is Map ? location.cast<String, dynamic>() : null,
      status: report.status,
      resolution: report.resolution,
      revision: report.revision,
    );
    try {
      final stored = await backend.pushSongReport(
        remote,
        create: create,
        asAuthor: create || asAuthor,
        asApprover: !create && !asAuthor || report.resolvedBy == userId,
        screenshot: screenshot,
        screenshotName: file,
      );
      await db.transaction(() async {
        await (db.update(
          db.songReports,
        )..where((r) => r.id.equals(report.id))).write(
          SongReportsCompanion(
            revision: Value(stored.revision),
            authorId: Value(stored.authorId),
            remoteScreenshot: Value(stored.screenshot),
            resolvedBy: Value(stored.resolvedBy),
            resolvedAt: Value(stored.resolvedAt),
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
      // Not allowed (e.g. resolved meanwhile) or refused.
      _log.warning('Report ${report.id} not pushed', e);
      await db.transaction(() async {
        if (!create) {
          // The server's version replaces the refused change at the next
          // pull: this device's copy counts as older, and the report is
          // pulled again.
          final before = report.revision - 1;
          await (db.update(db.songReports)
                ..where((r) => r.id.equals(report.id)))
              .write(SongReportsCompanion(revision: Value(before)));
          final cursor = await store.cursor(
            report.libraryId,
            SyncCollection.songReports,
          );
          if (cursor > before) {
            await store.setCursor(
              report.libraryId,
              SyncCollection.songReports,
              before,
            );
          }
        }
        await store.done(entry);
      });
      return PushResult.skipped;
    }
  }
}
