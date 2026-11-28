import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:setding/sync/pocketbase_backend.dart';
import 'package:setding/sync/session_store.dart';
import 'package:setding/sync/sync_backend.dart';

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
    Future<http.Response> Function(http.Request) handler, {
    List<Duration> rateLimitBackoff = const [Duration.zero, Duration.zero],
    String? clientVersion,
  }) {
    requests = [];
    return PocketBaseBackend(
      serverUrl: _server,
      store: store,
      rateLimitBackoff: rateLimitBackoff,
      clientVersion: clientVersion,
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
    expect(
      (jsonDecode(requests.single.body) as Map)['identity'],
      'ann@example.test',
    );

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

  group('minimum client version (ADR-0029)', () {
    test('sends the app version with every request', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(200, {'token': _token(), 'record': _record()}),
        clientVersion: '0.7.0',
      );
      await b.signIn(email: 'ann@example.test', password: 'pw');
      expect(requests, isNotEmpty);
      for (final r in requests) {
        expect(r.headers['X-Setding-Version'], '0.7.0');
      }
    });

    test('sends no version header without a version', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(200, {'token': _token(), 'record': _record()}),
      );
      await b.signIn(email: 'ann@example.test', password: 'pw');
      expect(requests.single.headers.containsKey('X-Setding-Version'), false);
    });

    test('HTTP 426 means the app must be updated', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(426, {
          'status': 426,
          'message': 'Please update setDING.',
          'data': {'minClientVersion': '1.0.0'},
        }),
      );
      await expectLater(
        b.signIn(email: 'ann@example.test', password: 'pw'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.kind,
            'kind',
            BackendErrorKind.updateRequired,
          ),
        ),
      );
    });

    test('keeps the session when the refresh is refused with 426', () async {
      final store = MemorySessionStore(_storedSession());
      final b = backend(store, (r) async => _json(426, {'status': 426}));
      await b.refreshSession();
      expect(b.currentUser, isNotNull);
      expect(store.current, isNotNull);
    });

    test('reads the minimum version from the server config', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(200, {
          'registration': 'invite_only',
          'emailVerification': 'off',
          'minClientVersion': '1.2.0',
          'latestClientVersion': '1.4.0',
        }),
      );
      final config = await b.fetchServerConfig();
      expect(config.minClientVersion, '1.2.0');
      expect(config.latestClientVersion, '1.4.0');
      expect(config.inviteOnly, isTrue);
    });

    test('an older server reports no minimum', () async {
      final b = backend(
        MemorySessionStore(),
        (r) async => _json(200, {'registration': 'open'}),
      );
      final config = await b.fetchServerConfig();
      expect(config.minClientVersion, isNull);
      expect(config.latestClientVersion, isNull);
      expect(config.openRegistration, isTrue);
    });

    test('an unrecognised registration mode is unknown, not open', () async {
      final b = backend(MemorySessionStore(), (r) async => _json(200, {}));
      final config = await b.fetchServerConfig();
      expect(config.registration, RegistrationMode.unknown);
      expect(config.openRegistration, isFalse);
      expect(config.inviteOnly, isFalse);
    });
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

  // ADR-0070: the storage of an organization, for those who may upload PDFs.
  test('reads the storage of an organization; 404 is none', () async {
    final store = MemorySessionStore(_storedSession());
    var status = 200;
    final b = backend(
      store,
      (r) async => status == 200
          ? _json(200, {
              'used_bytes': 3000,
              'limit_bytes': 26214400,
              'live_bytes': 1000,
              'trash_bytes': 2000,
            })
          : _json(404, {'message': 'not found', 'status': 404}),
    );
    final s = await b.fetchOrgStorage('o1');
    expect(requests.single.url.path, '/api/setding/organizations/o1/storage');
    expect(
      s,
      const OrgStorage(
        usedBytes: 3000,
        limitBytes: 26214400,
        liveBytes: 1000,
        trashBytes: 2000,
      ),
    );
    status = 404;
    expect(await b.fetchOrgStorage('o1'), isNull);
  });

  test('clears a session the server rejects', () async {
    final store = MemorySessionStore(_storedSession());
    final b = backend(
      store,
      (r) async => _json(401, {
        'status': 401,
        'message': 'invalid',
        'data': <String, dynamic>{},
      }),
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
          'data': <String, dynamic>{},
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
        () => b.signUp(
          email: 'a@b.test',
          password: 'password',
          name: const PersonName(
            firstName: 'A',
            lastName: 'Test',
            nickname: 'A',
          ),
        ),
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

  test('signs up with first and last name and signs in', () async {
    final b = backend(MemorySessionStore(), (r) async {
      if (r.url.path.endsWith('/records')) return _json(200, _record());
      return _json(200, {'token': _token(), 'record': _record()});
    });
    final user = await b.signUp(
      email: 'ann@example.test',
      password: 'password',
      name: const PersonName(firstName: ' Ann ', lastName: ' Muster '),
    );
    expect(user.name, 'Ann');
    final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
    // The server derives `name` (ADR-0062).
    expect(body.containsKey('name'), isFalse);
    expect(body['first_name'], 'Ann');
    expect(body['last_name'], 'Muster');
    expect(body['nickname'], '');
    expect(body['passwordConfirm'], 'password');
    expect(requests.last.url.path, '/api/collections/users/auth-with-password');
  });

  test('downloads share one file token and stream to the target', () async {
    final store = MemorySessionStore(_storedSession());
    final b = backend(store, (r) async {
      if (r.url.path == '/api/files/token') return _json(200, {'token': 'ft'});
      if (r.url.path == '/api/files/attachments/a1/one.pdf') {
        return http.Response.bytes([1, 2, 3], 200);
      }
      return _json(404, {'message': 'not found'});
    });
    RemoteAttachment attachment(String id, String file) => RemoteAttachment(
      id: id,
      organizationId: 'o1',
      songId: 's1',
      name: id,
      file: file,
    );

    final downloads = b.openDownloads();
    final one = StreamController<List<int>>();
    final received = one.stream.expand((chunk) => chunk).toList();
    await downloads.download(attachment('a1', 'one.pdf'), one.sink);
    await one.close();
    expect(await received, [1, 2, 3]);
    await expectLater(
      downloads.download(
        attachment('a2', 'two.pdf'),
        StreamController<List<int>>().sink,
      ),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.notAllowed,
        ),
      ),
    );
    downloads.close();
    expect(
      requests.where((r) => r.url.path == '/api/files/token'),
      hasLength(1),
    );
    expect(
      requests.where((r) => r.url.path.startsWith('/api/files/attachments')),
      everyElement(
        predicate<http.Request>((r) => r.url.queryParameters['token'] == 'ft'),
      ),
    );
  });

  group('rate limits (HTTP 429)', () {
    http.Response tooMany() => _json(429, {
      'status': 429,
      'message': 'Too Many Requests.',
      'data': <String, dynamic>{},
    });
    const song = RemoteSong(
      id: 's1',
      organizationId: 'o1',
      title: 'T',
      chordpro: '',
      revision: 0,
    );
    Map<String, Object> songRecord() => {
      'id': 's1',
      'collectionId': 'songs',
      'collectionName': 'songs',
      'organization': 'o1',
      'title': 'T',
      'chordpro': '',
      'revision': 7,
      'deleted': false,
    };

    test('signed-in requests are retried after a wait', () async {
      var rejected = 0;
      final b = backend(MemorySessionStore(_storedSession()), (r) async {
        if (rejected < 2) {
          rejected++;
          return tooMany();
        }
        return _json(200, songRecord());
      });
      final pushed = await b.pushSong(song, create: true);
      expect(pushed.revision, 7);
      expect(requests, hasLength(3));
      expect(requests.map((r) => r.method), everyElement('POST'));
    });

    test('pulls are retried as well', () async {
      var rejected = false;
      final b = backend(MemorySessionStore(_storedSession()), (r) async {
        if (!rejected) {
          rejected = true;
          return tooMany();
        }
        return _json(200, {
          'page': 1,
          'perPage': 500,
          'totalItems': 1,
          'totalPages': 1,
          'items': [songRecord()],
        });
      });
      final songs = await b.pullSongs('o1', 0);
      expect(songs.single.id, 's1');
      expect(requests, hasLength(2));
    });

    test('a request still rejected after the last wait fails', () async {
      final b = backend(
        MemorySessionStore(_storedSession()),
        (r) async => tooMany(),
      );
      await expectLater(
        b.pushSong(song, create: true),
        throwsA(
          isA<BackendException>().having(
            (e) => e.kind,
            'kind',
            BackendErrorKind.server,
          ),
        ),
      );
      // The first attempt and one retry per wait.
      expect(requests, hasLength(3));
    });

    test('waits as long as configured between the attempts', () async {
      final times = <DateTime>[];
      final b = backend(MemorySessionStore(_storedSession()), (r) async {
        times.add(DateTime.now());
        return times.length < 2 ? tooMany() : _json(200, songRecord());
      }, rateLimitBackoff: const [Duration(milliseconds: 200)]);
      await b.pushSong(song, create: true);
      expect(
        times[1].difference(times[0]),
        greaterThanOrEqualTo(const Duration(milliseconds: 200)),
      );
    });

    test('the default waits outlast the default limits', () {
      final total = PocketBaseBackend.defaultRateLimitBackoff.fold(
        Duration.zero,
        (a, b) => a + b,
      );
      // PocketBase's longest default window is 10 s (`/api/`).
      expect(total, greaterThan(const Duration(seconds: 10)));
    });

    test('signing in is not retried', () async {
      final b = backend(MemorySessionStore(), (r) async => tooMany());
      await expectLater(
        b.signIn(email: 'a@b.test', password: 'x'),
        throwsA(isA<BackendException>()),
      );
      expect(requests, hasLength(1));
    });

    test('attachment downloads are retried', () async {
      var rejected = false;
      final b = backend(MemorySessionStore(_storedSession()), (r) async {
        if (r.url.path == '/api/files/token') {
          return _json(200, {'token': 'ft'});
        }
        if (!rejected) {
          rejected = true;
          return tooMany();
        }
        return http.Response.bytes([4, 5], 200);
      });
      final downloads = b.openDownloads();
      final target = StreamController<List<int>>();
      final received = target.stream.expand((chunk) => chunk).toList();
      await downloads.download(
        const RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: 'a1',
          file: 'one.pdf',
        ),
        target.sink,
      );
      await target.close();
      downloads.close();
      expect(await received, [4, 5]);
      expect(
        requests.where((r) => r.url.path.startsWith('/api/files/attachments')),
        hasLength(2),
      );
    });
  });

  group('errors of signed-in requests', () {
    Matcher kind(BackendErrorKind k) =>
        throwsA(isA<BackendException>().having((e) => e.kind, 'kind', k));
    const song = RemoteSong(
      id: 's1',
      organizationId: 'o1',
      title: 'T',
      chordpro: '',
      revision: 3,
    );

    test('signed out: no request', () async {
      final b = backend(MemorySessionStore(), (r) async => _json(200, {}));
      await expectLater(
        b.pushSong(song, create: false),
        kind(BackendErrorKind.signedOut),
      );
      await expectLater(b.pullSets('b1', 0), kind(BackendErrorKind.signedOut));
      expect(requests, isEmpty);
    });

    test('a changed song is a conflict, other errors are mapped', () async {
      var status = 409;
      final b = backend(
        MemorySessionStore(_storedSession()),
        (r) async =>
            _json(status, {'message': 'x', 'data': <String, dynamic>{}}),
      );
      await expectLater(
        b.pushSong(song, create: false),
        kind(BackendErrorKind.conflict),
      );
      status = 403;
      await expectLater(
        b.pushSong(song, create: false),
        kind(BackendErrorKind.notAllowed),
      );
      await expectLater(b.pullSets('b1', 0), kind(BackendErrorKind.notAllowed));
    });

    test('a revoked invitation is reported as such', () async {
      final b = backend(
        MemorySessionStore(_storedSession()),
        (r) async => _json(410, {
          'message': 'gone',
          'data': {
            'token': {'code': 'revoked', 'message': 'revoked'},
          },
        }),
      );
      await expectLater(
        b.redeemInvite('A' * 32),
        kind(BackendErrorKind.inviteRevoked),
      );
    });
  });

  // A refused request is not sent again by itself; a server error or a rate
  // limit may go away (#1225).
  group('refused requests (#1225)', () {
    const attachment = RemoteAttachment(
      id: 'a1',
      organizationId: 'o1',
      songId: 's1',
      name: 'Score',
      sizeBytes: 3,
    );
    Future<BackendException> pushFails(int status, Object body) async {
      final b = backend(
        MemorySessionStore(_storedSession()),
        (r) async => _json(status, body),
        rateLimitBackoff: const [],
      );
      try {
        await b.pushAttachment(attachment, create: true, bytes: [1, 2, 3]);
      } on BackendException catch (e) {
        return e;
      }
      fail('no error');
    }

    test('a validation error is refused, with the code of its field', () async {
      final e = await pushFails(400, {
        'status': 400,
        'message': 'Failed to create record.',
        'data': {
          'file': {
            'code': 'validation_file_size_limit',
            'message': 'Too large.',
          },
        },
      });
      expect(e.kind, BackendErrorKind.server);
      expect(e.statusCode, 400);
      expect(e.refused, isTrue);
      expect(e.fieldCode('file'), 'validation_file_size_limit');
      expect(e.fieldCode('name'), isNull);
    });

    test('no permission is refused', () async {
      final e = await pushFails(403, {'status': 403, 'message': 'Forbidden'});
      expect(e.kind, BackendErrorKind.notAllowed);
      expect(e.refused, isTrue);
    });

    test('a server error and a rate limit are not refused', () async {
      for (final status in [500, 503, 429]) {
        final e = await pushFails(status, {'status': status, 'message': 'x'});
        expect(e.kind, BackendErrorKind.server, reason: '$status');
        expect(e.refused, isFalse, reason: '$status');
      }
    });

    test('an update needed and no network are not refused', () async {
      expect(
        (await pushFails(426, {'status': 426, 'message': 'x'})).refused,
        isFalse,
      );
      expect(const BackendException(BackendErrorKind.network).refused, isFalse);
      expect(
        const BackendException(BackendErrorKind.signedOut).refused,
        isFalse,
      );
    });
  });
}
