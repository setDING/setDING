import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/attachment_storage.dart';
import '../data/band_copy.dart';
import '../data/band_view.dart';
import '../data/database.dart';
import '../data/outbox.dart';
import '../data/song_repository.dart' show SongMeta, songMetas;
import 'band_service.dart';
import 'sync_backend.dart';

const _uuid = Uuid();

/// Result of one sync run.
@immutable
class SyncReport {
  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.downloaded = 0,
    this.error,
  });

  final int pulled;
  final int pushed;

  /// New conflicts detected in this run.
  final int conflicts;

  /// Attachment files downloaded in this run.
  final int downloaded;

  /// Why the run stopped early (e.g. offline), or null.
  final BackendErrorKind? error;
}

/// Synchronizes songs and sets between the local database and the server
/// (ADR-0004): delta pull per organization (songs) and band (sets) since
/// the last pulled revision, then push of the outbox. Songs are never
/// overwritten silently: a song changed on both sides becomes a
/// [SongConflict] for the user to resolve. Sets use last writer wins.
///
/// The local library ("On this device") is never synced.
class SyncEngine {
  SyncEngine(
    this.db,
    this.backend,
    this.bands, {
    this.copies,
    AttachmentStorage? storage,
  }) : storage = storage ?? copies?.storage;

  final AppDatabase db;

  /// Where attachment files are stored (ADR-0009); without it, attachment
  /// files are neither uploaded nor downloaded.
  final AttachmentStorage? storage;
  final SyncBackend backend;
  final BandService bands;

  /// Used to keep both versions of a conflicting song.
  final BandCopyService? copies;

  Future<SyncReport>? _running;

