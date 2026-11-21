import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Deleting the own account (ADR-0052, issue #780) through the API.
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  const password = 'password-123';

  Future<Response> deleteAccount(Client client, String id, [String? pw]) =>
      client.send(
        'DELETE',
        '/api/collections/users/records/$id',
        body: {'password': ?pw},
      );

  Future<bool> exists(String id) async =>
      (await pb.superuser.view('users', id)).status == 200;

  Future<Map<String, dynamic>> record(String collection, String id) async {
    final r = await pb.superuser.view(collection, id);
    r.expectStatus(200);
    return r.json;
  }

  Future<String> emailOf(User user) async =>
      (await record('users', user.id))['email'] as String;

  Future<Map<String, dynamic>> orgMembership(String orgId, User user) async =>
      (await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "$orgId" && user = "${user.id}"',
      )).single;

  test('nobody deletes somebody else\'s account', () async {
    final f = await BandFixture.create(pb);
    final r = await deleteAccount(f.admin, f.member.id, password);
    expect(r.status, greaterThanOrEqualTo(400));
    expect(await exists(f.member.id), isTrue);
    expect(
      (await deleteAccount(pb.guest, f.member.id, password)).status,
      greaterThanOrEqualTo(400),
    );
    expect(await exists(f.member.id), isTrue);
  });

  test('a missing or wrong password is refused', () async {
    final f = await BandFixture.create(pb);
    for (final pw in [null, '', 'wrong-password']) {
      final r = await deleteAccount(f.member, f.member.id, pw);
      expect(r.status, 400, reason: '$pw: ${r.json}');
      expect(r.field('data.password.code'), 'invalid_password');
    }
    expect(await exists(f.member.id), isTrue);
    expect((await f.membershipOf(f.member))['deleted'], isFalse);
  });

  test(
    'the only admin of an organization is refused, also by superusers',
    () async {
      final f = await BandFixture.create(pb);
      final org = await record('organizations', f.orgId);
      final r = await deleteAccount(f.admin, f.admin.id, password);
      expect(r.status, 400, reason: '${r.json}');
      expect(r.field('data.organizations.code'), 'last_admin');
      expect(
        r.field('data.organizations.message') as String,
        startsWith(org['name'] as String),
      );
      expect(await exists(f.admin.id), isTrue);
      expect((await orgMembership(f.orgId, f.admin))['deleted'], isFalse);

      expect((await pb.superuser.delete('users', f.admin.id)).status, 400);
      expect(await exists(f.admin.id), isTrue);
    },
  );

  test(
    'deleting an account removes the person and keeps the shared content',
    () async {
      final f = await BandFixture.create(pb);
      final email = await emailOf(f.member);
      final song = await f.createSong(f.admin);
      // The member edited the song, has private data and a band role.
      final editor = await pb.signUp('Editor');
      await BandFixture.addOrgMember(pb, f.orgId, editor, role: 'librarian');
      (await pb.superuser.patch(
        'org_memberships',
        (await orgMembership(f.orgId, f.member))['id'] as String,
        {'role': 'librarian'},
      )).expectStatus(200);
      (await f.member.patch('songs', song['id'] as String, {
        'title': 'Edited',
        'revision': song['revision'],
      })).expectStatus(200);
      final edited = await record('songs', song['id'] as String);
      expect(edited['updated_by'], f.member.id);
      final overlay = await f.member.post('overlays', {
        'id': uuid(),
        'user': f.member.id,
        'song': song['id'],
        'data': {'transpose': 2},
      });
      overlay.expectStatus(200);
      final settings = await f.member.post('user_settings', {
        'id': uuid(),
        'user': f.member.id,
        'data': {'instrument': 'guitar'},
      });
      settings.expectStatus(200);
      final orgM = await orgMembership(f.orgId, f.member);
      final bandM = await f.membershipOf(f.member);

      final r = await deleteAccount(f.member, f.member.id, password);
      expect(r.status, 204, reason: '${r.json}');

      expect(await exists(f.member.id), isFalse);
      // Memberships stay as tombstones without a person, with a new revision.
      final orgAfter = await record('org_memberships', orgM['id'] as String);
      expect(orgAfter['deleted'], isTrue);
      expect(orgAfter['user'], '');
      expect(orgAfter['revision'] as int, greaterThan(orgM['revision'] as int));
      final bandAfter = await record('memberships', bandM['id'] as String);
      expect(bandAfter['deleted'], isTrue);
      expect(bandAfter['user'], '');
      expect(
        bandAfter['revision'] as int,
        greaterThan(bandM['revision'] as int),
      );
      // Bandmates see the tombstone in their sync.
      final seen = await f.admin.list(
        'memberships',
        filter: 'id = "${bandM['id']}"',
      );
      expect(seen.single['deleted'], isTrue);
      // Private data is gone.
      expect(
        (await pb.superuser.view(
          'overlays',
          overlay.json['id'] as String,
        )).status,
        404,
      );
      expect(
        (await pb.superuser.view(
          'user_settings',
          settings.json['id'] as String,
        )).status,
        404,
      );
      // The song stays; its author is cleared without a new revision.
      final songAfter = await record('songs', song['id'] as String);
      expect(songAfter['title'], 'Edited');
      expect(songAfter['deleted'], isFalse);
      expect(songAfter['updated_by'], '');
      expect(songAfter['revision'], edited['revision']);
      // The account cannot sign in or use its token anymore.
      final signIn = await pb.guest.send(
        'POST',
        '/api/collections/users/auth-with-password',
        body: {'identity': email, 'password': password},
      );
      expect(signIn.status, 400);
      expect(
        (await f.member.send(
          'POST',
          '/api/collections/users/auth-refresh',
        )).status,
        401,
      );
    },
  );

  test(
    'a band leader deletes their account and their invitations are revoked',
    () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      // The leader is the band's only leader besides the organization admin;
      // make them the only one.
      (await pb.superuser.patch(
        'memberships',
        (await f.membershipOf(f.admin))['id'] as String,
        {'role': 'member'},
      )).expectStatus(200);
      final invite = await leader.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId, 'band': f.id},
      );
      invite.expectStatus(200);
      final bandM = await f.membershipOf(leader);

      (await deleteAccount(leader, leader.id, password)).expectStatus(204);

      expect(
        (await record('memberships', bandM['id'] as String))['deleted'],
        isTrue,
      );
      final inv = await record('invites', invite.json['id'] as String);
      expect(inv['revoked'], isTrue);
      expect(inv['created_by'], '');
    },
  );

  test('an admin with a second admin deletes their account', () async {
    final f = await BandFixture.create(pb);
    final other = await pb.signUp('Other admin');
    await BandFixture.addOrgMember(pb, f.orgId, other, role: 'admin');
    (await deleteAccount(f.admin, f.admin.id, password)).expectStatus(204);
    expect(await exists(f.admin.id), isFalse);
    final admins = await pb.superuser.list(
      'org_memberships',
      filter:
          'organization = "${f.orgId}" && role = "admin" && deleted = false',
    );
    expect(admins.map((m) => m['user']), [other.id]);
  });

  test('a closed organization does not block its last admin', () async {
    final f = await BandFixture.create(pb);
    (await f.admin.delete('organizations', f.orgId)).expectStatus(204);
    final m = await orgMembership(f.orgId, f.admin);

    (await deleteAccount(f.admin, f.admin.id, password)).expectStatus(204);

    expect(await exists(f.admin.id), isFalse);
    final after = await record('org_memberships', m['id'] as String);
    expect(after['deleted'], isTrue);
    expect(after['user'], '');
  });

  test('superusers delete an account without a password', () async {
    final f = await BandFixture.create(pb);
    final bandM = await f.membershipOf(f.member);
    (await pb.superuser.delete('users', f.member.id)).expectStatus(204);
    expect(await exists(f.member.id), isFalse);
    final after = await record('memberships', bandM['id'] as String);
    expect(after['deleted'], isTrue);
    expect(after['user'], '');
  });
}
