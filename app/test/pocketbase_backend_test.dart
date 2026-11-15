import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realchord/sync/pocketbase_backend.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_backend.dart';

const _server = 'https://pb.example.test';

/// An unsigned JWT that expires at [exp] (seconds since epoch).
String _token({int exp = 4102444800}) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': exp, 'type': 'auth'})}.sig';
}

Map<String, Object> _record({String name = 'Ann'}) => {
  'id': 'user1',
  'collectionId': '_pb_users_auth_',
  'collectionName': 'users',
  'email': 'ann@example.test',
  'name': name,
};

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A stored session for [_server] as the backend writes it.
String _storedSession({String server = _server, String? token}) => jsonEncode({
  'server': server,
  'auth': jsonEncode({'token': token ?? _token(), 'model': _record()}),
});

void main() {
  late List<http.Request> requests;

  PocketBaseBackend backend(
    SessionStore store,
    Future<http.Response> Function(http.Request) handler,
  ) {
    requests = [];
    return PocketBaseBackend(
      serverUrl: _server,
      store: store,
      httpClientFactory: () => MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
    );
  }

  test('signs in and stores the session for this server', () async {
    final store = MemorySessionStore();
    final b = backend(
      store,
      (r) async => _json(200, {'token': _token(), 'record': _record()}),
    );
    final changes = <AuthUser?>[];
    b.userChanges.listen(changes.add);

    final user = await b.signIn(email: ' ann@example.test ', password: 'pw');
    expect(user.id, 'user1');
    expect(user.displayName, 'Ann');
    expect(b.currentUser, user);
    expect(
      requests.single.url.path,
      '/api/collections/users/auth-with-password',
    );
    expect(jsonDecode(requests.single.body)['identity'], 'ann@example.test');

    await Future<void>.delayed(Duration.zero);
    expect(changes, [user]);
    final stored = jsonDecode(store.current!) as Map<String, dynamic>;
    expect(stored['server'], _server);
    expect(stored['auth'], contains('user1'));
  });

  test('restores a stored session without network access', () async {
    final b = backend(
      MemorySessionStore(_storedSession()),
      (r) async => throw const SocketException('offline'),
    );
    expect(b.currentUser?.email, 'ann@example.test');
    await b.refreshSession();
    expect(b.currentUser, isNotNull);
  });

  test('keeps an expired session while offline', () async {
    final b = backend(
      MemorySessionStore(_storedSession(token: _token(exp: 1))),
      (r) async => throw const SocketException('offline'),
    );
    expect(b.currentUser, isNotNull);
    await b.refreshSession();
    expect(b.currentUser, isNotNull);
  });

  test('signs out an expired session once the server is reachable', () async {
    final store = MemorySessionStore(_storedSession(token: _token(exp: 1)));
    final b = backend(store, (r) async => _json(200, {'code': 200}));
    await b.refreshSession();
    expect(requests.single.url.path, '/api/health');
    expect(b.currentUser, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.current, isNull);
  });

  test('ignores a session stored for another server', () async {
    final b = backend(
      MemorySessionStore(_storedSession(server: 'https://other.test')),
      (r) async => _json(500, {}),
    );
    expect(b.currentUser, isNull);
  });

  test('ignores a corrupt stored session', () async {
    final b = backend(
      MemorySessionStore('not json'),
      (r) async => _json(500, {}),
    );
    expect(b.currentUser, isNull);
  });

  test('refreshes the session when online', () async {
    final store = MemorySessionStore(_storedSession());
    final b = backend(
      store,
      (r) async =>
          _json(200, {'token': _token(), 'record': _record(name: 'Ann B.')}),
    );
    await b.refreshSession();
    expect(requests.single.url.path, '/api/collections/users/auth-refresh');
    expect(b.currentUser?.name, 'Ann B.');
    expect(store.current, contains('Ann B.'));
  });

  test('clears a session the server rejects', () async {
    final store = MemorySessionStore(_storedSession());
    final b = backend(
      store,
      (r) async =>
          _json(401, {'status': 401, 'message': 'invalid', 'data': {}}),
    );
    await b.refreshSession();
    expect(b.currentUser, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.current, isNull);
  });

  test('does not call the server to refresh without a session', () async {
    final b = backend(MemorySessionStore(), (r) async => _json(500, {}));
    await b.refreshSession();
    expect(requests, isEmpty);
  });

  test('signs out and deletes the stored session', () async {
    final store = MemorySessionStore(_storedSession());
    final b = backend(store, (r) async => _json(500, {}));
    await b.signOut();
    expect(b.currentUser, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.current, isNull);
  });

  group('errors', () {
    Future<BackendErrorKind> kindOf(Future<Object?> Function() call) async {
      try {
        await call();
      } on BackendException catch (e) {
        return e.kind;
      }
      fail('no BackendException');
    }

    test('wrong credentials', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(400, {
          'status': 400,
          'message': 'Failed to authenticate.',
          'data': {},
        }),
      );
      expect(
        await kindOf(() => b.signIn(email: 'a@b.test', password: 'x')),
        BackendErrorKind.invalidCredentials,
      );
      expect(b.currentUser, isNull);
    });

    test('no connection', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => throw const SocketException('offline'),
      );
      expect(
        await kindOf(() => b.signIn(email: 'a@b.test', password: 'x')),
        BackendErrorKind.network,
      );
    });

    Future<BackendErrorKind> signUpFails(Map<String, Object> data) {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(400, {
          'status': 400,
          'message': 'Failed to create record.',
          'data': data,
        }),
      );
      return kindOf(
        () => b.signUp(email: 'a@b.test', password: 'password', name: 'A'),
      );
    }

    test('email taken', () async {
      expect(
        await signUpFails({
          'email': {'code': 'validation_not_unique', 'message': 'taken'},
        }),
        BackendErrorKind.emailTaken,
      );
    });

    test('invalid email', () async {
      expect(
        await signUpFails({
          'email': {'code': 'validation_is_email', 'message': 'invalid'},
        }),
        BackendErrorKind.invalidEmail,
      );
    });

    test('weak password', () async {
      expect(
        await signUpFails({
          'password': {
            'code': 'validation_min_text_constraint',
            'message': 'x',
          },
        }),
        BackendErrorKind.weakPassword,
      );
    });

    test('other server errors', () async {
      expect(await signUpFails({}), BackendErrorKind.server);
    });
  });

  test('signs up with name and signs in', () async {
    final b = backend(MemorySessionStore(), (r) async {
      if (r.url.path.endsWith('/records')) return _json(200, _record());
      return _json(200, {'token': _token(), 'record': _record()});
    });
    final user = await b.signUp(
      email: 'ann@example.test',
      password: 'password',
      name: ' Ann ',
    );
    expect(user.name, 'Ann');
    final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(body['name'], 'Ann');
    expect(body['passwordConfirm'], 'password');
    expect(requests.last.url.path, '/api/collections/users/auth-with-password');
  });
}
