import 'dart:convert';

import 'package:realchord_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Registration mode and email verification (ADR-0024).
void main() {
  Map<String, dynamic> account(String email, {String? invite}) => {
    'email': email,
    'password': 'password-123',
    'passwordConfirm': 'password-123',
    'name': 'New',
    'invite': ?invite,
  };

  int counter = 0;
  String email() =>
      'new${++counter}-${DateTime.now().microsecondsSinceEpoch}@realchord.test';

  Future<User> signIn(PocketBase pb, String email) async {
    final auth = await pb.guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': 'password-123'},
    );
    auth.expectStatus(200);
    return User(
      pb,
      auth.field('record.id') as String,
      auth.json['token'] as String,
    );
  }

  Future<String> invite(BandFixture f) async {
    final r = await f.admin.send(
      'POST',
      '/api/realchord/invites',
      body: {'organization': f.orgId},
    );
    r.expectStatus(200);
    return r.json['token'] as String;
  }

  Future<Map<String, dynamic>> founderInvite(PocketBase pb, String name) async {
    final r = await pb.command(['founder-invite', ...name.split(' ')]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    // The JSON line may carry a log prefix and go to stdout or stderr.
    final line = '${r.stdout}\n${r.stderr}'
        .split('\n')
        .lastWhere((l) => l.contains('"token"'));
    return jsonDecode(line.substring(line.indexOf('{')))
        as Map<String, dynamic>;
  }

  group('invite_only (default)', () {
    late PocketBase pb;

    setUpAll(
      () async => pb = await PocketBase.start(
        environment: {'REALCHORD_REGISTRATION': ''},
      ),
    );
    tearDownAll(() => pb.stop());

    test('the config route reports the mode without an account', () async {
      final r = await pb.guest.send('GET', '/api/realchord/config');
      r.expectStatus(200);
      expect(r.json, {
        'registration': 'invite_only',
        'emailVerification': 'off',
      });
    });

    test('sign-up without or with a bad invitation is refused', () async {
      expect((await pb.guest.post('users', account(email()))).status, 403);
      final bad = await pb.guest.post(
        'users',
        account(email(), invite: 'A' * 32),
      );
      expect(bad.status, 403);
      expect(bad.field('data.invite.code'), 'invitation_required');
    });

    test('sign-up with an invitation, then joining', () async {
      final f = await BandFixture.create(pb);
      final token = await invite(f);
      final preview = await pb.guest.send(
        'GET',
        '/api/realchord/invites/$token',
      );
      preview.expectStatus(200);
      expect(preview.field('organization.id'), f.orgId);
      expect(preview.json['member'], isFalse);
      expect(preview.json['founder'], isFalse);

      final address = email();
      (await pb.guest.post(
        'users',
        account(address, invite: token),
      )).expectStatus(200);
      final user = await signIn(pb, address);
      (await user.send(
        'POST',
        '/api/realchord/invites/$token/redeem',
      )).expectStatus(200);
      expect(await user.list('organizations'), hasLength(1));
    });

    test('revoked invitations do not allow a sign-up', () async {
      final f = await BandFixture.create(pb);
      final token = await invite(f);
      final listed = await f.admin.list('invites');
      for (final i in listed) {
        (await f.admin.patch('invites', i['id'] as String, {
          'revoked': true,
        })).expectStatus(200);
      }
      expect(
        (await pb.guest.post('users', account(email(), invite: token))).status,
        403,
      );
    });

    test('superusers create accounts without an invitation', () async {
      (await pb.superuser.post('users', account(email()))).expectStatus(200);
    });

    test('no new organizations through bands or directly', () async {
      final f = await BandFixture.create(pb);
      final band = await f.admin.post('bands', {'name': 'Solo'});
      expect(band.status, 403);
      final org = await f.admin.post('organizations', {'name': 'Mine'});
      expect(org.status, 403);
      final inOrg = await f.admin.post('bands', {
        'name': 'Second band',
        'organization': f.orgId,
      });
      inOrg.expectStatus(200);
    });

    test(
      'a founder invitation signs up and founds an organization once',
      () async {
        final founder = await founderInvite(pb, 'Music school');
        final token = founder['token'] as String;
        expect(token, hasLength(32));
        expect(founder['url'], endsWith('/invite/$token'));

        final preview = await pb.guest.send(
          'GET',
          '/api/realchord/invites/$token',
        );
        preview.expectStatus(200);
        expect(preview.json['founder'], isTrue);
        expect(preview.field('organization.name'), 'Music school');
        expect(preview.json['status'], 'valid');

        final address = email();
        (await pb.guest.post(
          'users',
          account(address, invite: token),
        )).expectStatus(200);
        final user = await signIn(pb, address);
        final redeemed = await user.send(
          'POST',
          '/api/realchord/invites/$token/redeem',
        );
        redeemed.expectStatus(200);
        final orgId = redeemed.field('organization.id') as String;
        final memberships = await user.list('org_memberships');
        expect(memberships.single['organization'], orgId);
        expect(memberships.single['role'], 'admin');

        // The founder can now create bands in it.
        (await user.post('bands', {
          'name': 'Choir',
          'organization': orgId,
        })).expectStatus(200);

        // Used: neither a second organization nor a sign-up.
        final again = await (await pb.signUpVia(
          token,
        )).send('POST', '/api/realchord/invites/$token/redeem');
        expect(again.status, 410);
        expect(
          (await pb.guest.post(
            'users',
            account(email(), invite: token),
          )).status,
          403,
        );
        final page = await pb.guest.send('GET', '/invite/$token');
        expect(page.raw.body, contains('invalid'));
      },
    );

    test(
      'founder invitations are not listed for organization admins',
      () async {
        await founderInvite(pb, 'Hidden');
        final f = await BandFixture.create(pb);
        final listed = await f.admin.list('invites');
        expect(listed.where((i) => i['organization'] == ''), isEmpty);
      },
    );

    test('the landing page names the organization to found', () async {
      final founder = await founderInvite(pb, 'Church band');
      final page = await pb.guest.send(
        'GET',
        '/invite/${founder['token']}',
        headers: {'Accept-Language': 'en'},
      );
      expect(page.raw.body, contains('found the organization Church band'));
    });
  });

  group('open', () {
    late PocketBase pb;

    setUpAll(
      () async => pb = await PocketBase.start(
        environment: {'REALCHORD_REGISTRATION': 'open'},
      ),
    );
    tearDownAll(() => pb.stop());

    test('anyone signs up and founds organizations', () async {
      final r = await pb.guest.send('GET', '/api/realchord/config');
      expect(r.json['registration'], 'open');
      (await pb.guest.post('users', account(email()))).expectStatus(200);
      final user = await pb.signUp();
      (await user.post('bands', {'name': 'Solo'})).expectStatus(200);
    });
  });

  group('email verification', () {
    test('required without SMTP stays off', () async {
      final pb = await PocketBase.start(
        environment: {'REALCHORD_EMAIL_VERIFICATION': 'required'},
      );
      addTearDown(pb.stop);
      final r = await pb.guest.send('GET', '/api/realchord/config');
      expect(r.json['emailVerification'], 'off');
      await pb.signUp();
    });

    test('required with SMTP blocks sign-in until verified', () async {
      final pb = await PocketBase.start(
        environment: {'REALCHORD_EMAIL_VERIFICATION': 'required'},
      );
      addTearDown(pb.stop);
      // SMTP pointing nowhere: sending fails, which only gets logged.
      (await pb.superuser.send(
        'PATCH',
        '/api/settings',
        body: {
          'smtp': {'enabled': true, 'host': '127.0.0.1', 'port': 1},
        },
      )).expectStatus(200);
      final r = await pb.guest.send('GET', '/api/realchord/config');
      expect(r.json['emailVerification'], 'required');

      final address = email();
      final created = await pb.guest.post('users', account(address));
      created.expectStatus(200);
      final denied = await pb.guest.send(
        'POST',
        '/api/collections/users/auth-with-password',
        body: {'identity': address, 'password': 'password-123'},
      );
      expect(denied.status, 403);
      expect(denied.field('data.email.code'), 'email_not_verified');

      (await pb.superuser.patch('users', created.json['id'] as String, {
        'verified': true,
      })).expectStatus(200);
      await signIn(pb, address);
    });
  });

  group('rate limits', () {
    test('are enabled by the migration', () async {
      final pb = await PocketBase.start(rateLimits: true);
      addTearDown(pb.stop);
      final r = await pb.superuser.send('GET', '/api/settings');
      r.expectStatus(200);
      final limits = r.json['rateLimits'] as Map<String, dynamic>;
      expect(limits['enabled'], isTrue);
      final labels = (limits['rules'] as List).map((x) => (x as Map)['label']);
      expect(
        labels,
        containsAll([
          'users:create',
          '*:auth',
          '/api/realchord/invites/',
          '/invite/',
        ]),
      );
    });
  });
}

extension on PocketBase {
  /// Signs up a user with an invitation and signs in (invite-only servers).
  Future<User> signUpVia(String token) async {
    final address =
        'via-${DateTime.now().microsecondsSinceEpoch}@realchord.test';
    // The invitation is used already, so sign up as superuser.
    (await superuser.post('users', {
      'email': address,
      'password': 'password-123',
      'passwordConfirm': 'password-123',
      'name': 'Late',
    })).expectStatus(200);
    final auth = await guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': address, 'password': 'password-123'},
    );
    auth.expectStatus(200);
    return User(
      this,
      auth.field('record.id') as String,
      auth.json['token'] as String,
    );
  }
}
