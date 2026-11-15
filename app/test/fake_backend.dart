import 'dart:async';

import 'package:realchord/sync/sync_backend.dart';

/// In-memory [SyncBackend] for widget tests.
class FakeSyncBackend implements SyncBackend {
  FakeSyncBackend({this.user, this.serverUrl = defaultServerUrl});

  AuthUser? user;

  @override
  final String serverUrl;

  /// Accounts that can sign in: email → password.
  final accounts = <String, String>{};

  /// When set, every call fails with this error.
  BackendErrorKind? failWith;

  final resetRequests = <String>[];
  int refreshCount = 0;
  final _changes = StreamController<AuthUser?>.broadcast();

  void _check() {
    if (failWith != null) throw BackendException(failWith!);
  }

  void _set(AuthUser? u) {
    user = u;
    _changes.add(u);
  }

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _check();
    if (accounts[email.trim()] != password) {
      throw const BackendException(BackendErrorKind.invalidCredentials);
    }
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: '');
    _set(u);
    return u;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _check();
    if (accounts.containsKey(email.trim())) {
      throw const BackendException(BackendErrorKind.emailTaken);
    }
    accounts[email.trim()] = password;
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: name.trim());
    _set(u);
    return u;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _check();
    resetRequests.add(email);
  }

  @override
  Future<void> refreshSession() async => refreshCount++;

  @override
  Future<void> signOut() async => _set(null);

  @override
  void dispose() {}
}
