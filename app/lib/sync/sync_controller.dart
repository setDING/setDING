import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../settings/settings.dart';
import '../data/attachment_storage.dart';
import 'attachment_fetcher.dart';
import 'auth_providers.dart';
import 'sync_backend.dart' show BackendErrorKind, RegistrationMode;
import 'sync_engine.dart';

/// Whether syncs start automatically; widget tests turn it off and sync
/// explicitly.
final autoSyncProvider = Provider<bool>((ref) => true);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(syncBackendProvider),
    ref.watch(bandServiceProvider),
    copies: ref.watch(bandCopyProvider),
    storage: ref.watch(attachmentStorageProvider),
    preloadAttachments: !ref.watch(webClientProvider),
    settings: ref.watch(userSettingsStoreProvider),
  ),
);

/// Loads attachment files when they are opened (web client, ADR-0018).
final attachmentFetcherProvider = Provider<AttachmentFetcher>(
  (ref) => AttachmentFetcher(
    ref.watch(databaseProvider),
    ref.watch(syncBackendProvider),
    ref.watch(attachmentStorageProvider),
  ),
);

/// The file of an attachment for viewing: the stored file, or on the web
/// client the file downloaded on demand. Null if it is not available (native
/// apps: not downloaded yet, ADR-0009).
final attachmentFileProvider = FutureProvider.autoDispose
    .family<StoredFile?, String>((ref, attachmentId) async {
      if (!ref.watch(webClientProvider)) return null;
      return ref.watch(attachmentFetcherProvider).fetch(attachmentId);
    });

/// State of the sync for the UI.
@immutable
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.lastSync,
    this.lastReport,
    this.afterLive = false,
  });

  final bool running;

  /// End of the last completed run.
  final DateTime? lastSync;
  final SyncReport? lastReport;

  /// [lastReport] is the run that caught up after live mode: its changes
  /// came in during the performance and are summed up once (#691).
  final bool afterLive;

  SyncStatus copyWith({
    bool? running,
    DateTime? lastSync,
    SyncReport? lastReport,
  }) => SyncStatus(
    running: running ?? this.running,
    lastSync: lastSync ?? this.lastSync,
    lastReport: lastReport ?? this.lastReport,
    afterLive: afterLive,
  );
}

/// Starts syncs (ADR-0004) according to the [SyncMode] setting: once after
/// signing in and at start (unless manual); in automatic mode also a few
/// seconds after local changes, on realtime events from the server and
/// every few minutes. Paused while live mode is open, so nothing changes on
/// stage (ADR-0007); a sync requested meanwhile runs afterwards.
class SyncController extends Notifier<SyncStatus> {
  static const localDelay = Duration(seconds: 3);
  static const remoteDelay = Duration(seconds: 1);
  static const interval = Duration(minutes: 5);

  Timer? _debounce;
  int _paused = 0;
  bool _requested = false;

  /// The next run catches up on the syncs requested during live mode.
  bool _catchingUp = false;

  /// Whether the scheduled (or deferred) sync must load the bands first.
  bool _refreshBands = false;

  /// Realtime events that change who sees which band; other events (songs,
  /// sets, attachments, adjustments) sync without loading the bands.
  static const bandCollections = {
    'organizations',
    'org_memberships',
    'bands',
    'memberships',
  };
  final _auto = <void Function()>[];

  @override
  SyncStatus build() {
    final userId = ref.watch(authProvider.select((u) => u?.id));
    ref.onDispose(() {
      _stopAutomatic();
      _debounce?.cancel();
    });
    _userId = userId;
    // The last sync of this person on this device survives a restart, for
    // the stale sync warning (#744).
    final stored = userId == null
        ? null
        : ref.read(sharedPreferencesProvider).getString(_lastSyncKey(userId));
    final initial = SyncStatus(
      lastSync: stored == null ? null : DateTime.tryParse(stored),
    );
    if (userId == null || !ref.watch(autoSyncProvider)) return initial;
    // Read, not watched: changing the mode must not rebuild (and reset)
    // the controller.
    final mode = ref.read(settingsProvider).syncMode;
    ref.listen(
      settingsProvider.select((s) => s.syncMode),
      (_, next) => _applyMode(next),
    );
    _applyMode(mode);
    // At start and after signing in.
    if (mode != SyncMode.manual) Future.microtask(syncNow);
    return initial;
  }

  String? _userId;

  static String _lastSyncKey(String userId) => 'lastSync.$userId';

  void _applyMode(SyncMode mode) {
    _stopAutomatic();
    if (mode != SyncMode.automatic) return;
    final db = ref.read(databaseProvider);
    // New or changed entries only: entries the sync itself removes after
    // pushing must not start the next sync.
    final outbox = db
        .tableUpdates(
          TableUpdateQuery.onTable(
            db.syncOutbox,
            limitUpdateKind: UpdateKind.insert,
          ),
        )
        // Local changes do not change the bands.
        .listen((_) => _schedule(localDelay, refreshBands: false));
    final remote = ref
        .read(syncBackendProvider)
        .watchChanges()
        .listen(
          (collection) => _schedule(
            remoteDelay,
            refreshBands: bandCollections.contains(collection),
          ),
          onError: (Object _) {},
        );
    final periodic = Timer.periodic(interval, (_) => syncNow());
    _auto.addAll([outbox.cancel, remote.cancel, periodic.cancel]);
  }

