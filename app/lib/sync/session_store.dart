import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static const _key = 'realchord.session';

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
      debugPrint('Could not read the stored session: $e');
      _current = null;
    }
  }

  @override
  Future<void> write(String value) async {
    _current = value;
    try {
      await _storage.write(key: _key, value: value);
    } catch (e) {
      debugPrint('Could not store the session: $e');
    }
  }

  @override
  Future<void> delete() async {
    _current = null;
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('Could not delete the stored session: $e');
    }
  }
}

/// Session in a plain file. Only for isolated test instances
/// (`REALCHORD_DATA_DIR`, see Makefile), which must not touch the session
/// of a normally installed app.
class FileSessionStore implements SessionStore {
  FileSessionStore(this.file);

  final File file;
  String? _current;

  @override
  String? get current => _current;

  @override
  Future<void> load() async {
    _current = await file.exists() ? await file.readAsString() : null;
  }

  @override
  Future<void> write(String value) async {
    _current = value;
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  }

  @override
  Future<void> delete() async {
    _current = null;
    if (await file.exists()) await file.delete();
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
