import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _svg = utf8.encode(
  '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
);

/// PocketBase's default fields of `users` that setDING does not use are
/// removed (`avatar`) or locked (`emailVisibility`, `name`), issue #1197.
void main() {
  group('unused user fields', () {
    late PocketBase pb;

    setUpAll(() async => pb = await PocketBase.start());
    tearDownAll(() => pb.stop());

    Future<Map<String, dynamic>> stored(String id) async =>
        (await pb.superuser.view('users', id)).json;

    test('users cannot upload an avatar (#1197)', () async {
      final ann = await pb.signUp('Ann');
      final r = await ann.patchMultipart(
        'users',
        ann.id,
        const {},
        fileField: 'avatar',
        bytes: _svg,
        filename: 'avatar.svg',
        contentType: 'image/svg+xml',
      );
      // Unknown fields are ignored; nothing is stored.
      expect(r.status, anyOf(200, 400));
      final me = await stored(ann.id);
      expect(me.containsKey('avatar'), isFalse);
      final users = await pb.superuser.send('GET', '/api/collections/users');
      final fields = (users.json['fields'] as List).map(
        (f) => (f as Map)['name'],
      );
      expect(fields, isNot(contains('avatar')));
    });

    test('users cannot make their e-mail visible (#1197)', () async {
      final f = await BandFixture.create(pb);
      final r = await f.member.patch('users', f.member.id, {
        'emailVisibility': true,
      });
      expect(r.status, greaterThanOrEqualTo(400));
      expect((await stored(f.member.id))['emailVisibility'], isFalse);

      // Not even together with an allowed change.
      final both = await f.member.patch('users', f.member.id, {
        'nickname': 'Visible',
        'emailVisibility': true,
      });
      expect(both.status, greaterThanOrEqualTo(400));
      final me = await stored(f.member.id);
      expect(me['emailVisibility'], isFalse);
      expect(me['nickname'], isNot('Visible'));

      // Other members of the organization do not get the address.
      final seen = await f.admin.view('users', f.member.id);
      seen.expectStatus(200);
      expect(seen.json['email'] ?? '', isEmpty);
      final listed = await f.admin.list(
        'users',
        filter: 'id = "${f.member.id}"',
      );
      expect(listed.single['email'] ?? '', isEmpty);

      // Names stay changeable, with the visibility sent as false.
      (await f.member.patch('users', f.member.id, {
        'nickname': 'Still me',
        'emailVisibility': false,
      })).expectStatus(200);
      expect((await stored(f.member.id))['nickname'], 'Still me');
    });

    test('sign-up cannot make the e-mail visible (#1197)', () async {
      Map<String, dynamic> account(Object? visible) => {
        'email': '${uuid()}@setding.test',
        'password': 'password-123',
        'passwordConfirm': 'password-123',
        'first_name': 'Ann',
        'last_name': 'Meier',
        'emailVisibility': ?visible,
      };
      final refused = account(true);
      expect((await pb.guest.post('users', refused)).status, 400);
      final none = await pb.superuser.list(
        'users',
        filter: 'email = "${refused['email']}"',
      );
      expect(none, isEmpty);
      (await pb.guest.post('users', account(false))).expectStatus(200);
      (await pb.guest.post('users', account(null))).expectStatus(200);
    });

    test('name is kept by the server, not by the client (#1197)', () async {
      final ann = await pb.signUp('Ann');
      (await ann.patch('users', ann.id, {
        'nickname': 'Annie',
        'name': 'Somebody else',
      })).expectStatus(200);
      expect((await stored(ann.id))['name'], 'Annie');
    });
  });

  test('the migration clears emailVisibility and reverts (#1197)', () async {
    var pb = await PocketBase.start(
      migrationsBefore: '1797400000_lock_user_fields.js',
    );
    addTearDown(() => pb.stop());
    final f = await BandFixture.create(pb);
    // Before, members could make their address visible and set an avatar.
    (await f.member.patch('users', f.member.id, {
      'emailVisibility': true,
    })).expectStatus(200);
    final email = (await pb.superuser.view('users', f.member.id)).json['email'];
    expect((await f.admin.view('users', f.member.id)).json['email'], email);

    pb = await pb.upgrade();
    final admin = await signIn(pb, f.admin);
    final member = (await pb.superuser.view('users', f.member.id)).json;
    expect(member['emailVisibility'], isFalse);
    expect(member.containsKey('avatar'), isFalse);
    expect((await admin.view('users', f.member.id)).json['email'] ?? '', '');

    // Down: the default field and rules are back; up again locks them.
    pb = await pb.downgrade('1797400000_lock_user_fields.js');
    var users = await pb.superuser.send('GET', '/api/collections/users');
    expect(
      (users.json['fields'] as List).map((f) => (f as Map)['name']),
      contains('avatar'),
    );
    expect(users.json['updateRule'], 'id = @request.auth.id');
    final down = await signIn(pb, f.member);
    (await down.patchMultipart(
      'users',
      f.member.id,
      const {},
      fileField: 'avatar',
      bytes: _svg,
      filename: 'avatar.svg',
      contentType: 'image/svg+xml',
    )).expectStatus(200);

    pb = await pb.upgrade();
    users = await pb.superuser.send('GET', '/api/collections/users');
    expect(
      (users.json['fields'] as List).map((f) => (f as Map)['name']),
      isNot(contains('avatar')),
    );
    final up = await signIn(pb, f.member);
    expect(
      (await up.patch('users', f.member.id, {'emailVisibility': true})).status,
      greaterThanOrEqualTo(400),
    );
  });
}

/// The same user with a token of the restarted server.
Future<User> signIn(PocketBase pb, User user) async {
  final record = await pb.superuser.view('users', user.id);
  final r = await pb.guest.send(
    'POST',
    '/api/collections/users/auth-with-password',
    body: {'identity': record.json['email'], 'password': 'password-123'},
  );
  r.expectStatus(200);
  return User(pb, user.id, r.json['token'] as String);
}