  /// Runs a sync; concurrent calls share the running one.
  Future<SyncReport> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncReport> _sync() async {
    final user = backend.currentUser;
    if (user == null) return const SyncReport();
    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;
    var downloaded = 0;
    try {
      await bands.refresh();
      final visible = [
        for (final b in await bands.watchBands(user.id).first)
          if (!b.isLocal) b,
      ];
      final orgIds = {for (final b in visible) b.organizationId!};
      final orgs = await bands.watchOrganizations(user.id).first;
      orgIds.addAll(orgs.map((o) => o.id));

      for (final org in orgIds) {
        final r = await _pullSongs(org);
        pulled += r.$1;
        conflicts += r.$2;
        pulled += await _pullAttachments(org);
      }
      for (final band in visible) {
        pulled += await _pullSets(band);
      }
      await _enqueueUnsynced(visible);
      final p = await _push();
      pushed += p.$1;
      conflicts += p.$2;
      downloaded += await _downloadMissing();
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
      );
    } on BackendException catch (e) {
      debugPrint('Sync stopped: $e');
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
        error: e.kind,
      );
    }
  }

  // Pull -------------------------------------------------------------------------

  Future<int> _cursor(String scope, String collection) async {
    final row =
        await (db.select(db.syncCursors)..where(
              (c) => c.scope.equals(scope) & c.collection.equals(collection),
            ))
            .getSingleOrNull();
    return row?.revision ?? 0;
  }

  Future<void> _setCursor(String scope, String collection, int revision) => db
      .into(db.syncCursors)
      .insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
          scope: scope,
          collection: collection,
          revision: Value(revision),
        ),
      );

  /// Rows for [ids], loaded in chunks (SQLite limits the variables of a
  /// statement), by ID.
  static Future<Map<String, T>> _byId<T>(
    List<String> ids,
    Future<List<T>> Function(List<String> chunk) load,
    String Function(T) id,
  ) async {
    const chunkSize = 500;
    final result = <String, T>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, math.min(i + chunkSize, ids.length));
      for (final row in await load(chunk)) {
        result[id(row)] = row;
      }
    }
    return result;
  }

  /// Which of [ids] have a pending local change in [collection].
  Future<Set<String>> _dirty(String collection, List<String> ids) async =>
      (await _byId(
        ids,
        (chunk) =>
            (db.select(db.syncOutbox)..where(
                  (o) =>
                      o.collection.equals(collection) & o.recordId.isIn(chunk),
                ))
                .get(),
        (o) => o.recordId,
      )).keys.toSet();

  /// Which of [ids] are songs on this device (also deleted ones).
  Future<Set<String>> _existingSongs(List<String> ids) async => (await _byId(
    ids.toSet().toList(),
    (chunk) =>
        (db.selectOnly(db.songs)
              ..addColumns([db.songs.id])
              ..where(db.songs.id.isIn(chunk)))
            .map((r) => r.read(db.songs.id)!)
            .get(),
    (id) => id,
  )).keys.toSet();

  /// Returns (pulled, new conflicts).
  Future<(int, int)> _pullSongs(String orgId) async {
    final since = await _cursor(orgId, SyncCollection.songs);
    final remote = await backend.pullSongs(orgId, since);
    if (remote.isEmpty) return (0, 0);
    final metas = await songMetas([for (final s in remote) s.chordpro]);
    var conflicts = 0;
    await db.transaction(() async {
      final ids = [for (final s in remote) s.id];
      final locals = await _byId(
        ids,
        (chunk) => (db.select(db.songs)..where((s) => s.id.isIn(chunk))).get(),
        (s) => s.id,
      );
      final dirty = await _dirty(SyncCollection.songs, ids);
      final known = (await _byId(
        ids,
        (chunk) => (db.select(
          db.songConflicts,
        )..where((c) => c.songId.isIn(chunk))).get(),
        (c) => c.songId,
      )).keys.toSet();
      for (final (i, song) in remote.indexed) {
        if (await _applySong(
          song,
          metas[i],
          local: locals[song.id],
          dirty: dirty.contains(song.id),
          knownConflict: known.contains(song.id),
        )) {
          conflicts++;
        }
      }
      if (remote.isNotEmpty) {
        await _setCursor(orgId, SyncCollection.songs, remote.last.revision);
      }
    });
    return (remote.length, conflicts);
  }

  /// Applies a server song ([local], [dirty] and [knownConflict] describe
  /// this device's state); returns true if it became a new conflict.
  Future<bool> _applySong(
    RemoteSong remote,
    SongMeta meta, {
    required SongEntry? local,
    required bool dirty,
    required bool knownConflict,
  }) async {
    if (local != null && remote.revision <= local.revision) return false;
    if (local != null && dirty) {
      // Changed here and on the server: never overwrite silently.
      await db
          .into(db.songConflicts)
          .insertOnConflictUpdate(
            SongConflictsCompanion.insert(
              songId: remote.id,
              title: remote.title,
              chordproSource: remote.chordpro,
              revision: remote.revision,
              deleted: Value(remote.deleted),
              detectedAt: DateTime.now(),
            ),
          );
      return !knownConflict;
    }
    await writeSong(remote, meta: meta);
    return false;
  }

  /// Stores the server state of a song locally (no outbox entry); [meta]
  /// is extracted from its source unless given.
  Future<void> writeSong(RemoteSong remote, {SongMeta? meta}) async {
    meta ??= SongMeta.fromSource(remote.chordpro);
    await db
        .into(db.songs)
        .insertOnConflictUpdate(
          SongsCompanion.insert(
            id: remote.id,
            libraryId: remote.organizationId,
            chordproSource: Value(remote.chordpro),
            title: meta.title ?? remote.title,
            artist: Value(meta.artist),
            songKey: Value(meta.key),
            tempo: Value(meta.tempo),
            sortTitle: Value(meta.sortTitle),
            sortArtist: Value(meta.sortArtist),
            tags: Value(meta.tagsColumn),
            revision: Value(remote.revision),
            updatedAt: DateTime.now(),
            deleted: Value(remote.deleted),
          ),
        );
    if (remote.deleted) {
      await (db.delete(
        db.setItems,
      )..where((i) => i.songId.equals(remote.id))).go();
    }
  }

  Future<int> _pullAttachments(String orgId) async {
    final since = await _cursor(orgId, SyncCollection.attachments);
    final remote = await backend.pullAttachments(orgId, since);
    if (remote.isEmpty) return 0;
    final removedFiles = <String>[];
    await db.transaction(() async {
      final ids = [for (final a in remote) a.id];
      final locals = await _byId(
        ids,
        (chunk) =>
            (db.select(db.attachments)..where((a) => a.id.isIn(chunk))).get(),
        (a) => a.id,
      );
      final dirty = await _dirty(SyncCollection.attachments, ids);
      final songs = await _existingSongs([for (final a in remote) a.songId]);
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
        await _setCursor(
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
  Future<int> _downloadMissing() async {
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
          debugPrint('Attachment ${a.id} not downloaded: $e');
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

  Future<int> _pullSets(BandView band) async {
    final since = await _cursor(band.id, SyncCollection.setlists);
    final remote = await backend.pullSets(band.id, since);
    if (remote.isEmpty) return 0;
    await db.transaction(() async {
      final ids = [for (final s in remote) s.id];
      final locals = await _byId(
        ids,
        (chunk) =>
            (db.select(db.setlists)..where((s) => s.id.isIn(chunk))).get(),
        (s) => s.id,
      );
      final dirty = await _dirty(SyncCollection.setlists, ids);
      final songs = await _existingSongs([
        for (final s in remote)
          for (final item in s.items)
            if (item['song'] case final String id) id,
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
        await _setCursor(
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
          ),
        );
    await (db.delete(
      db.setItems,
    )..where((i) => i.setId.equals(remote.id))).go();
    if (remote.deleted) return;
    for (final (position, item) in remote.items.indexed) {
      final type = SetItemType.values.firstWhere(
        (t) => t.name == item['type'],
        orElse: () => SetItemType.text,
      );
      var songId = item['song'] as String?;
      if (songId != null && !songExists(songId)) {
        songId = null; // not (yet) available: shown as "song missing"
      }
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: (item['id'] as String?) ?? _uuid.v4(),
              setId: remote.id,
              songId: Value(songId),
              position: position,
              transpose: Value((item['transpose'] as num?)?.toInt() ?? 0),
              sequence: Value(item['sequence'] as String?),
              note: Value(item['note'] as String?),
              type: type,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  // Push -------------------------------------------------------------------------

  /// Adds records that never reached the server (revision 0) to the outbox,
  /// e.g. songs copied into an organization before the outbox existed
  /// (app schema < 5). Only records the user may push are added, so a
  /// rejected change is not retried on every sync.
  Future<void> _enqueueUnsynced(List<BandView> bands) async {
    final libraries = {
      for (final b in bands)
        if (b.canEditSongs) b.libraryId,
    }..remove(localBandId);
    final setBands = {
      for (final b in bands)
        if (b.canManageSets && !b.isLocal) b.id,
    };
    String placeholders(int n) => List.filled(n, '?').join(', ');
    var added = 0;
    Future<void> enqueue(
      String collection,
      String select,
      List<String> args,
    ) async => added += await db.customUpdate(
      'INSERT OR IGNORE INTO sync_outbox (collection, record_id, version) '
      "SELECT '$collection', id, 1 FROM ($select)",
      variables: [for (final a in args) Variable.withString(a)],
    );
    if (libraries.isNotEmpty) {
      final libs = libraries.toList();
      await enqueue(
        SyncCollection.songs,
        'SELECT id FROM songs WHERE revision = 0 AND deleted = 0 '
        'AND library_id IN (${placeholders(libs.length)})',
        libs,
      );
      await enqueue(
        SyncCollection.attachments,
        'SELECT a.id FROM attachments a JOIN songs s ON s.id = a.song_id '
        'WHERE a.revision = 0 AND a.deleted = 0 AND s.deleted = 0 '
        "AND lower(a.file_name) LIKE '%.pdf' "
        'AND s.library_id IN (${placeholders(libs.length)})',
        libs,
      );
    }
    if (setBands.isNotEmpty) {
      final ids = setBands.toList();
      await enqueue(
        SyncCollection.setlists,
        'SELECT id FROM setlists WHERE revision = 0 AND deleted = 0 '
        'AND band_id IN (${placeholders(ids.length)})',
        ids,
      );
    }
    if (added > 0) {
      db.notifyUpdates({
        TableUpdate.onTable(db.syncOutbox, kind: UpdateKind.insert),
      });
    }
  }

  /// Returns (pushed, new conflicts).
  Future<(int, int)> _push() async {
    var pushed = 0;
    var conflicts = 0;
    // Songs first: an attachment needs its song on the server.
    const order = [
      SyncCollection.songs,
      SyncCollection.setlists,
      SyncCollection.attachments,
    ];
    final entries = await db.select(db.syncOutbox).get()
      ..sort(
        (a, b) =>
            order.indexOf(a.collection).compareTo(order.indexOf(b.collection)),
      );
    for (final entry in entries) {
      switch (entry.collection) {
        case SyncCollection.songs:
          final r = await _pushSong(entry);
          if (r == _Push.done) pushed++;
          if (r == _Push.conflict) conflicts++;
        case SyncCollection.setlists:
          if (await _pushSet(entry) == _Push.done) pushed++;
        case SyncCollection.attachments:
          if (await _pushAttachment(entry) == _Push.done) pushed++;
      }
    }
    return (pushed, conflicts);
  }

  Future<void> _done(OutboxEntry entry) =>
      (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(entry.collection) &
                o.recordId.equals(entry.recordId) &
                o.version.equals(entry.version),
          ))
          .go();

  Future<_Push> _pushSong(OutboxEntry entry) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(entry.recordId))).getSingleOrNull();
    final hasConflict =
        await (db.select(
          db.songConflicts,
        )..where((c) => c.songId.equals(entry.recordId))).getSingleOrNull() !=
        null;
    if (song == null || song.libraryId == localBandId) {
      await _done(entry);
      return _Push.skipped;
    }
    if (hasConflict) return _Push.skipped; // waits for the user
    final create = song.revision == 0;
    if (create && song.deleted) {
      await _done(entry); // created and deleted before it ever synced
      return _Push.skipped;
    }
    final remote = RemoteSong(
      id: song.id,
      organizationId: song.libraryId,
      title: song.title,
      chordpro: song.chordproSource,
      revision: song.revision,
      deleted: song.deleted,
    );
    try {
      final stored = await _pushSongOrRecover(remote, create: create);
      await db.transaction(() async {
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(revision: Value(stored.revision)),
        );
        await _done(entry);
      });
      return _Push.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.conflict) {
        final server = await backend.fetchSong(song.id);
        if (server != null) {
          await db
              .into(db.songConflicts)
              .insertOnConflictUpdate(
                SongConflictsCompanion.insert(
                  songId: song.id,
                  title: server.title,
                  chordproSource: server.chordpro,
                  revision: server.revision,
                  deleted: Value(server.deleted),
                  detectedAt: DateTime.now(),
                ),
              );
        }
        return _Push.conflict;
      }
      if (e.kind == BackendErrorKind.notAllowed) {
        // No (longer) permission: the change stays local.
        debugPrint('Song ${song.id} not pushed: not allowed');
        await _done(entry);
        return _Push.skipped;
      }
      rethrow;
    }
  }

  /// A create whose response got lost is retried as an update.
  Future<RemoteSong> _pushSongOrRecover(
    RemoteSong song, {
    required bool create,
  }) async {
    try {
      return await backend.pushSong(song, create: create);
    } on BackendException catch (e) {
      if (!create || e.kind != BackendErrorKind.server) rethrow;
      final existing = await backend.fetchSong(song.id);
      if (existing == null) rethrow;
      return backend.pushSong(
        RemoteSong(
          id: song.id,
          organizationId: song.organizationId,
          title: song.title,
          chordpro: song.chordpro,
          revision: existing.revision,
          deleted: song.deleted,
        ),
        create: false,
      );
    }
  }

  Future<_Push> _pushSet(OutboxEntry entry) async {
    final set = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(entry.recordId))).getSingleOrNull();
    if (set == null || set.bandId == localBandId) {
      await _done(entry);
      return _Push.skipped;
    }
    final create = set.revision == 0;
    if (create && set.deleted) {
      await _done(entry);
      return _Push.skipped;
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
      items: [for (final i in items) setItemJson(i)],
      revision: set.revision,
      deleted: set.deleted,
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
          SetlistsCompanion(revision: Value(stored.revision)),
        );
        await _done(entry);
      });
      return _Push.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        debugPrint('Set ${set.id} not pushed: not allowed');
        await _done(entry);
        return _Push.skipped;
      }
      rethrow;
    }
  }

  Future<_Push> _pushAttachment(OutboxEntry entry) async {
    final storage = this.storage;
    final row = await (db.select(db.attachments).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
    ])..where(db.attachments.id.equals(entry.recordId))).getSingleOrNull();
    if (row == null || storage == null) {
      if (row == null) await _done(entry);
      return _Push.skipped;
    }
    final a = row.readTable(db.attachments);
    final song = row.readTable(db.songs);
    if (song.libraryId == localBandId || !isPdfFile(a.fileName)) {
      await _done(entry);
      return _Push.skipped;
    }
    final create = a.revision == 0;
    if (create && a.deleted) {
      await _done(entry);
      return _Push.skipped;
    }
    // The song must be on the server first (pushed in this run or before).
    if (song.revision == 0) return _Push.skipped;
    List<int>? bytes;
    if (create) {
      if (!await storage.exists(a.fileName)) {
        await _done(entry);
        return _Push.skipped;
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
        await _done(entry);
      });
      return _Push.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.network ||
          e.kind == BackendErrorKind.signedOut) {
        rethrow;
      }
      // Not allowed, too large or refused: the attachment stays local.
      debugPrint('Attachment ${a.id} not pushed: $e');
      await _done(entry);
      return _Push.skipped;
    }
  }

  /// The JSON form of a set item on the server (ADR-0015).
  static Map<String, dynamic> setItemJson(SetItemEntry i) => {
    'id': i.id,
    'type': i.type.name,
    if (i.songId != null) 'song': i.songId,
    if (i.transpose != 0) 'transpose': i.transpose,
    if (i.sequence != null) 'sequence': i.sequence,
    if (i.note != null) 'note': i.note,
  };

  // Conflicts ---------------------------------------------------------------------

  Future<SongConflict?> _conflict(String songId) => (db.select(
    db.songConflicts,
  )..where((c) => c.songId.equals(songId))).getSingleOrNull();

  /// Keeps the local version: it is pushed on top of the server version.
  Future<void> keepLocal(String songId) => db.transaction(() async {
    final conflict = await _conflict(songId);
    if (conflict == null) return;
    await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(revision: Value(conflict.revision)),
    );
    await (db.delete(
      db.songConflicts,
    )..where((c) => c.songId.equals(songId))).go();
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingle();
    await markDirty(db, SyncCollection.songs, songId, scope: song.libraryId);
  });

  /// Takes the server version and drops the local change.
  Future<void> takeServer(String songId) => db.transaction(() async {
    final conflict = await _conflict(songId);
    if (conflict == null) return;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingle();
    await writeSong(
      RemoteSong(
        id: songId,
        organizationId: song.libraryId,
        title: conflict.title,
        chordpro: conflict.chordproSource,
        revision: conflict.revision,
        deleted: conflict.deleted,
      ),
    );
    await (db.delete(
      db.songConflicts,
    )..where((c) => c.songId.equals(songId))).go();
    await (db.delete(db.syncOutbox)..where(
          (o) =>
              o.collection.equals(SyncCollection.songs) &
              o.recordId.equals(songId),
        ))
        .go();
  });

  /// Saves the local version as a new song in the same library and takes
  /// the server version for the original. Returns the copy's ID.
  Future<String?> keepBoth(String songId) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null || copies == null) return null;
    final copy = (await copies!.copySongs([songId], song.libraryId)).single;
    await takeServer(songId);
    return copy;
  }

  /// Debug description of the pending outbox (tests, logs).
  Future<String> describeOutbox() async => jsonEncode([
    for (final o in await db.select(db.syncOutbox).get())
      '${o.collection}/${o.recordId}@${o.version}',
  ]);
}

enum _Push { done, skipped, conflict }
