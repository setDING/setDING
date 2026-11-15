import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/band_copy.dart';
import '../data/band_view.dart';
import '../data/database.dart';
import '../data/outbox.dart';
import '../data/song_repository.dart' show SongMeta;
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
    this.error,
  });

  final int pulled;
  final int pushed;

  /// New conflicts detected in this run.
  final int conflicts;

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
  SyncEngine(this.db, this.backend, this.bands, {this.copies});

  final AppDatabase db;
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
      }
      for (final band in visible) {
        pulled += await _pullSets(band);
      }
      final p = await _push();
      pushed += p.$1;
      conflicts += p.$2;
      return SyncReport(pulled: pulled, pushed: pushed, conflicts: conflicts);
    } on BackendException catch (e) {
      debugPrint('Sync stopped: $e');
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
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

  Future<OutboxEntry?> _outbox(String collection, String id) =>
      (db.select(db.syncOutbox)..where(
            (o) => o.collection.equals(collection) & o.recordId.equals(id),
          ))
          .getSingleOrNull();

  /// Returns (pulled, new conflicts).
  Future<(int, int)> _pullSongs(String orgId) async {
    final since = await _cursor(orgId, SyncCollection.songs);
    final remote = await backend.pullSongs(orgId, since);
    var conflicts = 0;
    await db.transaction(() async {
      for (final song in remote) {
        if (await _applySong(song)) conflicts++;
      }
      if (remote.isNotEmpty) {
        await _setCursor(orgId, SyncCollection.songs, remote.last.revision);
      }
    });
    return (remote.length, conflicts);
  }

  /// Applies a server song; returns true if it became a new conflict.
  Future<bool> _applySong(RemoteSong remote) async {
    final local = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(remote.id))).getSingleOrNull();
    if (local != null && remote.revision <= local.revision) return false;
    final dirty = await _outbox(SyncCollection.songs, remote.id);
    if (local != null && dirty != null) {
      // Changed here and on the server: never overwrite silently.
      final existing = await (db.select(
        db.songConflicts,
      )..where((c) => c.songId.equals(remote.id))).getSingleOrNull();
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
      return existing == null;
    }
    await writeSong(remote);
    return false;
  }

  /// Stores the server state of a song locally (no outbox entry).
  Future<void> writeSong(RemoteSong remote) async {
    final meta = SongMeta.fromSource(remote.chordpro);
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

  Future<int> _pullSets(BandView band) async {
    final since = await _cursor(band.id, SyncCollection.setlists);
    final remote = await backend.pullSets(band.id, since);
    await db.transaction(() async {
      for (final set in remote) {
        await _applySet(set);
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

  Future<void> _applySet(RemoteSet remote) async {
    final local = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(remote.id))).getSingleOrNull();
    if (local != null && remote.revision <= local.revision) return;
    // Last writer wins: a pending local change is pushed afterwards.
    if (local != null &&
        await _outbox(SyncCollection.setlists, remote.id) != null) {
      return;
    }
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
      if (songId != null &&
          await (db.select(
                db.songs,
              )..where((s) => s.id.equals(songId!))).getSingleOrNull() ==
              null) {
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

  /// Returns (pushed, new conflicts).
  Future<(int, int)> _push() async {
    var pushed = 0;
    var conflicts = 0;
    final entries = await db.select(db.syncOutbox).get();
    for (final entry in entries) {
      switch (entry.collection) {
        case SyncCollection.songs:
          final r = await _pushSong(entry);
          if (r == _Push.done) pushed++;
          if (r == _Push.conflict) conflicts++;
        case SyncCollection.setlists:
          if (await _pushSet(entry) == _Push.done) pushed++;
        default:
          // Attachments are pushed by the attachment sync (issue #18).
          continue;
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
      await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
        SongsCompanion(revision: Value(stored.revision)),
      );
      await _done(entry);
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
      await (db.update(db.setlists)..where((s) => s.id.equals(set.id))).write(
        SetlistsCompanion(revision: Value(stored.revision)),
      );
      await _done(entry);
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
