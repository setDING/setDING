import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/song_repository.dart' show adoptLocalOverlays;
import '../providers.dart'
    show
        attachmentStorageProvider,
        bandServiceProvider,
        databaseProvider,
        selectedBandIdProvider,
        selectedLibraryIdProvider,
        webClientProvider;
import '../settings/settings.dart';
import 'pocketbase_backend.dart';
import 'session_store.dart';
import 'sync_controller.dart' show SyncController, autoSyncProvider;
import 'sync_backend.dart';
import '../util/log.dart';

const _log = Log('auth');

/// Where the session is stored; overridden in main() and in tests.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// The backend for the configured server. Changing the server URL creates a
/// new backend; a session belongs to one server.
final syncBackendProvider = Provider<SyncBackend>((ref) {
  final backend = PocketBaseBackend(
    serverUrl: ref.watch(serverUrlProvider),
    store: ref.watch(sessionStoreProvider),
  );
  ref.onDispose(backend.dispose);
  return backend;
});

/// Registration settings of the configured server (ADR-0024); assumes an
/// open server if it cannot be asked (offline, older server), since the
/// server enforces its own settings anyway.
final serverConfigProvider = FutureProvider<ServerConfig>((ref) async {
  final backend = ref.watch(syncBackendProvider);
  try {
    return await backend.fetchServerConfig();
  } on BackendException catch (e) {
    _log.info('Server settings not available: $e');
    return ServerConfig.unknown;
  }
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
      final signedOut = state != null && user == null;
      state = user;
      if (signedOut) _clearWebData();
      if (signedIn) _adoptOverlays(user.id);
      if (signedIn) _ensureSettings(user.id);
      if (signedIn && !_syncRefreshesBands) _refreshBands();
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(() async {
      // Data of an earlier session whose tab was closed (web only).
      if (backend.currentUser == null) await _clearWebData();
      if (backend.currentUser case final user?) {
        await _adoptOverlays(user.id);
        await _ensureSettings(user.id);
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
  ///
  /// The sync mode is a device setting, read from the stored device
  /// settings: [settingsProvider] depends on the signed-in user.
  bool get _syncRefreshesBands =>
      ref.read(autoSyncProvider) &&
      AppSettings.fromJson(
            AppSettings.readPrefs(ref.read(sharedPreferencesProvider), const [
              'syncMode',
            ]),
          ).syncMode !=
          SyncMode.manual;

  static const _adoptedKey = 'overlaysAdopted';

  /// The first user signed in on this device after the upgrade to schema 8
  /// takes over the existing personal adjustments (ADR-0020), once.
  Future<void> _adoptOverlays(String userId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_adoptedKey) ?? false) return;
    await prefs.setBool(_adoptedKey, true);
    final count = await adoptLocalOverlays(ref.read(databaseProvider), userId);
    if (count > 0) _log.info('Took over $count personal adjustments');
  }

  /// Personal settings of [userId] on this device (ADR-0027): at the first
  /// sign-in a copy of the signed-out settings, until the sync brings the
  /// person's settings from the server.
  Future<void> _ensureSettings(String userId) =>
      ref.read(userSettingsStoreProvider).ensure(userId);

  /// The web client keeps local data only while signed in (ADR-0018): it
  /// may run on a shared computer, and browsers may evict storage anyway.
  Future<void> _clearWebData() async {
    if (!ref.read(webClientProvider)) return;
    try {
      await ref.read(databaseProvider).clearAll();
      await ref.read(userSettingsStoreProvider).reload();
      await ref.read(attachmentStorageProvider).deleteAll();
      await ref.read(selectedBandIdProvider.notifier).reset();
      await ref.read(selectedLibraryIdProvider.notifier).reset();
    } catch (e) {
      _log.error('Could not delete the local data', e);
    }
  }

  Future<void> _refreshBands() async {
    try {
      await ref.read(bandServiceProvider).refresh();
    } catch (e) {
      // Offline or server error: the cached bands stay available.
      _log.warning('Could not refresh bands', e);
    }
  }

  Future<void> signOut() => ref.read(syncBackendProvider).signOut();
}

final authProvider = NotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
