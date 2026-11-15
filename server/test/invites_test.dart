import 'package:realchord_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late PocketBase pb;

  setUpAll(
    () async => pb = await PocketBase.start(
      environment: {
        'REALCHORD_ANDROID_CERT_SHA256': 'AA:BB, CC:DD',
        'REALCHORD_APPLE_TEAM_ID': 'TEAM123',
      },
    ),
  );
  tearDownAll(() => pb.stop());

  Future<Response> create(Client client, String orgId) => client.send(
    'POST',
    '/api/realchord/invites',
    body: {'organization': orgId},
  );

  Future<String> token(BandFixture f) async {
    final r = await create(f.admin, f.orgId);
    r.expectStatus(200);
    return r.json['token'] as String;
  }

  Future<Response> redeem(Client client, String token) =>
      client.send('POST', '/api/realchord/invites/$token/redeem');

  group('creating links', () {
    test('organization admins get a link; only the hash is stored', () async {
      final f = await BandFixture.create(pb);
      final r = await create(f.admin, f.orgId);
      r.expectStatus(200);
      final t = r.json['token'] as String;
      expect(t, hasLength(32));
      expect(r.json['url'], endsWith('/invite/$t'));
      final expires = DateTime.parse(r.json['expires'] as String);
      expect(
        expires.difference(DateTime.now().toUtc()).inHours,
        inInclusiveRange(167, 168),
      );

      final stored = await pb.superuser.view('invites', r.json['id'] as String);
      expect(stored.json['token_hash'], isNot(t));
      expect(stored.json['created_by'], f.admin.id);
      final listed = await f.admin.list('invites');
      expect(listed.single.containsKey('token_hash'), isFalse);
    });

    test('members, outsiders and guests cannot create links', () async {
      final f = await BandFixture.create(pb);
      expect((await create(f.member, f.orgId)).status, 403);
      expect((await create(f.outsider, f.orgId)).status, 403);
      expect((await create(pb.guest, f.orgId)).status, 401);
    });

    test('links cannot be created through the records API', () async {
      final f = await BandFixture.create(pb);
      final r = await f.admin.post('invites', {
        'organization': f.orgId,
        'token_hash': 'forged',
        'expires': '2099-01-01 00:00:00.000Z',
      });
      expect(r.status, isNot(200));
    });

    test('only organization admins see and revoke links', () async {
      final f = await BandFixture.create(pb);
      final r = await create(f.admin, f.orgId);
      final id = r.json['id'] as String;
      expect(await f.member.list('invites'), isEmpty);
      expect(
        (await f.member.patch('invites', id, {'revoked': true})).status,
        404,
      );
      expect(
        (await f.admin.patch('invites', id, {
          'expires': '2099-01-01 00:00:00.000Z',
        })).status,
        isNot(200),
      );
      (await f.admin.patch('invites', id, {'revoked': true})).expectStatus(200);
    });
  });

  group('joining', () {
    test('shows the organization and joins as member', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final newcomer = await pb.signUp('Newcomer');

      final preview = await newcomer.send('GET', '/api/realchord/invites/$t');
      preview.expectStatus(200);
      expect(preview.json['organization']['id'], f.orgId);
      expect(preview.json['status'], 'valid');
      expect(preview.json['member'], isFalse);

      final joined = await redeem(newcomer, t);
      joined.expectStatus(200);
      expect(joined.json['alreadyMember'], isFalse);
      expect((await newcomer.view('organizations', f.orgId)).status, 200);
      final m = (await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${newcomer.id}"',
      )).single;
      expect(m['role'], 'member');
      expect(m['revision'], greaterThan(0));
      // Admins see who joined with which link.
      final joinedWith = await f.admin.list(
        'org_memberships',
        filter: 'invite != ""',
      );
      expect(joinedWith.single['user'], newcomer.id);
      // Joining the organization does not add the person to a band.
      expect((await newcomer.view('bands', f.id)).status, 404);
    });

    test('a link can be used several times', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      for (var i = 0; i < 2; i++) {
        (await redeem(await pb.signUp(), t)).expectStatus(200);
      }
    });

    test('joining twice is harmless', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final r = await redeem(f.member, t);
      r.expectStatus(200);
      expect(r.json['alreadyMember'], isTrue);
      final admin = await redeem(f.admin, t);
      expect(admin.json['alreadyMember'], isTrue);
      final own = (await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${f.admin.id}"',
      )).single;
      expect(own['role'], 'admin');
    });

    test('people who left can rejoin with a new link', () async {
      final f = await BandFixture.create(pb);
      final m = (await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${f.member.id}"',
      )).single;
      (await f.member.patch('org_memberships', m['id'] as String, {
        'deleted': true,
      })).expectStatus(200);
      expect((await f.member.view('organizations', f.orgId)).status, 404);

      final r = await redeem(f.member, await token(f));
      r.expectStatus(200);
      expect(r.json['alreadyMember'], isFalse);
      expect((await f.member.view('organizations', f.orgId)).status, 200);
    });

    test('revoked, expired and unknown links are refused', () async {
      final f = await BandFixture.create(pb);
      final created = await create(f.admin, f.orgId);
      final t = created.json['token'] as String;
      final id = created.json['id'] as String;
      final user = await pb.signUp();

      (await f.admin.patch('invites', id, {'revoked': true})).expectStatus(200);
      final revoked = await redeem(user, t);
      expect(revoked.status, 410);
      expect(revoked.json['data']['token']['code'], 'revoked');
      expect(
        (await user.send('GET', '/api/realchord/invites/$t')).json['status'],
        'revoked',
      );

      final t2 = await token(f);
      final id2 =
          (await f.admin.list(
                'invites',
              )).firstWhere((i) => i['revoked'] == false)['id']
              as String;
      (await pb.superuser.patch('invites', id2, {
        'expires': '2020-01-01 00:00:00.000Z',
      })).expectStatus(200);
      final expired = await redeem(user, t2);
      expect(expired.status, 410);
      expect(expired.json['data']['token']['code'], 'expired');

      expect((await redeem(user, 'A' * 32)).status, 404);
      expect((await redeem(user, 'bad!')).status, 404);
      expect((await user.view('organizations', f.orgId)).status, 404);
    });

    test('guests cannot join', () async {
      final f = await BandFixture.create(pb);
      expect((await redeem(pb.guest, await token(f))).status, 401);
    });
  });

  group('web', () {
    test('the landing page links into the app', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final en = await pb.guest.send('GET', '/invite/$t');
      en.expectStatus(200);
      expect(en.raw.headers['content-type'], contains('text/html'));
      expect(en.raw.body, contains('realchord://invite/$t'));
      expect(en.raw.body, contains('The Band'));

      final bad = await pb.guest.send('GET', '/invite/${'A' * 32}');
      expect(bad.raw.body, contains('invalid'));
      expect(bad.raw.body, isNot(contains('realchord://')));
    });

    test('serves the deep-link verification files', () async {
      final links = await pb.guest.send('GET', '/.well-known/assetlinks.json');
      links.expectStatus(200);
      expect(links.raw.body, contains('ch.realchord.realchord'));
      expect(links.raw.body, contains('"CC:DD"'));
      final apple = await pb.guest.send(
        'GET',
        '/.well-known/apple-app-site-association',
      );
      apple.expectStatus(200);
      expect(apple.raw.body, contains('TEAM123.ch.realchord.realchord'));
      expect(apple.raw.body, contains('/invite/*'));
    });
  });
}
