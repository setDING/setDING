import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../util/log.dart';

const _log = Log('session');

/// The server a stored session belongs to (`{"server": …, "auth": …}`, written
/// by the PocketBase backend), or null if there is none or it cannot be read.
String? sessionServer(String? stored) {
  if (stored == null || stored.isEmpty) return null;
  try {
    if (jsonDecode(stored) case {'server': final String server}
        when server.isNotEmpty) {
      return server;
    }
  } on FormatException {
    // An unreadable session belongs to no server.
  }
  return null;
}

/// Persists the session (auth token and user record) between app starts.
///
/// [load] is called once at startup; afterwards [current] holds the stored
/// value synchronously, so the backend can restore the session without
/// waiting (offline start, ADR-0001).
abstract class SessionStore {
  String? get current;

  Future<void> load();

  Future<void> write(String value);

  Future<void> delete();
}

/// Session in the platform's secure storage (Keychain, Android Keystore,
/// Windows Credential Manager / DPAPI, libsecret on Linux).
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'setding.session';

  final FlutterSecureStorage _storage;
  String? _current;

  @override
  String? get current => _current;

  @override
  Future<void> load() async {
    try {
      _current = await _storage.read(key: _key);
    } catch (e) {
      // No keyring available (e.g. a Linux desktop without Secret Service):
      // the app starts signed out instead of failing.
      _log.warning('Could not read the stored session', e);
      _current = null;
    }
  }

  @override
  Future<void> write(String value) async {
    _current = value;
    try {
      await _storage.write(key: _key, value: value);
    } catch (e) {
      _log.warning('Could not store the session', e);
    }
  }

  @override
  Future<void> delete() async {
    _current = null;
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      _log.warning('Could not delete the stored session', e);
    }
  }
}

/// Session kept in memory only (tests).
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this._current]);

  String? _current;

  @override
  String? get current => _current;

  @override
  Future<void> load() async {}

  @override
  Future<void> write(String value) async => _current = value;

  @override
  Future<void> delete() async => _current = null;
}
