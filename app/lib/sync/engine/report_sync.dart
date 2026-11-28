import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'refused_changes.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of mistake reports (ADR-0060): delta pull per organization (the
/// server only returns what the person may read), push of the reporter's
/// and the resolver's changes, last writer wins. Screenshots are uploaded
/// with the report, or added later when the report was created without one
/// reaching the server; they are downloaded only when a report is opened.
class ReportSync {
  ReportSync(
    this.db,
    this.backend,
    this.store,
    this.storage, {
    RefusedChanges? undone,
  }) : undone = undone ?? RefusedChanges(store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Changes of reports the server refused for good (#1264).
  final RefusedChanges undone;

  /// Where screenshots are stored; without it, none are uploaded.
  final AttachmentStorage? storage;

  /// Whether a person with [orgRole] in an organization and [bandRoles]
  /// in its bands reads all of its reports, like the server's list rule
  /// (ADR-0060): librarians, organization admins, band leaders and set
  /// planners; everyone else only their own.
  static bool seesAll(OrgRole? orgRole, Iterable<BandRole?> bandRoles) =>
      orgRole == OrgRole.admin ||
      orgRole == OrgRole.librarian ||
      bandRoles.any((r) => r == BandRole.admin || r == BandRole.planner);

  /// Pulls the reports of [orgId] that [userId] may read; [seesAll] as
  /// [ReportSync.seesAll] for the user's current roles. When it differs
  /// from the last pull (a promotion or demotion), the reports are pulled
  /// from the start and those the user can no longer read leave the
  /// device, except the user's own changes not on the server yet (#1194).
  Future<int> pull(
    String orgId, {
    required String userId,
    required bool seesAll,
  }) async {
    final scope = seesAll ? _allReports : _ownReports;
    final rescan =
        await store.cursor(orgId, SyncCollection.songReportsScope) != scope;
    final since = rescan
        ? 0
        : await store.cursor(orgId, SyncCollection.songReports);
    return (await _pull(
      orgId,
      since,
      rescan: rescan ? (userId: userId, scope: scope) : null,
    )).length;
  }

  /// Pulls the reports of [orgId] changed since [since]; [rescan] after a
  /// change of the reports the user reads (see [pull]). Returns the IDs of
  /// the reports the server sent.
  Future<Set<String>> _pull(
    String orgId,
    int since, {
    ({String userId, int scope})? rescan,
  }) async {
    final remote = await backend.pullSongReports(orgId, since);
    if (remote.isEmpty && rescan == null) return const {};
    final removedFiles = <String>[];
    await db.transaction(() async {
      final ids = [for (final r in remote) r.id];
      if (rescan != null) {
        removedFiles.addAll(await _removeUnreadable(orgId, rescan.userId, ids));
        await store.setCursor(
          orgId,
          SyncCollection.songReportsScope,
          rescan.scope,
        );
        await store.setCursor(orgId, SyncCollection.songReports, 0);
      }
      if (remote.isEmpty) return;
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
    await _deleteFiles(removedFiles);
    return {for (final r in remote) r.id};
  }

  Future<void> _deleteFiles(List<String> files) async {
    for (final f in files) {
      if (await storage?.exists(f) ?? false) await storage?.delete(f);
    }
  }

  /// Pulls the server's version of the reports whose change the server
  /// refused in this run (#1264), so that they are undone at once; a
  /// report the server does not send back (not readable any more) leaves
  /// this device with its screenshot.
  Future<int> pullUndone() => undone.pullAgain(
    SyncCollection.songReports,
    RefusedRecord.report,
    pull: (org, _) async =>
        _pull(org, await store.cursor(org, SyncCollection.songReports)),
    remove: (ids) async {
      final rows = await (db.select(
        db.songReports,
      )..where((r) => r.id.isIn(ids))).get();
      await db.transaction(() async {
        await (db.delete(db.songReports)..where((r) => r.id.isIn(ids))).go();
        await (db.delete(db.syncOutbox)..where(
              (o) =>
                  o.collection.equals(SyncCollection.songReports) &
                  o.recordId.isIn(ids),
            ))
            .go();
      });
      await _deleteFiles([for (final r in rows) ?r.screenshotFile]);
      _log.info('Removed ${ids.length} reports the server no longer shows');
    },
  );

  /// Values of the [SyncCollection.songReportsScope] cursor.
  static const _ownReports = 1;
  static const _allReports = 2;

  /// Removes the reports of [orgId] on the server that a full pull did not
  /// return ([readable]): the user can no longer read them. The user's own
  /// pending changes stay and are pushed; pending changes of others'
  /// reports would be refused and are dropped. Returns their screenshots.
  Future<List<String>> _removeUnreadable(
    String orgId,
    String userId,
    List<String> readable,
  ) async {
    final keep = readable.toSet();
    final locals =
        await (db.select(db.songReports)..where(
              (r) =>
                  r.libraryId.equals(orgId) & r.revision.isBiggerThanValue(0),
            ))
            .get();
    final gone = [
      for (final r in locals)
        if (!keep.contains(r.id)) r,
    ];
    if (gone.isEmpty) return const [];
    final dirty = await store.dirty(SyncCollection.songReports, [
      for (final r in gone) r.id,
    ]);
    final remove = [
      for (final r in gone)
        if (!(r.authorId == userId && dirty.contains(r.id))) r,
    ];
    final ids = [for (final r in remove) r.id];
    // In chunks: SQLite limits the variables of a statement.
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, math.min(i + 500, ids.length));
      await (db.delete(db.songReports)..where((r) => r.id.isIn(chunk))).go();
      await (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(SyncCollection.songReports) &
                o.recordId.isIn(chunk),
          ))
          .go();
    }
    _log.info('Removed ${ids.length} reports of $orgId no longer readable');
    return [for (final r in remove) ?r.screenshotFile];
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
      if (!e.refused) rethrow; // sent again in the next sync
      final change = (
        kind: create ? RefusedRecord.keptReport : RefusedRecord.report,
        id: report.id,
        name: song.title,
        songTitle: song.title,
      );
      if (create) {
        // A new report the server refused for good stays on this device as
        // the person wrote it; as a report not on the server it is sent
        // again with every sync, and told once (#1264).
        _log.warning('Report ${report.id} refused, kept on this device', e);
        await undone.keepLocal(entry, change, sentAgain: true);
        return PushResult.skipped;
      }
      // Not allowed (e.g. resolved meanwhile) or a validation error: the
      // change is undone and the server's version comes back (#1264).
      _log.warning('Report ${report.id} refused by the server, undone', e);
      await undone.undo(
        entry,
        change,
        collection: SyncCollection.songReports,
        scope: report.libraryId,
        revision: report.revision,
        setRevision: (before) =>
            (db.update(db.songReports)..where((r) => r.id.equals(report.id)))
                .write(SongReportsCompanion(revision: Value(before))),
      );
      return PushResult.skipped;
    }
  }
}