  void _stopAutomatic() {
    for (final cancel in _auto) {
      cancel();
    }
    _auto.clear();
  }

  void _schedule(Duration delay, {bool refreshBands = true}) {
    _refreshBands |= refreshBands;
    _debounce?.cancel();
    _debounce = Timer(delay, () => syncNow(refreshBands: _refreshBands));
  }

  /// Runs a sync now (or after live mode); returns null when deferred.
  /// [refreshBands] false skips loading the bands (see [SyncEngine.sync]).
  Future<SyncReport?> syncNow({bool refreshBands = true}) async {
    if (_paused > 0) {
      _requested = true;
      _refreshBands |= refreshBands;
      return null;
    }
    _requested = false;
    final afterLive = _catchingUp;
    _catchingUp = false;
    final bands = refreshBands || _refreshBands;
    _refreshBands = false;
    state = state.copyWith(running: true);
    final report = await ref.read(syncEngineProvider).sync(refreshBands: bands);
    if (!ref.mounted) return report;
    if (report.error == BackendErrorKind.updateRequired) {
      // Nothing works with this server until the app is updated
      // (ADR-0029): no automatic retries until the next start; the server
      // config tells the UI which version is needed.
      _stopAutomatic();
      _debounce?.cancel();
      ref.invalidate(serverConfigProvider);
    }
    if (report.error == null &&
        ref.read(serverConfigProvider).value?.registration ==
            RegistrationMode.unknown) {
      // The server is reachable again: read the registration mode that could
      // not be read before (issue #829).
      ref.invalidate(serverConfigProvider);
    }
    final lastSync = report.error == null ? DateTime.now() : state.lastSync;
    final userId = _userId;
    if (report.error == null && userId != null) {
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setString(_lastSyncKey(userId), lastSync!.toIso8601String()),
      );
    }
    state = SyncStatus(
      lastSync: lastSync,
      lastReport: report,
      afterLive: afterLive,
    );
    return report;
  }

  /// Live mode opened.
  void pause() => _paused++;

  /// Live mode closed: catch up on requested syncs.
  void resume() {
    if (_paused > 0) _paused--;
    if (_paused == 0 && _requested) {
      _catchingUp = true;
      _schedule(remoteDelay, refreshBands: _refreshBands);
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Number of local changes not yet on the server.
final pendingChangesProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final count = db.syncOutbox.recordId.count();
  return (db.selectOnly(
    db.syncOutbox,
  )..addColumns([count])).watchSingle().map((r) => r.read(count) ?? 0);
});

/// The last successful sync is older than this: the sets on this device may
/// not be up to date (ADR-0001, #744).
const syncStaleAfter = Duration(hours: 24);

/// Why the data on this device may not be up to date, for the warning
/// above the sets (#744).
@immutable
class SyncStaleness {
  const SyncStaleness({
    required this.lastSync,
    required this.stale,
    required this.unsent,
  });

  /// The last successful sync; null if there was none on this device.
  final DateTime? lastSync;

  /// The last successful sync is missing or older than [syncStaleAfter].
  final bool stale;

  /// Local changes not on the server because the last sync failed.
  final int unsent;
}

/// The stale sync warning, or null when the data is up to date (or nothing
/// is synced: signed out, or the web client, ADR-0018). [syncClockProvider]
/// gives the time.
final syncStalenessProvider = Provider<SyncStaleness?>((ref) {
  if (ref.watch(webClientProvider)) return null;
  if (ref.watch(authProvider) == null) return null;
  final status = ref.watch(syncControllerProvider);
  if (status.running) return null;
  final pending = ref.watch(pendingChangesProvider).value ?? 0;
  final last = status.lastSync;
  final stale =
      last == null ||
      ref.watch(syncClockProvider)().difference(last) > syncStaleAfter;
  final unsent = status.lastReport?.error != null ? pending : 0;
  if (!stale && unsent == 0) return null;
  return SyncStaleness(lastSync: last, stale: stale, unsent: unsent);
});

/// The current time for [syncStalenessProvider]; tests override it.
final syncClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Synced attachment files that are not downloaded yet (ADR-0009).
final missingFilesProvider = StreamProvider<int>((ref) async* {
  // The web client loads files when opened (ADR-0018): none are "missing".
  if (ref.watch(webClientProvider)) {
    yield 0;
    return;
  }
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(attachmentStorageProvider);
  Future<int> count() async {
    final rows = await (db.select(
      db.attachments,
    )..where((a) => a.deleted.equals(false) & a.remoteFile.isNotNull())).get();
    // Synchronous checks: a few local files, and no async I/O per row.
    return rows.where((a) => !storage.file(a.fileName).existsSync()).length;
  }

  yield await count();
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onTable(db.attachments),
  )) {
    yield await count();
  }
});

/// Songs changed here and on the server (ADR-0004).
final conflictsProvider = StreamProvider<List<SongConflict>>(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).songConflicts)
      .watch(),
);

/// The conflict of one song, or null.
final songConflictProvider = StreamProvider.autoDispose
    .family<SongConflict?, String>((ref, songId) {
      final db = ref.watch(databaseProvider);
      return (db.select(
        db.songConflicts,
      )..where((c) => c.songId.equals(songId))).watchSingleOrNull();
    });
