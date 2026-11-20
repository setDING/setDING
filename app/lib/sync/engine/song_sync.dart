import 'package:drift/drift.dart';

import '../../data/band_copy.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../data/song_repository.dart' show SongMeta, songMetas;
import '../../util/log.dart';
import '../sync_backend.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of songs (ADR-0004): delta pull per organization, push with the
/// base revision, and conflicts the user resolves.
class SongSync {
  SongSync(this.db, this.backend, this.store, {this.copies});

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Used to keep both versions of a conflicting song.
  final BandCopyService? copies;

  /// Returns (pulled, new conflicts).
  Future<(int, int)> pull(String orgId) async {
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
            sequence: Value(meta.sequence),
            tempo: Value(meta.tempo),
            sortTitle: Value(meta.sortTitle),
            sortArtist: Value(meta.sortArtist),
            tags: Value(meta.tagsColumn),
            searchText: Value(meta.searchText),
            chordproProblems: Value(meta.problems),
            revision: Value(remote.revision),
            updatedAt: DateTime.now(),
            deleted: Value(remote.deleted),
            deletedAt: Value(remote.deletedAt),
            purged: Value(remote.purged),
            createdBy: Value(remote.createdBy),
            updatedBy: Value(remote.updatedBy),
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
    );
    try {
      final stored = await _pushSongOrRecover(remote, create: create);
      await db.transaction(() async {
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(
            revision: Value(stored.revision),
            createdBy: Value(stored.createdBy),
            updatedBy: Value(stored.updatedBy),
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
