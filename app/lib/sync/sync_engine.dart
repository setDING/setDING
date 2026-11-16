import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/attachment_storage.dart';
import '../data/band_copy.dart';
import '../data/band_view.dart';
import '../data/database.dart';
import '../data/outbox.dart';
import '../data/song_repository.dart' show SongMeta;
import 'band_service.dart';
import 'engine/attachment_sync.dart';
import 'engine/overlay_sync.dart';
import 'engine/set_sync.dart';
import 'engine/song_sync.dart';
import 'engine/sync_store.dart';
import 'sync_backend.dart';
import '../util/log.dart';

const _log = Log('sync');

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
  }) : storage = storage ?? copies?.storage {
    final store = SyncStore(db);
    _songs = SongSync(db, backend, store, copies: copies);
    _sets = SetSync(db, backend, store);
    _attachments = AttachmentSync(db, backend, store, this.storage);
    _overlays = OverlaySync(db, backend, store);
  }

  final AppDatabase db;

  /// Where attachment files are stored (ADR-0009); without it, attachment
  /// files are neither uploaded nor downloaded.
  final AttachmentStorage? storage;
  final SyncBackend backend;
  final BandService bands;

  /// Used to keep both versions of a conflicting song.
  final BandCopyService? copies;

  late final SongSync _songs;
  late final SetSync _sets;
  late final AttachmentSync _attachments;
  late final OverlaySync _overlays;

  Future<SyncReport>? _running;

  /// Runs a sync; concurrent calls share the running one.
  ///
  /// [refreshBands] false skips loading the organizations and bands first,
  /// e.g. for a realtime event about a song or set (ADR-0004): the bands
  /// stored on this device are used.
  Future<SyncReport> sync({bool refreshBands = true}) =>
      _running ??= _sync(refreshBands: refreshBands)
          .whenComplete(() => _running = null);

  Future<SyncReport> _sync({required bool refreshBands}) async {
    final user = backend.currentUser;
    if (user == null) return const SyncReport();
    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;
    var downloaded = 0;
    try {
      if (refreshBands) await bands.refresh();
      final visible = [
        for (final b in await bands.watchBands(user.id).first)
          if (!b.isLocal) b,
      ];
      final orgIds = {for (final b in visible) b.organizationId!};
      final orgs = await bands.watchOrganizations(user.id).first;
      orgIds.addAll(orgs.map((o) => o.id));

      for (final org in orgIds) {
        final r = await _songs.pull(org);
        pulled += r.$1;
        conflicts += r.$2;
        pulled += await _attachments.pull(org);
      }
      for (final band in visible) {
        pulled += await _sets.pull(band);
      }
      // After the songs: an overlay needs its song on this device.
      pulled += await _overlays.pull(user.id);
      await _enqueueUnsynced(visible, userId: user.id, orgIds: orgIds);
      final p = await _push(user.id);
      pushed += p.$1;
      conflicts += p.$2;
      downloaded += await _attachments.downloadMissing();
      _log.info(
        'Sync done: pulled $pulled, pushed $pushed, conflicts $conflicts, '
        'downloaded $downloaded',
      );
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
      );
    } on BackendException catch (e) {
      _log.warning('Sync stopped', e);
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
        error: e.kind,
      );
    }
  }

  // Push -------------------------------------------------------------------------

  /// Adds records that never reached the server (revision 0) to the outbox,
  /// e.g. songs copied into an organization before the outbox existed
  /// (app schema < 5). Only records the user may push are added, so a
  /// rejected change is not retried on every sync.
  Future<void> _enqueueUnsynced(
    List<BandView> bands, {
    required String userId,
    required Set<String> orgIds,
  }) async {
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
    if (orgIds.isNotEmpty) {
      // Personal adjustments of this user, e.g. taken over after the
      // upgrade (ADR-0020); any member may sync their own.
      final libs = orgIds.toList();
      await enqueue(
        SyncCollection.overlays,
        "SELECT o.owner_id || ':' || o.song_id AS id FROM personal_overlays o "
        'JOIN songs s ON s.id = o.song_id '
        'WHERE o.revision = 0 AND o.owner_id = ? AND s.deleted = 0 '
        'AND s.library_id IN (${placeholders(libs.length)})',
        [userId, ...libs],
      );
    }
    if (added > 0) {
      db.notifyUpdates({
        TableUpdate.onTable(db.syncOutbox, kind: UpdateKind.insert),
      });
    }
  }

  /// Returns (pushed, new conflicts).
  Future<(int, int)> _push(String userId) async {
    var pushed = 0;
    var conflicts = 0;
    // Songs first: attachments and overlays need their song on the server.
    const order = [
      SyncCollection.songs,
      SyncCollection.setlists,
      SyncCollection.attachments,
      SyncCollection.overlays,
    ];
    final entries = await db.select(db.syncOutbox).get()
      ..sort(
        (a, b) =>
            order.indexOf(a.collection).compareTo(order.indexOf(b.collection)),
      );
    for (final entry in entries) {
      switch (entry.collection) {
        case SyncCollection.songs:
          final r = await _songs.push(entry);
          if (r == PushResult.done) pushed++;
          if (r == PushResult.conflict) conflicts++;
        case SyncCollection.setlists:
          if (await _sets.push(entry) == PushResult.done) pushed++;
        case SyncCollection.attachments:
          if (await _attachments.push(entry) == PushResult.done) pushed++;
        case SyncCollection.overlays:
          if (await _overlays.push(entry, userId) == PushResult.done) {
            pushed++;
          }
      }
    }
    return (pushed, conflicts);
  }

  // Songs: storing server versions and resolving conflicts -------------------

  /// Stores the server state of a song locally (no outbox entry).
  Future<void> writeSong(RemoteSong remote, {SongMeta? meta}) =>
      _songs.writeSong(remote, meta: meta);

  /// Keeps the local version: it is pushed on top of the server version.
  Future<void> keepLocal(String songId) => _songs.keepLocal(songId);

  /// Takes the server version and drops the local change.
  Future<void> takeServer(String songId) => _songs.takeServer(songId);

  /// Saves the local version as a new song and takes the server version for
  /// the original. Returns the copy's ID.
  Future<String?> keepBoth(String songId) => _songs.keepBoth(songId);

  // Constants of the parts, for tests and callers -----------------------------

  /// Attachment files downloaded at the same time.
  static const parallelDownloads = AttachmentSync.parallelDownloads;

  /// Server record ID of the adjustments of [userId] for [songId].
  static String overlayServerId(String userId, String songId) =>
      OverlaySync.overlayServerId(userId, songId);

  /// The fields of layer 3 as stored on the server.
  static Map<String, dynamic> overlayData(SongOverlay o) =>
      OverlaySync.overlayData(o);

  /// Debug description of the pending outbox (tests, logs).
  Future<String> describeOutbox() async => jsonEncode([
    for (final o in await db.select(db.syncOutbox).get())
      '${o.collection}/${o.recordId}@${o.version}',
  ]);
}
