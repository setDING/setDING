import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// backend is created (ignored while offline).
class AuthNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final backend = ref.watch(syncBackendProvider);
    final subscription = backend.userChanges.listen((user) => state = user);
    ref.onDispose(subscription.cancel);
    Future.microtask(backend.refreshSession);
    return backend.currentUser;
  }

  Future<void> signOut() => ref.read(syncBackendProvider).signOut();
}

final authProvider = NotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
