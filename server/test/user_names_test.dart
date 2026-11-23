import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// First name, last name and nickname of accounts (ADR-0062, #1039).
void main() {
  group('names', () {
    late PocketBase pb;

    setUpAll(() async => pb = await PocketBase.start());
    tearDownAll(() => pb.stop());

    var n = 0;
    Map<String, dynamic> account(Map<String, dynamic> names) {
      n++;
      return {
        'email':
            'names$n-${DateTime.now().microsecondsSinceEpoch}@setding.test',
        'password': 'password-123',
        'passwordConfirm': 'password-123',
        ...names,
      };
    }

    Future<Map<String, dynamic>> stored(String id) async =>
        (await pb.superuser.view('users', id)).json;

    test('sign-up requires first and last name', () async {
      for (final names in [
        <String, dynamic>{},
        {'first_name': 'Ann'},
        {'last_name': 'Meier'},
        {'first_name': '  ', 'last_name': 'Meier'},
        {'first_name': 'Ann', 'last_name': '', 'nickname': 'Annie'},
        {'first_name': 'Ann', 'last_name': 'x' * 101},
      ]) {
        final r = await pb.guest.post('users', account(names));
        expect(r.status, 400, reason: '$names ${r.json}');
      }
      // Not even a superuser creates an account without them.
      expect((await pb.superuser.post('users', account({}))).status, 400);
    });

    test('the server keeps name as nickname or full name', () async {
      final plain = await pb.guest.post(
        'users',
        account({'first_name': ' Ann  Marie ', 'last_name': 'Meier'}),
      );
      plain.expectStatus(200);
      final ann = await stored(plain.json['id'] as String);
      expect(ann['first_name'], 'Ann Marie');
      expect(ann['last_name'], 'Meier');
      expect(ann['nickname'], '');
      expect(ann['name'], 'Ann Marie Meier');

      final nick = await pb.guest.post(
        'users',
        account({
          'first_name': 'Robert',
          'last_name': 'Huber',
          'nickname': 'Bob',
          'name': 'ignored',
        }),
      );
      nick.expectStatus(200);
      expect((await stored(nick.json['id'] as String))['name'], 'Bob');
    });

    test('older apps that only send name are split', () async {
      final r = await pb.guest.post('users', account({'name': 'Ann M. Meier'}));
      r.expectStatus(200);
      final ann = await stored(r.json['id'] as String);
      expect(ann['first_name'], 'Ann M.');
      expect(ann['last_name'], 'Meier');
      expect(ann['name'], 'Ann M. Meier');

      // A single word is no full name; the error names the field they know.
      final single = await pb.guest.post('users', account({'name': 'Ann'}));
      expect(single.status, 400);
      expect(single.field('data.name.code'), 'validation_required');
    });

    test('users change their own names but cannot clear them', () async {
      final ann = await pb.signUp('Ann');
      final bob = await pb.signUp('Bob');
      (await ann.patch('users', ann.id, {
        'first_name': 'Anna',
        'last_name': 'Muster',
        'nickname': '',
      })).expectStatus(200);
      var me = await stored(ann.id);
      expect(me['name'], 'Anna Muster');

      for (final body in [
        {'first_name': ''},
        {'last_name': ' '},
      ]) {
        expect((await ann.patch('users', ann.id, body)).status, 400);
      }
      me = await stored(ann.id);
      expect([me['first_name'], me['last_name']], ['Anna', 'Muster']);

      // An older app renames with name only.
      (await ann.patch('users', ann.id, {'name': 'Annie'})).expectStatus(200);
      me = await stored(ann.id);
      expect(
        [me['first_name'], me['last_name'], me['nickname'], me['name']],
        ['Anna', 'Muster', 'Annie', 'Annie'],
      );

      // Nobody changes the names of somebody else.
      expect(
        (await ann.patch('users', bob.id, {'first_name': 'hacked'})).status,
        greaterThanOrEqualTo(400),
      );
      expect((await stored(bob.id))['first_name'], 'Bob');
    });

    test('bandmates see the names, outsiders do not', () async {
      final f = await BandFixture.create(pb);
      final admin = (await f.member.view('users', f.admin.id)).json;
      expect(admin['first_name'], 'Admin');
      expect(admin['last_name'], 'Test');
      expect(admin['nickname'], 'Admin');
      expect((await f.outsider.view('users', f.admin.id)).status, 404);
    });
  });

  test('the migration splits existing names', () async {
    var pb = await PocketBase.start(
      migrationsBefore: '1797200000_user_names.js',
    );
    addTearDown(() => pb.stop());
    Future<String> create(String name) async {
      final r = await pb.superuser.post('users', {
        'email': '${uuid()}@setding.test',
        'password': 'password-123',
        'passwordConfirm': 'password-123',
        'name': name,
      });
      r.expectStatus(200);
      return r.json['id'] as String;
    }

    final full = await create('Ann Marie Meier');
    final single = await create('Bob');
    final empty = await create('');

    pb = await pb.upgrade();
    Future<List<Object?>> names(String id) async {
      final u = (await pb.superuser.view('users', id)).json;
      return [u['first_name'], u['last_name'], u['nickname'], u['name']];
    }

    expect(await names(full), ['Ann Marie', 'Meier', '', 'Ann Marie Meier']);
    expect(await names(single), ['', '', 'Bob', 'Bob']);
    expect(await names(empty), ['', '', '', '']);
  });
}
