import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/attachment_storage.dart';
import '../data/band_copy.dart';
import '../data/band_view.dart';
import '../data/database.dart';
import '../data/outbox.dart';
import '../data/play_history.dart';
import '../data/song_repository.dart' show SongMeta;
import 'band_service.dart';
import 'engine/arrangement_sync.dart';
import 'engine/change_recorder.dart';
import 'engine/contact_sync.dart';
import 'engine/attachment_sync.dart';
import 'engine/annotation_sync.dart';
import 'engine/overlay_sync.dart';
import 'engine/report_sync.dart';
import 'engine/set_sync.dart';
import 'engine/settings_sync.dart';
import 'engine/song_sync.dart';
import 'engine/substitute_sync.dart';
import 'engine/sync_store.dart';
import 'sync_backend.dart';
import '../settings/user_settings_store.dart';
import '../util/log.dart';

export 'engine/change_recorder.dart' show SyncChange, SyncChangeKind;
export 'engine/attachment_sync.dart' show RefusedUpload;

const _log = Log('sync');

/// Result of one sync run.
@immutable
class SyncReport {
  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.downloaded = 0,
    this.settingsTakenOver = false,
    this.goneBands = const [],
    this.closedOrganizations = const [],
    this.changes = const [],
    this.refusedUploads = const [],
    this.error,
  });

  final int pulled;
  final int pushed;

  /// New conflicts detected in this run.
  final int conflicts;

  /// Attachment files downloaded in this run.
  final int downloaded;

  /// The settings on this device were replaced by the person's settings
  /// from the account (first sign-in on this device, ADR-0027).
  final bool settingsTakenOver;

  /// Names of bands this person could see before this run but no longer
  /// can: deleted (ADR-0044), or the person was removed or left.
  final List<String> goneBands;

  /// Organizations of the person that were closed (ADR-0044).
  final List<ClosedOrganization> closedOrganizations;

  /// Songs and sets someone else changed or deleted, applied in this run
  /// (#691).
  final List<SyncChange> changes;

  /// Attachments the server refused to take in this run (#1225); they stay
  /// on this device only and are not sent again by themselves.
  final List<RefusedUpload> refusedUploads;

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
    this.preloadAttachments = true,
    this.settings,
  }) : storage = storage ?? copies?.storage {
    final store = _store = SyncStore(db);
    _changes = ChangeRecorder(db);
    _songs = SongSync(db, backend, store, copies: copies, changes: _changes);
    _sets = SetSync(db, backend, store, changes: _changes);
    _attachments = AttachmentSync(
      db,
      backend,
      store,
      this.storage,
      changes: _changes,
    );
    _overlays = OverlaySync(db, backend, store);
    _annotations = AnnotationSync(db, backend, store);
    _reports = ReportSync(db, backend, store, this.storage);
    _contacts = ContactSync(db, backend, store);
    _arrangements = ArrangementSync(db, backend, store, changes: _changes);
    _substitutes = SubstituteSync(db, backend, store, _sets);
    if (settings case final settings?) {
      _settings = SettingsSync(db, backend, store, settings);
    }
  }

  /// The personal settings (ADR-0027); without them, they are not synced.
  final UserSettingsStore? settings;
  SettingsSync? _settings;

  final AppDatabase db;

  /// Where attachment files are stored (ADR-0009); without it, attachment
  /// files are neither uploaded nor downloaded.
  final AttachmentStorage? storage;
  final SyncBackend backend;
  final BandService bands;

  /// Whether every sync downloads the missing attachment files, so they are
  /// available offline (ADR-0009). The web client loads them when opened
  /// instead (ADR-0018).
  final bool preloadAttachments;

  /// Used to keep both versions of a conflicting song.
  final BandCopyService? copies;

  late final SyncStore _store;
  late final ChangeRecorder _changes;
  late final SongSync _songs;
  late final SetSync _sets;
  late final AttachmentSync _attachments;
  late final OverlaySync _overlays;
  late final AnnotationSync _annotations;
  late final ReportSync _reports;
  late final ContactSync _contacts;
  late final ArrangementSync _arrangements;
  late final SubstituteSync _substitutes;

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
    var settingsTakenOver = false;
    var gone = const BandChanges();
    try {
      _changes.takeRun(); // left over from a run that stopped early
      _attachments.takeRefused();
      // Recent changes of the overview are kept for 30 days (ADR-0045).
      await _changes.log.prune();
      if (refreshBands) gone = await bands.refresh();
      final visible = [
        for (final b in await bands.watchBands(user.id).first)
          if (!b.isLocal) b,
      ];
      final orgIds = {for (final b in visible) b.organizationId!};
      final orgs = await bands.watchOrganizations(user.id).first;
      orgIds.addAll(orgs.map((o) => o.id));

      // Changes by others for the overview (ADR-0045), not on the first
      // sync of a library or band.
      Future<String?> logFor(String scope, List<String> collections) async =>
          await _store.pulledBefore(scope, collections) ? user.id : null;
      for (final org in orgIds) {
        final log = await logFor(org, const [
          SyncCollection.songs,
          SyncCollection.attachments,
        ]);
        final r = await _songs.pull(org, logChangesFor: log);
        pulled += r.$1;
        conflicts += r.$2;
        pulled += await _attachments.pull(org, logChangesFor: log);
        // After the songs: a report belongs to its song (ADR-0060). Which
        // reports the user reads depends on their roles (#1194).
        pulled += await _reports.pull(
          org,
          userId: user.id,
          seesAll: ReportSync.seesAll(
            orgs.where((o) => o.id == org).firstOrNull?.role,
            [
              for (final b in visible)
                if (b.organizationId == org && !b.substitute) b.role,
            ],
          ),
        );
        // Before the sets, whose lineups name them (ADR-0064).
        pulled += await _contacts.pull(org);
      }
      // Sets of substitute bands come from the lineup route (ADR-0061).
      for (final band in visible.where((b) => !b.substitute)) {
        final log = await logFor(band.id, const [
          SyncCollection.setlists,
          SyncCollection.arrangements,
        ]);
        pulled += await _sets.pull(band, logChangesFor: log);
        // After the songs: an arrangement needs its song on this device.
        pulled += await _arrangements.pull(band, logChangesFor: log);
        // With the band's sets and arrangements on this device: freeze how
        // the songs of the sets whose gig day has come were played
        // (ADR-0046). Pushed below with the other changes.
        if (band.canManageSets) {
          await PlayHistoryRepository(db).freeze(band.id);
        }
      }
      // After the songs: the sets the user plays as a substitute
      // (ADR-0061), replaced as a whole; with the bands refreshed only, so
      // a band the user joined is no substitute band any more.
      if (refreshBands) pulled += await _substitutes.pull();
      // After the songs: an overlay needs its song on this device.
      pulled += await _overlays.pull(user.id);
      pulled += await _annotations.pull(user.id);
      if (_settings case final s?) {
        final (n, takenOver) = await s.pull(user.id);
        pulled += n;
        settingsTakenOver = takenOver;
      }
      // Uploads refused for a full storage, once there is room (ADR-0070).
      for (final org in orgIds) {
        await _attachments.retryWhenRoom(org);
      }
      await _enqueueUnsynced(visible, userId: user.id, orgIds: orgIds);
      final p = await _push(user.id);
      pushed += p.$1;
      conflicts += p.$2;
      // After the push, so this device's frozen plays are included.
      for (final org in orgIds) {
        await _pullOrgPlays(org);
      }
      if (preloadAttachments) {
        downloaded += await _attachments.downloadMissing();
      }
      _log.info(
        'Sync done: pulled $pulled, pushed $pushed, conflicts $conflicts, '
        'downloaded $downloaded',
      );
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
        settingsTakenOver: settingsTakenOver,
        goneBands: gone.goneBands,
        closedOrganizations: gone.closedOrganizations,
        changes: _changes.takeRun(),
        refusedUploads: _attachments.takeRefused(),
      );
    } on BackendException catch (e) {
      _log.warning('Sync stopped', e);
      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        downloaded: downloaded,
        settingsTakenOver: settingsTakenOver,
        goneBands: gone.goneBands,
        closedOrganizations: gone.closedOrganizations,
        changes: _changes.takeRun(),
        refusedUploads: _attachments.takeRefused(),
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
        // Leaders push their own songs; the server checks each one.
        if (b.library.canCreateSongs) b.libraryId,
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
        // Refused by the server: sent again when the person retries (#1225).
        'AND a.upload_refused IS NULL '
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
    // People without an account (ADR-0064), created by set editors of the
    // organization's bands.
    final contactOrgs = {
      for (final b in bands)
        if (b.canManageSets && !b.isLocal) ?b.organizationId,
    };
    if (contactOrgs.isNotEmpty) {
      final ids = contactOrgs.toList();
      await enqueue(
        SyncCollection.contacts,
        'SELECT id FROM contacts WHERE revision = 0 AND deleted = 0 '
        'AND organization_id IN (${placeholders(ids.length)})',
        ids,
      );
    }
    if (setBands.isNotEmpty) {
      // Band arrangements (ADR-0025), maintained by the same people as sets.
      final ids = setBands.toList();
      await enqueue(
        SyncCollection.arrangements,
        "SELECT a.band_id || ':' || a.song_id AS id FROM band_arrangements a "
        'JOIN songs s ON s.id = a.song_id '
        'WHERE a.revision = 0 AND a.deleted = 0 AND s.deleted = 0 '
        'AND a.band_id IN (${placeholders(ids.length)})',
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
      // Mistake reports of this user not on the server (ADR-0060).
      await enqueue(
        SyncCollection.songReports,
        'SELECT r.id FROM song_reports r JOIN songs s ON s.id = r.song_id '
        'WHERE r.revision = 0 AND r.deleted = 0 AND r.author_id = ? '
        'AND s.deleted = 0 '
        'AND r.library_id IN (${placeholders(libs.length)})',
        [userId, ...libs],
      );
      // Freehand annotations of this user not on the server (ADR-0032).
      await enqueue(
        SyncCollection.annotations,
        "SELECT DISTINCT a.owner_id || ':' || a.song_id || ':' || a.target "
        'AS id FROM annotations a JOIN songs s ON s.id = a.song_id '
        'WHERE a.pending > 0 AND a.owner_id = ? AND s.deleted = 0 '
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
      // After its song, which may have to be created first (ADR-0053).
      SyncCollection.songLinks,
      SyncCollection.songReview,
      SyncCollection.songReports,
      // Before the sets, whose lineups name them (ADR-0064).
      SyncCollection.contacts,
      SyncCollection.setlists,
      SyncCollection.attachments,
      SyncCollection.overlays,
      SyncCollection.annotations,
      SyncCollection.arrangements,
      SyncCollection.userSettings,
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
        case SyncCollection.songLinks:
          if (await _songs.pushLink(entry) == PushResult.done) pushed++;
        case SyncCollection.songReview:
          if (await _songs.pushReview(entry) == PushResult.done) pushed++;
        case SyncCollection.songReports:
          if (await _reports.push(entry, userId) == PushResult.done) {
            pushed++;
          }
        case SyncCollection.contacts:
          if (await _contacts.push(entry) == PushResult.done) pushed++;
        case SyncCollection.setlists:
          if (await _sets.push(entry) == PushResult.done) pushed++;
        case SyncCollection.attachments:
          if (await _attachments.push(entry) == PushResult.done) pushed++;
        case SyncCollection.overlays:
          if (await _overlays.push(entry, userId) == PushResult.done) {
            pushed++;
          }
        case SyncCollection.annotations:
          if (await _annotations.push(entry, userId) == PushResult.done) {
            pushed++;
          }
        case SyncCollection.arrangements:
          if (await _arrangements.push(entry) == PushResult.done) pushed++;
        case SyncCollection.userSettings:
          if (await _settings?.push(entry, userId) == PushResult.done) {
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

  /// Stores how often each band of [orgId] played each song (ADR-0046),
  /// replacing what the last sync stored. Without the summary (offline, an
  /// older server) the stored one stays.
  Future<void> _pullOrgPlays(String orgId) async {
    final List<RemoteOrgPlay> plays;
    try {
      plays = await backend.fetchOrgPlays(orgId);
    } on BackendException catch (e) {
      _log.info('Plays of organization $orgId not fetched: ${e.kind.name}');
      return;
    }
    await db.transaction(() async {
      await (db.delete(
        db.orgPlays,
      )..where((p) => p.organizationId.equals(orgId))).go();
      for (final p in plays) {
        await db
            .into(db.orgPlays)
            .insert(
              OrgPlaysCompanion.insert(
                organizationId: orgId,
                songId: p.songId,
                bandId: p.bandId,
                bandName: p.bandName,
                playCount: p.count,
                lastPlayed: p.last,
                playedKey: Value(p.key),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      await _store.setCursor(
        orgId,
        SyncCollection.orgPlays,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    });
  }

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
