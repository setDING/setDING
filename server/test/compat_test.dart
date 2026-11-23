import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

/// Minimum client version (ADR-0029).
void main() {
  Map<String, String> version(String v) => {'X-Setding-Version': v};

  group('default minimum (0.0.0)', () {
    late PocketBase pb;

    setUpAll(() async => pb = await PocketBase.start());
    tearDownAll(() => pb.stop());

    test('clients without the header are accepted', () async {
      final user = await pb.signUp();
      (await user.send(
        'GET',
        '/api/collections/songs/records',
      )).expectStatus(200);
    });

    test('the config route reports the minimum', () async {
      final r = await pb.guest.send('GET', '/api/setding/config');
      r.expectStatus(200);
      expect(r.json['minClientVersion'], '0.0.0');
      // Only deploys stamp a version (tool/server/deploy.sh).
      expect(r.json.containsKey('serverVersion'), isTrue);
      expect(r.json['serverVersion'], isNull);
      expect(r.json.containsKey('latestClientVersion'), isTrue);
      expect(r.json['latestClientVersion'], isNull);
    });
  });

  group('stamped server version', () {
    late PocketBase pb;
    // Where tool/server/deploy.sh puts the stamp; ignored by git.
    final stamp = File('../server/pb_hooks/setding-version.txt');

    setUpAll(() async {
      stamp.writeAsStringSync('1.2.3\n');
      pb = await PocketBase.start();
    });
    tearDownAll(() async {
      await pb.stop();
      if (stamp.existsSync()) stamp.deleteSync();
    });

    test('the config route reports the deployed version', () async {
      final r = await pb.guest.send('GET', '/api/setding/config');
      r.expectStatus(200);
      expect(r.json['serverVersion'], '1.2.3');
      // A release deploy reports the newest app release (ADR-0036).
      expect(r.json['latestClientVersion'], '1.2.3');
    });
  });

  group('server deployed from a working tree', () {
    late PocketBase pb;
    final stamp = File('../server/pb_hooks/setding-version.txt');

    setUpAll(() async {
      stamp.writeAsStringSync('1.2.4-dev+abc1234\n');
      pb = await PocketBase.start();
    });
    tearDownAll(() async {
      await pb.stop();
      if (stamp.existsSync()) stamp.deleteSync();
    });

    test('reports no newest release', () async {
      final r = await pb.guest.send('GET', '/api/setding/config');
      r.expectStatus(200);
      expect(r.json['serverVersion'], '1.2.4-dev+abc1234');
      expect(r.json['latestClientVersion'], isNull);
    });
  });

  group('raised minimum (SETDING_MIN_CLIENT_VERSION=2.0.0)', () {
    late PocketBase pb;
    late String email;
    const password = 'password-123';

    setUpAll(() async {
      pb = await PocketBase.start(
        environment: {'SETDING_MIN_CLIENT_VERSION': '2.0.0'},
      );
      email = 'compat-${DateTime.now().microsecondsSinceEpoch}@setding.test';
      (await pb.superuser.post('users', {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'first_name': 'Compat',
        'last_name': 'Test',
      })).expectStatus(200);
    });
    tearDownAll(() => pb.stop());

    Future<Response> signIn(Map<String, String>? headers) => pb.guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': password},
      headers: headers,
    );

    test('the config route stays open and reports the minimum', () async {
      final r = await pb.guest.send('GET', '/api/setding/config');
      r.expectStatus(200);
      expect(r.json['minClientVersion'], '2.0.0');
    });

    test('health stays open', () async {
      (await pb.guest.send('GET', '/api/health')).expectStatus(200);
    });

    test('a request without the header is refused with 426', () async {
      final r = await signIn(null);
      expect(r.status, 426);
      expect(r.field('data.minClientVersion'), '2.0.0');
      expect(r.field('data.clientVersion'), '0.0.0');
    });

    test('older versions are refused, including prereleases', () async {
      for (final v in ['1.9.9', '2.0.0-beta.1', 'garbage']) {
        expect((await signIn(version(v))).status, 426, reason: v);
      }
    });

    test('the minimum and newer versions are accepted', () async {
      for (final v in ['2.0.0', '2.0.0+42', '2.1.0', '10.0.0']) {
        expect((await signIn(version(v))).status, 200, reason: v);
      }
    });

    test('a signed-in outdated client is refused on every route', () async {
      final auth = await signIn(version('2.0.0'));
      final token = auth.json['token'] as String;
      final r = await Client(pb, token).send(
        'GET',
        '/api/collections/songs/records',
        headers: version('1.0.0'),
      );
      expect(r.status, 426);
      final own = await Client(pb, token).send(
        'POST',
        '/api/setding/invites',
        body: {'organization': 'x'},
        headers: version('1.0.0'),
      );
      expect(own.status, 426);
    });

    test('an outdated client with an invalid token still gets 426', () async {
      // The version check runs before PocketBase 0.42's 401 for unknown
      // tokens, so an outdated app is asked to update, not signed out.
      final r = await Client(pb, 'not-a-token').send(
        'GET',
        '/api/collections/songs/records',
        headers: version('1.0.0'),
      );
      expect(r.status, 426);
    });

    test('superusers are never refused', () async {
      (await pb.superuser.send(
        'GET',
        '/api/collections/songs/records',
      )).expectStatus(200);
    });
  });
}
