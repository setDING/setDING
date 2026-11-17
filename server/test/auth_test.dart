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
}
