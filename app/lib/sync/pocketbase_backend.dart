import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'session_store.dart';
import 'sync_backend.dart';

/// [SyncBackend] on PocketBase (ADR-0004, ADR-0015).
class PocketBaseBackend implements SyncBackend {
  PocketBaseBackend({
    required this.serverUrl,
    required SessionStore store,
    http.Client Function()? httpClientFactory,
  }) : _store = store {
    _pb = PocketBase(
      serverUrl,
      authStore: AsyncAuthStore(
        initial: _sessionFor(store.current, serverUrl),
        save: (data) =>
            _store.write(jsonEncode({'server': serverUrl, 'auth': data})),
        clear: _store.delete,
      ),
      httpClientFactory: httpClientFactory,
    );
    // The SDK would drop an expired token before every request, also while
    // offline; refreshSession decides instead (offline-first, ADR-0001).
    _pb.autoClearAuthStore(false);
    _subscription = _pb.authStore.onChange.listen(
      (_) => _changes.add(currentUser),
    );
  }

  static const _users = 'users';

  @override
  final String serverUrl;

  final SessionStore _store;
  late final PocketBase _pb;
  late final StreamSubscription<AuthStoreEvent> _subscription;
  final _changes = StreamController<AuthUser?>.broadcast();

  /// The stored auth data, if it belongs to [serverUrl].
  static String? _sessionFor(String? stored, String serverUrl) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      if (data['server'] != serverUrl) return null;
      return data['auth'] as String?;
    } on FormatException {
      return null;
    }
  }

  @override
  AuthUser? get currentUser {
    final record = _pb.authStore.record;
    if (_pb.authStore.token.isEmpty || record == null) return null;
    return AuthUser(
      id: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
    );
  }

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _pb.collection(_users).authWithPassword(email.trim(), password);
    } on ClientException catch (e) {
      throw _map(e, credentials: true);
    }
    return currentUser!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _pb
          .collection(_users)
          .create(
            body: {
              'email': email.trim(),
              'password': password,
              'passwordConfirm': password,
              'name': name.trim(),
            },
          );
    } on ClientException catch (e) {
      throw _map(e);
    }
    return signIn(email: email, password: password);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _pb.collection(_users).requestPasswordReset(email.trim());
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> refreshSession() async {
    if (currentUser == null) return;
    try {
      if (_pb.authStore.isValid) {
        await _pb.collection(_users).authRefresh();
      } else {
        // An expired token cannot be refreshed. Only sign out once the
        // server is reachable; offline, the session stays.
        await _pb.health.check();
        _pb.authStore.clear();
      }
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        // Token invalidated or account gone: the user has to sign in again.
        _pb.authStore.clear();
      } else {
        debugPrint('Session refresh failed: ${e.statusCode} ${e.response}');
      }
    }
  }

  @override
  Future<void> signOut() async => _pb.authStore.clear();

  @override
  void dispose() {
    _subscription.cancel();
    _changes.close();
  }

  static BackendException _map(ClientException e, {bool credentials = false}) {
    if (e.statusCode == 0) {
      return BackendException(BackendErrorKind.network, e.originalError);
    }
    if (credentials && e.statusCode == 400) {
      return BackendException(BackendErrorKind.invalidCredentials, e.response);
    }
    final fields = e.response['data'];
    if (fields is Map) {
      String? code(String field) {
        final error = fields[field];
        return error is Map ? error['code'] as String? : null;
      }

      final email = code('email');
      if (email == 'validation_not_unique') {
        return BackendException(BackendErrorKind.emailTaken, e.response);
      }
      if (email != null) {
        return BackendException(BackendErrorKind.invalidEmail, e.response);
      }
      if (code('password') != null || code('passwordConfirm') != null) {
        return BackendException(BackendErrorKind.weakPassword, e.response);
      }
    }
    return BackendException(BackendErrorKind.server, e.response);
  }
}
