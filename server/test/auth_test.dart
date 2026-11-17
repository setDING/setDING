import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Map<String, dynamic> claims(String token) =>
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;

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
}
