import 'package:drift/drift.dart';

import '../../data/band_copy.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../data/song_repository.dart' show SongMeta, songMetas;
import '../../util/log.dart';
import '../sync_backend.dart';
import 'change_recorder.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of songs (ADR-0004): delta pull per organization, push with the
/// base revision, and conflicts the user resolves.
///
/// The language version group and the language (ADR-0053) are last writer
/// wins per field: they are pushed on their own ([pushLink]), a pulled value
/// never replaces one still waiting in the outbox, and a server change of
/// only them is never a conflict. The review status (ADR-0060) works the
/// same way, as one outbox entry per song ([pushReview]).
class SongSync {
  SongSync(this.db, this.backend, this.store, {this.copies, this.changes});

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Used to keep both versions of a conflicting song.
  final BandCopyService? copies;

  /// Records changes of other people (ADR-0045).
  final ChangeRecorder? changes;

  /// Changes by others than [logChangesFor] (the signed-in user) are
  /// recorded in the change log (ADR-0045); null records nothing, e.g. on
  /// the first sync of the library or band.
  /// Returns (pulled, new conflicts).
  Future<(int, int)> pull(String orgId, {String? logChangesFor}) async {
    final since = await store.cursor(orgId, SyncCollection.songs);
    final remote = await backend.pullSongs(orgId, since);
    if (remote.isEmpty) return (0, 0);
    final metas = await songMetas([for (final s in remote) s.chordpro]);
    var conflicts = 0;
    await db.transaction(() async {
      final ids = [for (final s in remote) s.id];
      final locals = await SyncStore.byId(
        ids,
        (chunk) => (db.select(db.songs)..where((s) => s.id.isIn(chunk))).get(),
        (s) => s.id,
      );
      final dirty = await store.dirty(SyncCollection.songs, ids);
      final pendingLinks = {
        ...await store.dirty(SyncCollection.songLinks, [
          for (final id in ids)
            for (final f in SongLinkField.values)
              songLinkRecordId(id, f.serverName),
        ]),
        for (final id in await store.dirty(SyncCollection.songReview, ids))
          _reviewKey(id),
      };
      final known = (await SyncStore.byId(
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
          pendingLinks: pendingLinks,
          log: ChangeRecorder.records(song.updatedBy, logChangesFor),
        )) {
          conflicts++;
        }
      }
      if (remote.isNotEmpty) {
        await store.setCursor(
          orgId,
          SyncCollection.songs,
          remote.last.revision,
        );
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
    Set<String> pendingLinks = const {},
    bool log = false,
  }) async {
    final created = remote.created;
    if (local != null && local.createdAt == null && created != null) {
      // Pulled again after schema 33 for the creation date (#868).
      await (db.update(db.songs)..where((s) => s.id.equals(remote.id))).write(
        SongsCompanion(createdAt: Value(created)),
      );
    }
    if (local != null && remote.revision <= local.revision) return false;
    if (local != null &&
        dirty &&
        remote.effectiveContentRevision <= local.revision) {
      // Only the link fields changed on the server (ADR-0053): no conflict,
      // the local change is pushed on top of the new revision.
      await (db.update(db.songs)..where((s) => s.id.equals(remote.id))).write(
        SongsCompanion(revision: Value(remote.revision)),
      );
      await _writeLinks(remote, pendingLinks);
      return false;
    }
    if (local != null && dirty) {
      // The link fields are not part of the conflict.
      await _writeLinks(remote, pendingLinks);
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
    if (log) await changes?.song(local, remote, meta.title ?? remote.title);
    await writeSong(remote, meta: meta);
    await _writeLinks(remote, pendingLinks);
    return false;
  }

  /// Key of a pending review status in the set of pending link fields.
  static String _reviewKey(String songId) => '$songId:review';

  /// Stores the link fields (ADR-0053) and the review status (ADR-0060) of
  /// a server song, except those with a local change still in the outbox
  /// ([pendingLinks]): that one wins.
  Future<void> _writeLinks(RemoteSong remote, Set<String> pendingLinks) async {
    bool pending(SongLinkField f) =>
        pendingLinks.contains(songLinkRecordId(remote.id, f.serverName));
    final review = !pendingLinks.contains(_reviewKey(remote.id));
    await (db.update(db.songs)..where((s) => s.id.equals(remote.id))).write(
      SongsCompanion(
        workId: pending(SongLinkField.workId)
            ? const Value.absent()
            : Value(remote.workId),
        language: pending(SongLinkField.language)
            ? const Value.absent()
            : Value(remote.language),
        reviewState: review ? Value(remote.reviewState) : const Value.absent(),
        reviewReason: review
            ? Value(remote.reviewReason)
            : const Value.absent(),
        reviewedBy: review ? Value(remote.reviewedBy) : const Value.absent(),
        reviewedAt: review ? Value(remote.reviewedAt) : const Value.absent(),
      ),
    );
  }

  /// Stores the server state of a song locally (no outbox entry); [meta]
  /// is extracted from its source unless given. The link fields stay as
  /// they are (see [_writeLinks]).
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
            sequence: Value(meta.sequence),
            tempo: Value(meta.tempo),
            sortTitle: Value(meta.sortTitle),
            sortArtist: Value(meta.sortArtist),
            tags: Value(meta.tagsColumn),
            searchText: Value(meta.searchText),
            chordproProblems: Value(meta.problems),
            chordproConversions: Value(meta.conversions),
            detectedLanguage: Value(meta.language),
            revision: Value(remote.revision),
            updatedAt: DateTime.now(),
            deleted: Value(remote.deleted),
            deletedAt: Value(remote.deletedAt),
            purged: Value(remote.purged),
            createdBy: Value(remote.createdBy),
            updatedBy: Value(remote.updatedBy),
            // Kept when the server's date is unknown, e.g. taking the
            // server version of a conflict.
            createdAt: Value.absentIfNull(remote.created),
          ),
        );
    if (remote.deleted) {
      await (db.delete(
        db.setItems,
      )..where((i) => i.songId.equals(remote.id))).go();
    }
  }

  Future<PushResult> push(OutboxEntry entry) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(entry.recordId))).getSingleOrNull();
    final hasConflict =
        await (db.select(
          db.songConflicts,
        )..where((c) => c.songId.equals(entry.recordId))).getSingleOrNull() !=
        null;
    if (song == null || song.libraryId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    if (hasConflict) return PushResult.skipped; // waits for the user
    final create = song.revision == 0;
    if (create && song.deleted) {
      await store.done(entry); // created and deleted before it ever synced
      return PushResult.skipped;
    }
    final remote = RemoteSong(
      id: song.id,
      organizationId: song.libraryId,
      title: song.title,
      chordpro: song.chordproSource,
      revision: song.revision,
      deleted: song.deleted,
      deletedAt: song.deletedAt,
      purged: song.purged,
      // Sent on create only (ADR-0053, ADR-0060).
      workId: song.workId,
      language: song.language,
      reviewState: song.reviewState,
      reviewReason: song.reviewReason,
    );
    try {
      final stored = await _pushSongOrRecover(remote, create: create);
      await db.transaction(() async {
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(
            revision: Value(stored.revision),
            createdBy: Value(stored.createdBy),
            updatedBy: Value(stored.updatedBy),
            createdAt: Value.absentIfNull(stored.created),
            // Who set the review status, as the server recorded it.
            reviewedBy: create
                ? Value(stored.reviewedBy)
                : const Value.absent(),
            reviewedAt: create
                ? Value(stored.reviewedAt)
                : const Value.absent(),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
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
        return PushResult.conflict;
      }
      if (e.kind == BackendErrorKind.notAllowed) {
        // No (longer) permission: the change stays local.
        _log.warning('Song ${song.id} not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
      }
      rethrow;
    }
  }

  /// Pushes one link field of a song (ADR-0053): last writer wins, no base
  /// revision. Waits until the song itself is on the server.
  Future<PushResult> pushLink(OutboxEntry entry) async {
    final (songId, name) = parseSongLinkRecordId(entry.recordId);
    final field = SongLinkField.values
        .where((f) => f.serverName == name)
        .firstOrNull;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (field == null || song == null || song.libraryId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    if (song.revision == 0) {
      if (song.deleted) await store.done(entry); // never synced
      return PushResult.skipped; // sent with the song's create
    }
    try {
      final stored = await backend.pushSongLink(
        songId,
        field,
        field == SongLinkField.workId ? song.workId : song.language,
      );
      await db.transaction(() async {
        final current = await (db.select(
          db.songs,
        )..where((s) => s.id.equals(songId))).getSingle();
        final conflict = await _conflict(songId);
        // The new revision is the base of later changes as long as the
        // content on the server is the one this device knows.
        if (conflict == null &&
            stored.effectiveContentRevision <= current.revision) {
          await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
            SongsCompanion(revision: Value(stored.revision)),
          );
        }
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        // No (longer) permission: the change stays local.
        _log.warning('Link of song $songId not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
      }
      rethrow;
    }
  }

  /// Pushes the review status of a song (ADR-0060): last writer wins, no
  /// base revision. Waits until the song itself is on the server.
  Future<PushResult> pushReview(OutboxEntry entry) async {
    final songId = entry.recordId;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null || song.libraryId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    if (song.revision == 0) {
      if (song.deleted) await store.done(entry); // never synced
      return PushResult.skipped; // sent with the song's create
    }
    try {
      final stored = await backend.pushSongReview(
        songId,
        song.reviewState,
        song.reviewReason,
      );
      await db.transaction(() async {
        final current = await (db.select(
          db.songs,
        )..where((s) => s.id.equals(songId))).getSingle();
        final conflict = await _conflict(songId);
        await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
          SongsCompanion(
            // As for link fields: the new revision is the base of later
            // changes while the content is the one this device knows.
            revision:
                conflict == null &&
                    stored.effectiveContentRevision <= current.revision
                ? Value(stored.revision)
                : const Value.absent(),
            reviewedBy: Value(stored.reviewedBy),
            reviewedAt: Value(stored.reviewedAt),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        // No (longer) permission: the change stays local.
        _log.warning('Review of song $songId not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
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
          deletedAt: song.deletedAt,
          purged: song.purged,
        ),
        create: false,
      );
    }
  }

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
}
