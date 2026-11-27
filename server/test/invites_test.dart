import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late PocketBase pb;

  setUpAll(
    () async => pb = await PocketBase.start(
      environment: {
        'SETDING_ANDROID_CERT_SHA256': 'AA:BB, CC:DD',
        'SETDING_APPLE_TEAM_ID': 'TEAM123',
      },
    ),
  );
  tearDownAll(() => pb.stop());

  Future<Response> create(Client client, String orgId) => client.send(
    'POST',
    '/api/setding/invites',
    body: {'organization': orgId},
  );

  Future<String> token(BandFixture f) async {
    final r = await create(f.admin, f.orgId);
    r.expectStatus(200);
    return r.json['token'] as String;
  }

  Future<Response> redeem(Client client, String token) =>
      client.send('POST', '/api/setding/invites/$token/redeem');

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

  group('link base URL (issue #617)', () {
    Future<void> setAppUrl(String url) async {
      final r = await pb.superuser.send(
        'PATCH',
        '/api/settings',
        body: {
          'meta': {'appURL': url},
        },
      );
      r.expectStatus(200);
    }

    tearDown(() => setAppUrl('http://localhost:8090'));

    test('links use the application URL, never the Host header', () async {
      await setAppUrl('https://api.example.test/');
      final f = await BandFixture.create(pb);
      const forged = {'host': 'evil.example.com'};
      final r = await f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId},
        headers: forged,
      );
      r.expectStatus(200);
      final t = r.json['token'] as String;
      expect(r.json['url'], 'https://api.example.test/invite/$t');

      final shown = await f.admin.send(
        'GET',
        '/api/setding/invites/${r.json['id']}/link',
        headers: forged,
      );
      shown.expectStatus(200);
      expect(shown.json['url'], 'https://api.example.test/invite/$t');
    });

    test('a localhost application URL is used as it is', () async {
      await setAppUrl('http://localhost:8090');
      final f = await BandFixture.create(pb);
      final r = await f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId},
        headers: {'host': 'evil.example.com'},
      );
      r.expectStatus(200);
      expect(r.json['url'], startsWith('http://localhost:8090/invite/'));
      expect(r.json['url'], isNot(contains('evil')));
    });
  });

  group('joining', () {
    test('shows the organization and joins as member', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final newcomer = await pb.signUp('Newcomer');

      final preview = await newcomer.send('GET', '/api/setding/invites/$t');
      preview.expectStatus(200);
      expect(preview.field('organization.id'), f.orgId);
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
      expect(revoked.field('data.token.code'), 'revoked');
      expect(
        (await user.send('GET', '/api/setding/invites/$t')).json['status'],
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
      expect(expired.field('data.token.code'), 'expired');

      expect((await redeem(user, 'A' * 32)).status, 404);
      expect((await redeem(user, 'bad!')).status, 404);
      expect((await user.view('organizations', f.orgId)).status, 404);
    });

    test('guests cannot join', () async {
      final f = await BandFixture.create(pb);
      expect((await redeem(pb.guest, await token(f))).status, 401);
    });
  });

  group('band leaders (ADR-0023)', () {
    Future<Response> createForBand(Client client, BandFixture f) => client.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': f.orgId, 'band': f.id},
    );

    test('leaders invite into their band; people join both', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      // Not into the organization alone.
      expect((await create(leader, f.orgId)).status, 403);
      final r = await createForBand(leader, f);
      r.expectStatus(200);
      final t = r.json['token'] as String;

      final newcomer = await pb.signUp('Newcomer');
      final preview = await newcomer.send('GET', '/api/setding/invites/$t');
      expect(preview.field('band.id'), f.id);
      (await redeem(newcomer, t)).expectStatus(200);
      final bands = await newcomer.list(
        'memberships',
        filter: 'user = "${newcomer.id}"',
      );
      expect(bands.single['band'], f.id);
      expect(bands.single['role'], 'member');
      final orgs = await newcomer.list(
        'org_memberships',
        filter: 'user = "${newcomer.id}"',
      );
      expect(orgs.single['role'], 'member');

      // An organization member who is not in the band joins the band.
      final known = await pb.signUp('Known');
      await BandFixture.addOrgMember(pb, f.orgId, known);
      final again = await redeem(known, t);
      again.expectStatus(200);
      expect(again.json['alreadyMember'], isFalse);
      expect(
        (await known.list(
          'memberships',
          filter: 'user = "${known.id}"',
        )).single['band'],
        f.id,
      );
    });

    test('leaders see and revoke only the links of their band', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      (await create(f.admin, f.orgId)).expectStatus(200);
      final mine = await createForBand(leader, f);
      final listed = await leader.list('invites');
      expect(listed.map((i) => i['id']), [mine.json['id']]);
      (await leader.patch('invites', mine.json['id'] as String, {
        'revoked': true,
      })).expectStatus(200);
      expect(await f.admin.list('invites'), hasLength(2));
    });

    test('set planners, members and other bands cannot invite', () async {
      final f = await BandFixture.create(pb);
      final planner = await f.addPlanner();
      expect((await createForBand(planner, f)).status, 403);
      expect((await createForBand(f.member, f)).status, 403);
      final other = await BandFixture.create(pb);
      final r = await f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId, 'band': other.id},
      );
      expect(r.status, 400);
    });

    test(
      'a band link also lets people sign up on invite-only servers',
      () async {
        final closed = await PocketBase.start(
          environment: {'SETDING_REGISTRATION': 'invite_only'},
        );
        addTearDown(closed.stop);
        final f = await BandFixture.create(closed);
        final leader = await f.addLeader();
        final r = await createForBand(leader, f);
        final created = await closed.guest.post('users', {
          'email': 'band-${DateTime.now().microsecondsSinceEpoch}@setding.test',
          'password': 'password-123',
          'passwordConfirm': 'password-123',
          'first_name': 'Drummer',
          'last_name': 'Test',
          'invite': r.json['token'],
        });
        created.expectStatus(200);
      },
    );
  });

  group('showing a link again (issue #579)', () {
    Future<Response> link(Client client, String id) =>
        client.send('GET', '/api/setding/invites/$id/link');

    test('admins get the same link; the token is stored encrypted', () async {
      final f = await BandFixture.create(pb);
      final created = await create(f.admin, f.orgId);
      final id = created.json['id'] as String;
      final r = await link(f.admin, id);
      r.expectStatus(200);
      expect(r.json['url'], created.json['url']);
      expect(r.json['expires'], created.json['expires']);

      final stored = await pb.superuser.view('invites', id);
      expect(stored.json['token_enc'], isNotEmpty);
      expect(stored.json['token_enc'], isNot(contains(created.json['token'])));
      expect(
        (await f.admin.list('invites')).single.containsKey('token_enc'),
        isFalse,
      );
      // Not changeable through the records API.
      await f.admin.patch('invites', id, {'token_enc': 'forged'});
      expect(
        (await pb.superuser.view('invites', id)).json['token_enc'],
        stored.json['token_enc'],
      );
    });

    test('only people who see the link get it', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final orgLink = (await create(f.admin, f.orgId)).json['id'] as String;
      final bandLink =
          (await leader.send(
                'POST',
                '/api/setding/invites',
                body: {'organization': f.orgId, 'band': f.id},
              )).json['id']
              as String;

      (await link(leader, bandLink)).expectStatus(200);
      (await link(f.admin, bandLink)).expectStatus(200);
      expect((await link(leader, orgLink)).status, 404);
      expect((await link(f.member, orgLink)).status, 404);
      expect((await link(f.outsider, bandLink)).status, 404);
      expect((await link(pb.guest, orgLink)).status, 401);
      expect((await link(f.admin, 'unknown')).status, 404);
    });

    test('revoked and expired links are not shown', () async {
      final f = await BandFixture.create(pb);
      final revoked = (await create(f.admin, f.orgId)).json['id'] as String;
      (await f.admin.patch('invites', revoked, {
        'revoked': true,
      })).expectStatus(200);
      final r = await link(f.admin, revoked);
      expect(r.status, 410);
      expect(r.field('data.token.code'), 'revoked');

      final expired = (await create(f.admin, f.orgId)).json['id'] as String;
      (await pb.superuser.patch('invites', expired, {
        'expires': '2020-01-01 00:00:00.000Z',
      })).expectStatus(200);
      expect(
        (await link(f.admin, expired)).field('data.token.code'),
        'expired',
      );
    });

    test('links stored with another key are not shown', () async {
      // The server does not start without a key (ADR-0063); a changed key
      // leaves the stored tokens unreadable.
      var keyed = await PocketBase.start();
      addTearDown(() => keyed.stop());
      final f = await BandFixture.create(keyed);
      final created = await create(f.admin, f.orgId);
      created.expectStatus(200);
      final id = created.json['id'] as String;
      expect(
        (await keyed.superuser.view('invites', id)).json['token_enc'],
        isNotEmpty,
      );
      keyed = await keyed.restart(
        environment: {'SETDING_INVITE_KEY': 'another-key'},
      );
      final admin = User(keyed, f.admin.id, f.admin.token!);
      final r = await link(admin, id);
      expect(r.status, 409);
      expect(r.field('data.token.code'), 'not_stored');
      // The link itself still works.
      (await redeem(
        await keyed.signUp(),
        created.json['token'] as String,
      )).expectStatus(200);
    });
  });

  group('invitation token hardening (issue #1200)', () {
    Future<Response> link(Client client, String id) =>
        client.send('GET', '/api/setding/invites/$id/link');

    test(
      'new links are stored with the full-length key and shown again',
      () async {
        final f = await BandFixture.create(pb);
        final created = await create(f.admin, f.orgId);
        created.expectStatus(200);
        final id = created.json['id'] as String;
        final enc =
            (await pb.superuser.view('invites', id)).json['token_enc']
                as String;
        expect(enc, startsWith('v2:'));
        final r = await link(f.admin, id);
        r.expectStatus(200);
        expect(r.json['url'], created.json['url']);
        // Showing it does not change it.
        expect((await pb.superuser.view('invites', id)).json['token_enc'], enc);
      },
    );

    test('links stored with the legacy key are still shown and then '
        're-encrypted', () async {
      // Encrypted before issue #1200 (AES-256-GCM, key: the first 32 hex
      // characters of sha256("setding-invite:test-invite-key")), together
      // with the SHA-256 of the token.
      const token = 'LegacyToken0123456789abcdefABCDE';
      const legacyEnc =
          'AAECAwQFBgcICQoLAKmdXkAt0kJwal1mMQmlEe0pAthlQCH44ek8Dssi4XwxyuHGv9OIv8Z1u4/rGup7';
      const tokenHash =
          'fe6279431ac7a7361e86bd1cdc1a696941a926fe7e50730c06c9095db8c23e51';
      final f = await BandFixture.create(pb);
      final id = (await create(f.admin, f.orgId)).json['id'] as String;
      (await pb.superuser.patch('invites', id, {
        'token_hash': tokenHash,
        'token_enc': legacyEnc,
      })).expectStatus(200);

      final r = await link(f.admin, id);
      r.expectStatus(200);
      expect(r.json['url'], endsWith('/invite/$token'));

      final enc =
          (await pb.superuser.view('invites', id)).json['token_enc'] as String;
      expect(enc, startsWith('v2:'));
      expect(enc, isNot(contains(token)));
      final again = await link(f.admin, id);
      again.expectStatus(200);
      expect(again.json['url'], r.json['url']);
      // The link itself works.
      (await redeem(await pb.signUp(), token)).expectStatus(200);
    });

    /// The request log entries whose URL contains [text].
    Future<List<dynamic>> logsWithUrl(String text) async {
      final r = await pb.superuser.send(
        'GET',
        '/api/logs?perPage=200&filter=${Uri.encodeQueryComponent("data.url~'$text'")}',
      );
      r.expectStatus(200);
      return r.json['items'] as List;
    }

    test('tokens do not appear in the request log', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final unknown = 'Unknown${DateTime.now().microsecondsSinceEpoch}';
      final id = (await create(f.admin, f.orgId)).json['id'] as String;
      final referer = pb.baseUrl.resolve('/invite/$t').toString();

      (await pb.guest.send('GET', '/invite/$t')).expectStatus(200);
      (await pb.guest.send(
        'GET',
        '/api/setding/invites/$t',
        headers: {'Referer': referer},
      )).expectStatus(200);
      // Unknown tokens get the landing page too.
      (await pb.guest.send('GET', '/invite/$unknown')).expectStatus(200);
      expect(
        (await pb.guest.send('GET', '/api/setding/invites/$unknown')).status,
        404,
      );
      // Refused before the route runs (no account).
      expect((await redeem(pb.guest, t)).status, 401);
      (await redeem(await pb.signUp(), t)).expectStatus(200);
      // The link route has a record id, which stays readable; it is
      // requested last, so its log entry shows that the batch was written.
      (await link(f.admin, id)).expectStatus(200);

      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while ((await logsWithUrl('/api/setding/invites/$id/link')).isEmpty) {
        expect(
          DateTime.now().isBefore(deadline),
          isTrue,
          reason: 'the request log was not written',
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(await logsWithUrl(t), isEmpty);
      expect(await logsWithUrl(unknown), isEmpty);
      final r = await pb.superuser.send(
        'GET',
        '/api/logs?perPage=200&filter=${Uri.encodeQueryComponent("data.referer~'$t'")}',
      );
      expect(r.json['items'], isEmpty);
      expect(await logsWithUrl('/invite/REDACTED'), isNotEmpty);
      expect(
        await logsWithUrl('/api/setding/invites/REDACTED/redeem'),
        isNotEmpty,
      );
    });
  });

  group('losing the right to invite (issue #1193)', () {
    Future<Map<String, dynamic>> invite(
      Client client,
      String orgId, {
      String? band,
      String? contact,
    }) async {
      final r = await client.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': orgId, 'band': ?band, 'contact': ?contact},
      );
      r.expectStatus(200);
      return r.json;
    }

    Future<Map<String, dynamic>> orgMembership(
      BandFixture f,
      User user,
    ) async => (await pb.superuser.list(
      'org_memberships',
      filter: 'organization = "${f.orgId}" && user = "${user.id}"',
    )).single;

    /// Checks on the server that the invitation is revoked and that
    /// redeeming it answers 410.
    Future<void> expectRevoked(Map<String, dynamic> link) async {
      final stored = await pb.superuser.view('invites', link['id'] as String);
      expect(stored.json['revoked'], isTrue, reason: 'invite ${link['id']}');
      final r = await redeem(await pb.signUp(), link['token'] as String);
      expect(r.status, 410);
      expect(r.field('data.token.code'), 'revoked');
    }

    /// Checks on the server that the invitation is still open and works.
    Future<void> expectValid(Map<String, dynamic> link) async {
      final stored = await pb.superuser.view('invites', link['id'] as String);
      expect(stored.json['revoked'], isFalse, reason: 'invite ${link['id']}');
      (await redeem(
        await pb.signUp(),
        link['token'] as String,
      )).expectStatus(200);
    }

    test('a demoted band leader loses their band invitations', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final mine = await invite(leader, f.orgId, band: f.id);
      final admins = await invite(f.admin, f.orgId, band: f.id);
      final membership = await f.membershipOf(leader);
      (await f.admin.patch('memberships', membership['id'] as String, {
        'role': 'planner',
      })).expectStatus(200);
      await expectRevoked(mine);
      await expectValid(admins);
    });

    test(
      'a band leader removed from the band loses their invitations',
      () async {
        final f = await BandFixture.create(pb);
        final leader = await f.addLeader();
        final mine = await invite(leader, f.orgId, band: f.id);
        final membership = await f.membershipOf(leader);
        (await f.admin.patch('memberships', membership['id'] as String, {
          'deleted': true,
        })).expectStatus(200);
        await expectRevoked(mine);
      },
    );

    test('an organization admin who stops leading the band keeps their '
        'invitations', () async {
      final f = await BandFixture.create(pb);
      // A second leader, so the band keeps an admin.
      await f.addLeader();
      final mine = await invite(f.admin, f.orgId, band: f.id);
      final membership = await f.membershipOf(f.admin);
      (await f.admin.patch('memberships', membership['id'] as String, {
        'role': 'member',
      })).expectStatus(200);
      await expectValid(mine);
    });

    test('a demoted organization admin keeps only the invitations of bands '
        'they still lead', () async {
      final f = await BandFixture.create(pb);
      final other = await f.admin.post('bands', {
        'name': 'Other band',
        'organization': f.orgId,
      });
      other.expectStatus(200);
      final otherId = other.json['id'] as String;
      final admin2 = await pb.signUp('Second admin');
      await BandFixture.addOrgMember(pb, f.orgId, admin2, role: 'admin');
      await BandFixture.addMember(pb, f.id, admin2, role: 'admin');
      final orgLink = await invite(admin2, f.orgId);
      final ledBand = await invite(admin2, f.orgId, band: f.id);
      final otherBand = await invite(admin2, f.orgId, band: otherId);
      final firstAdmins = await invite(f.admin, f.orgId);

      final m = await orgMembership(f, admin2);
      (await f.admin.patch('org_memberships', m['id'] as String, {
        'role': 'member',
      })).expectStatus(200);
      await expectRevoked(orgLink);
      await expectRevoked(otherBand);
      await expectValid(ledBand);
      await expectValid(firstAdmins);
    });

    test('an organization admin who leaves loses all their invitations; used '
        'personal invitations stay used', () async {
      final f = await BandFixture.create(pb);
      final admin2 = await pb.signUp('Second admin');
      await BandFixture.addOrgMember(pb, f.orgId, admin2, role: 'admin');
      await BandFixture.addMember(pb, f.id, admin2, role: 'admin');
      final orgLink = await invite(admin2, f.orgId);
      final bandLink = await invite(admin2, f.orgId, band: f.id);
      final contact = await admin2.post('contacts', {
        'id': uuid(),
        'organization': f.orgId,
        'first_name': 'Guest',
        'email': 'guest-${DateTime.now().microsecondsSinceEpoch}@setding.test',
      });
      contact.expectStatus(200);
      final personal = await invite(
        admin2,
        f.orgId,
        contact: contact.json['id'] as String,
      );
      final guest = await pb.signUp('Guest');
      (await redeem(guest, personal['token'] as String)).expectStatus(200);

      final m = await orgMembership(f, admin2);
      (await admin2.patch('org_memberships', m['id'] as String, {
        'deleted': true,
      })).expectStatus(200);
      await expectRevoked(orgLink);
      await expectRevoked(bandLink);
      final used = await pb.superuser.view('invites', personal['id'] as String);
      expect(used.json['revoked'], isFalse);
      expect(used.json['used_by'], guest.id);
    });
  });

  group('web', () {
    test('the landing page links into the app', () async {
      final f = await BandFixture.create(pb);
      final t = await token(f);
      final en = await pb.guest.send('GET', '/invite/$t');
      en.expectStatus(200);
      expect(en.raw.headers['content-type'], contains('text/html'));
      expect(en.raw.body, contains('setding://invite/$t'));
      expect(en.raw.body, contains('The Band'));
      // No web client configured on this server (see web_test.dart).
      expect(en.raw.body, isNot(contains('Open in the browser')));

      final bad = await pb.guest.send('GET', '/invite/${'A' * 32}');
      expect(bad.raw.body, contains('invalid'));
      expect(bad.raw.body, isNot(contains('setding://')));
    });

    test('serves the deep-link verification files', () async {
      final links = await pb.guest.send('GET', '/.well-known/assetlinks.json');
      links.expectStatus(200);
      expect(links.raw.body, contains('app.setding'));
      expect(links.raw.body, contains('"CC:DD"'));
      final apple = await pb.guest.send(
        'GET',
        '/.well-known/apple-app-site-association',
      );
      apple.expectStatus(200);
      expect(apple.raw.body, contains('TEAM123.app.setding'));
      expect(apple.raw.body, contains('/invite/*'));
      // Links to sets and songs (ADR-0065).
      expect(apple.raw.body, contains('/sets/*'));
      expect(apple.raw.body, contains('/songs/*'));
    });
  });
}
