import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../ui/bands/copy_to_band.dart' show bandCopyProvider;
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
  ),
);

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

/// Starts syncs (ADR-0004): after signing in and at start, a few seconds
/// after local changes, on realtime events from the server and every few
/// minutes. Paused while live mode is open, so nothing changes on stage
/// (ADR-0007); a sync requested meanwhile runs afterwards.
class SyncController extends Notifier<SyncStatus> {
  static const localDelay = Duration(seconds: 3);
  static const remoteDelay = Duration(seconds: 1);
  static const interval = Duration(minutes: 5);

  Timer? _debounce;
  int _paused = 0;
  bool _requested = false;

  @override
  SyncStatus build() {
    final userId = ref.watch(authProvider.select((u) => u?.id));
    if (userId == null || !ref.watch(autoSyncProvider)) {
      return const SyncStatus();
    }
    final db = ref.watch(databaseProvider);
    final backend = ref.watch(syncBackendProvider);

    final outbox = db
        .tableUpdates(TableUpdateQuery.onTable(db.syncOutbox))
        .listen((_) => _schedule(localDelay));
    final remote = backend.watchChanges().listen(
      (_) => _schedule(remoteDelay),
      onError: (Object _) {},
    );
    final periodic = Timer.periodic(interval, (_) => syncNow());
    ref.onDispose(() {
      outbox.cancel();
      remote.cancel();
      periodic.cancel();
      _debounce?.cancel();
    });
    Future.microtask(syncNow);
    return const SyncStatus();
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  /// Runs a sync now (or after live mode); returns null when deferred.
  Future<SyncReport?> syncNow() async {
    if (_paused > 0) {
      _requested = true;
      return null;
    }
    _requested = false;
    state = state.copyWith(running: true);
    final report = await ref.read(syncEngineProvider).sync();
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
    if (_paused == 0 && _requested) _schedule(remoteDelay);
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

/// Songs changed here and on the server (ADR-0004).
final conflictsProvider = StreamProvider<List<SongConflict>>(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).songConflicts)
      .watch(),
);

/// The conflict of one song, or null.
final songConflictProvider = StreamProvider.family<SongConflict?, String>((
  ref,
  songId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.songConflicts,
  )..where((c) => c.songId.equals(songId))).watchSingleOrNull();
});
