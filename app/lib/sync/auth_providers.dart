import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart' show bandServiceProvider;
import '../settings/settings.dart';
import 'pocketbase_backend.dart';
import 'session_store.dart';
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
      if (signedIn) _refreshBands();
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(() async {
      await backend.refreshSession();
      if (backend.currentUser != null) await _refreshBands();
    });
    return backend.currentUser;
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
