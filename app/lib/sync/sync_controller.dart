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
  const SyncStatus({this.running = false, this.lastSync, this.lastReport});

  final bool running;

  /// End of the last completed run.
  final DateTime? lastSync;
  final SyncReport? lastReport;

  SyncStatus copyWith({
    bool? running,
    DateTime? lastSync,
    SyncReport? lastReport,
  }) => SyncStatus(
    running: running ?? this.running,
    lastSync: lastSync ?? this.lastSync,
    lastReport: lastReport ?? this.lastReport,
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
    if (userId == null || !ref.watch(autoSyncProvider)) {
      return const SyncStatus();
    }
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
    return const SyncStatus();
  }

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
    final bands = refreshBands || _refreshBands;
    _refreshBands = false;
    state = state.copyWith(running: true);
    final report = await ref.read(syncEngineProvider).sync(refreshBands: bands);
    if (!ref.mounted) return report;
    state = SyncStatus(
      lastSync: report.error == null ? DateTime.now() : state.lastSync,
      lastReport: report,
    );
    return report;
  }

  /// Live mode opened.
  void pause() => _paused++;

  /// Live mode closed: catch up on requested syncs.
  void resume() {
    if (_paused > 0) _paused--;
    if (_paused == 0 && _requested) {
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
