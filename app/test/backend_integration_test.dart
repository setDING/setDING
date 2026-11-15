// Runs PocketBaseBackend against a real PocketBase with the repository's
// schema and hooks (server/, ADR-0015). The pinned PocketBase version is
// downloaded once by tool/server/fetch-pocketbase.sh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/sync/pocketbase_backend.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;
  late String url;

  setUpAll(() async {
    pb = await PocketBase.start();
    url = pb.baseUrl.toString().replaceAll(RegExp(r'/$'), '');
  });
  tearDownAll(() => pb.stop());

  var n = 0;
  String email() =>
      'app${++n}-${DateTime.now().microsecondsSinceEpoch}@realchord.test';

  Future<BackendErrorKind> kindOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on BackendException catch (e) {
      return e.kind;
    }
    fail('no BackendException');
  }

  test(
    'signs up, restores the session after a restart and signs out',
    () async {
      final store = MemorySessionStore();
      final address = email();
      final first = PocketBaseBackend(serverUrl: url, store: store);
      final user = await first.signUp(
        email: address,
        password: 'password-123',
        name: 'Ann',
      );
      expect(user.email, address);
      expect(user.name, 'Ann');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      first.dispose();

      // "Restart": a new backend on the stored session.
      final second = PocketBaseBackend(serverUrl: url, store: store);
      expect(second.currentUser, user);
      await second.refreshSession();
      expect(second.currentUser, user);

      await second.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.current, isNull);
      second.dispose();
    },
  );

  test('reports wrong credentials, taken email and weak password', () async {
    final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
    final address = email();
    await b.signUp(email: address, password: 'password-123', name: 'C');
    await b.signOut();

    expect(
      await kindOf(() => b.signIn(email: address, password: 'wrong-password')),
      BackendErrorKind.invalidCredentials,
    );
    expect(
      await kindOf(
        () => b.signUp(email: address, password: 'password-123', name: 'C'),
      ),
      BackendErrorKind.emailTaken,
    );
    expect(
      await kindOf(
        () => b.signUp(
          email: 'not-an-email',
          password: 'password-123',
          name: 'D',
        ),
      ),
      BackendErrorKind.invalidEmail,
    );
    expect(
      await kindOf(
        () => b.signUp(email: email(), password: 'short', name: 'E'),
      ),
      BackendErrorKind.weakPassword,
    );
    b.dispose();
  });

  test('accepts a password reset request', () async {
    final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
    await b.requestPasswordReset('nobody@realchord.test');
    b.dispose();
  });

  test('reports a network error when the server is unreachable', () async {
    final b = PocketBaseBackend(
      serverUrl: 'http://127.0.0.1:1',
      store: MemorySessionStore(),
    );
    expect(
      await kindOf(() => b.signIn(email: 'a@b.test', password: 'x')),
      BackendErrorKind.network,
    );
    b.dispose();
  });
}
