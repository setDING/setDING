import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/song_repository.dart' show adoptLocalOverlays;
import '../providers.dart' show bandServiceProvider, databaseProvider;
import '../settings/settings.dart';
import 'pocketbase_backend.dart';
import 'session_store.dart';
import 'sync_controller.dart' show SyncController, autoSyncProvider;
import 'sync_backend.dart';

/// Where the session is stored; overridden in main() and in tests.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// The backend for the configured server. Changing the server URL creates a
/// new backend; a session belongs to one server.
final syncBackendProvider = Provider<SyncBackend>((ref) {
  final backend = PocketBaseBackend(
    serverUrl: ref.watch(settingsProvider.select((s) => s.serverUrl)),
    store: ref.watch(sessionStoreProvider),
  );
  ref.onDispose(backend.dispose);
  return backend;
});

/// The signed-in user, or null. Refreshes a stored session once when the
/// backend is created (ignored while offline) and loads the user's bands
/// after signing in or starting signed in.
class AuthNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final backend = ref.watch(syncBackendProvider);
    final subscription = backend.userChanges.listen((user) {
      final signedIn = state == null && user != null;
      state = user;
      if (signedIn) _adoptOverlays(user.id);
      if (signedIn && !_syncRefreshesBands) _refreshBands();
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(() async {
      if (backend.currentUser case final user?) {
        await _adoptOverlays(user.id);
      }
      await backend.refreshSession();
      if (backend.currentUser != null && !_syncRefreshesBands) {
        await _refreshBands();
      }
    });
    return backend.currentUser;
  }

  /// The sync that starts at start and after signing in (unless manual,
  /// see [SyncController]) refreshes the bands itself; refreshing them here
  /// too would load them twice.
  bool get _syncRefreshesBands =>
      ref.read(autoSyncProvider) &&
      ref.read(settingsProvider).syncMode != SyncMode.manual;

  static const _adoptedKey = 'overlaysAdopted';

  /// The first user signed in on this device after the upgrade to schema 8
  /// takes over the existing personal adjustments (ADR-0020), once.
  Future<void> _adoptOverlays(String userId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_adoptedKey) ?? false) return;
    await prefs.setBool(_adoptedKey, true);
    final count = await adoptLocalOverlays(ref.read(databaseProvider), userId);
    if (count > 0) debugPrint('Took over $count personal adjustments');
  }

  Future<void> _refreshBands() async {
    try {
      await ref.read(bandServiceProvider).refresh();
    } catch (e) {
      // Offline or server error: the cached bands stay available.
      debugPrint('Could not refresh bands: $e');
    }
  }

  Future<void> signOut() => ref.read(syncBackendProvider).signOut();
}

final authProvider = NotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
