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
        'name': 'Compat',
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

    test('superusers are never refused', () async {
      (await pb.superuser.send(
        'GET',
        '/api/collections/songs/records',
      )).expectStatus(200);
    });
  });
}
