import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Map<String, dynamic> claims(String token) => jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
  ) as Map<String, dynamic>;

  test('user tokens are valid for 30 days', () async {
    final user = await pb.signUp();
    final refreshed = await user.send(
      'POST',
      '/api/collections/users/auth-refresh',
    );
    refreshed.expectStatus(200);
    final c = claims(refreshed.json['token'] as String);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final days = ((c['exp'] as int) - now) / 86400;
    expect(days, closeTo(30, 0.1));
  });

  test('anyone can sign up, but not twice with the same email', () async {
    final body = {
      'email': 'twice@setding.test',
      'password': 'password-123',
      'passwordConfirm': 'password-123',
      'first_name': 'Twice',
      'last_name': 'Test',
    };
    (await pb.guest.post('users', body)).expectStatus(200);
    final again = await pb.guest.post('users', body);
    expect(again.status, 400);
    expect(again.field('data.email.code'), 'validation_not_unique');
  });

  // Since PocketBase 0.42 an unknown or invalidated token is refused with
  // 401 on every route instead of being ignored. The app signs out on 401
  // (refreshSession); the Dart SDK never sends an expired token.
  test('an invalidated token is refused with 401 on every route', () async {
    final user = await pb.signUp();
    (await pb.superuser.patch('users', user.id, {
      'password': 'changed-password-123',
      'passwordConfirm': 'changed-password-123',
    })).expectStatus(200);
    for (final path in [
      '/api/collections/songs/records',
      '/api/setding/config',
      '/api/health',
    ]) {
      expect((await user.send('GET', path)).status, 401, reason: path);
    }
    final refresh = await user.send(
      'POST',
      '/api/collections/users/auth-refresh',
    );
    expect(refresh.status, 401);
    // Without the token the public routes stay open.
    (await pb.guest.send('GET', '/api/setding/config')).expectStatus(200);
    (await pb.guest.send('GET', '/api/health')).expectStatus(200);
  });

  group('own account (issue #779)', () {
    Future<int> signIn(String email, String password) async =>
        (await pb.guest.send(
          'POST',
          '/api/collections/users/auth-with-password',
          body: {'identity': email, 'password': password},
        )).status;

    Future<String> emailOf(User user) async =>
        (await pb.superuser.view('users', user.id)).json['email'] as String;

    test('users rename themselves, not others', () async {
      final ann = await pb.signUp('Ann');
      final bob = await pb.signUp('Bob');
      (await ann.patch('users', ann.id, {'name': 'Ann M.'})).expectStatus(200);
      expect((await pb.superuser.view('users', ann.id)).json['name'], 'Ann M.');
      expect(
        (await ann.patch('users', bob.id, {'name': 'hacked'})).status,
        greaterThanOrEqualTo(400),
      );
      expect((await pb.superuser.view('users', bob.id)).json['name'], 'Bob');
    });

    test('a password changes only with the current one', () async {
      final ann = await pb.signUp('Ann');
      final bob = await pb.signUp('Bob');
      final annEmail = await emailOf(ann);
      final bobEmail = await emailOf(bob);

      // Without or with a wrong current password, and for somebody else.
      for (final body in [
        {'password': 'changed-pw-1', 'passwordConfirm': 'changed-pw-1'},
        {
          'oldPassword': 'wrong-password',
          'password': 'changed-pw-1',
          'passwordConfirm': 'changed-pw-1',
        },
      ]) {
        final r = await ann.patch('users', ann.id, body);
        expect(r.status, 400, reason: '${r.json}');
      }
      expect(
        (await ann.patch('users', bob.id, {
          'oldPassword': 'password-123',
          'password': 'changed-pw-1',
          'passwordConfirm': 'changed-pw-1',
        })).status,
        greaterThanOrEqualTo(400),
      );
      expect(await signIn(annEmail, 'password-123'), 200);
      expect(await signIn(bobEmail, 'password-123'), 200);

      (await ann.patch('users', ann.id, {
        'oldPassword': 'password-123',
        'password': 'changed-pw-1',
        'passwordConfirm': 'changed-pw-1',
      })).expectStatus(200);
      expect(await signIn(annEmail, 'password-123'), 400);
      expect(await signIn(annEmail, 'changed-pw-1'), 200);
      // The old session is invalidated.
      expect(
        (await ann.send('POST', '/api/collections/users/auth-refresh')).status,
        401,
      );
    });
  });
}
