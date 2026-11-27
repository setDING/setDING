import 'package:test/test.dart';

import 'support/fixtures.dart';

import 'package:setding_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  group('bands', () {
    test('the creator becomes the first admin', () async {
      final user = await pb.signUp();
      final band = await user.post('bands', {'name': 'New band'});
      band.expectStatus(200);
      final memberships = await user.list('memberships');
      expect(memberships, hasLength(1));
      expect(memberships.single['band'], band.json['id']);
      expect(memberships.single['user'], user.id);
      expect(memberships.single['role'], 'admin');
      expect(
        memberships.single['revision'],
        greaterThan(band.json['revision']),
      );
    });

    test('guests cannot create bands', () async {
      final r = await pb.guest.post('bands', {'name': 'Anonymous'});
      expect(r.status, isNot(200));
    });

    test('only members see a band', () async {
      final f = await BandFixture.create(pb);
      expect((await f.admin.view('bands', f.id)).status, 200);
      expect((await f.member.view('bands', f.id)).status, 200);
      expect((await f.outsider.view('bands', f.id)).status, 404);
      expect(await f.outsider.list('bands', filter: 'id = "${f.id}"'), isEmpty);
    });

    test('only admins change band settings', () async {
      final f = await BandFixture.create(pb);
      final byMember = await f.member.patch('bands', f.id, {'name': 'Mine'});
      expect(byMember.status, 404);
      final byAdmin = await f.admin.patch('bands', f.id, {'name': 'Renamed'});
      byAdmin.expectStatus(200);
      expect(byAdmin.json['name'], 'Renamed');
      // The band setting was replaced by the librarian role (ADR-0023).
      expect(byAdmin.json.containsKey('members_can_edit_songs'), isFalse);
    });

    test('bands cannot be deleted through the API (issue #627)', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      for (final client in [leader, f.admin]) {
        final r = await client.patch('bands', f.id, {'deleted': true});
        expect(r.status, 404);
      }
      expect((await pb.superuser.view('bands', f.id)).json['deleted'], isFalse);
      // Renaming together with an unchanged flag still works.
      (await leader.patch('bands', f.id, {
        'name': 'Still here',
        'deleted': false,
      })).expectStatus(200);
    });
  });

  group('memberships', () {
    test('members see the memberships of their band only', () async {
      final f = await BandFixture.create(pb);
      final seen = await f.member.list(
        'memberships',
        filter: 'band = "${f.id}"',
      );
      expect(
        seen.map((m) => m['user']),
        unorderedEquals([f.admin.id, f.member.id]),
      );
      expect(
        await f.outsider.list('memberships', filter: 'band = "${f.id}"'),
        isEmpty,
      );
    });

    test('users cannot create memberships themselves', () async {
      final f = await BandFixture.create(pb);
      final join = await f.outsider.post('memberships', {
        'user': f.outsider.id,
        'band': f.id,
        'role': 'member',
      });
      expect(join.status, isNot(200));
      final byAdmin = await f.admin.post('memberships', {
        'user': f.outsider.id,
        'band': f.id,
        'role': 'member',
      });
      expect(byAdmin.status, isNot(200));
    });

    test('a user is a member of a band only once', () async {
      final f = await BandFixture.create(pb);
      final again = await pb.superuser.post('memberships', {
        'user': f.member.id,
        'band': f.id,
        'role': 'member',
      });
      expect(again.status, 400);
    });

    test('admins promote members and remove them', () async {
      final f = await BandFixture.create(pb);
      final m = await f.membershipOf(f.member);
      final promoted = await f.admin.patch('memberships', m['id'], {
        'role': 'admin',
      });
      promoted.expectStatus(200);
      expect(promoted.json['role'], 'admin');

      final removed = await f.admin.patch('memberships', m['id'], {
        'deleted': true,
      });
      removed.expectStatus(200);
      expect((await f.member.view('bands', f.id)).status, 404);
    });

    test('members cannot change roles', () async {
      final f = await BandFixture.create(pb);
      final own = await f.membershipOf(f.member);
      final self = await f.member.patch('memberships', own['id'], {
        'role': 'admin',
      });
      expect(self.status, isNot(200));
      final admin = await f.membershipOf(f.admin);
      final other = await f.member.patch('memberships', admin['id'], {
        'role': 'member',
      });
      expect(other.status, isNot(200));
      expect((await f.membershipOf(f.member))['role'], 'member');
    });

    test('memberships cannot be moved to another user or band', () async {
      final f = await BandFixture.create(pb);
      final other = await BandFixture.create(pb);
      final m = await f.membershipOf(f.member);
      expect(
        (await f.admin.patch('memberships', m['id'], {
          'user': f.outsider.id,
        })).status,
        isNot(200),
      );
      expect(
        (await f.admin.patch('memberships', m['id'], {
          'band': other.id,
        })).status,
        isNot(200),
      );
    });

    test('members can leave but not rejoin on their own', () async {
      final f = await BandFixture.create(pb);
      final m = await f.membershipOf(f.member);
      final left = await f.member.patch('memberships', m['id'], {
        'deleted': true,
      });
      left.expectStatus(200);
      expect((await f.member.view('bands', f.id)).status, 404);

      // The own (deleted) membership stays visible, so the app learns about it.
      final own = await f.member.list('memberships');
      expect(own.single['deleted'], isTrue);

      final rejoin = await f.member.patch('memberships', m['id'], {
        'deleted': false,
      });
      expect(rejoin.status, isNot(200));
    });

    test('the last admin can neither leave nor be demoted', () async {
      final f = await BandFixture.create(pb);
      final admin = await f.membershipOf(f.admin);
      final demote = await f.admin.patch('memberships', admin['id'], {
        'role': 'member',
      });
      expect(demote.status, 400);
      final leave = await f.admin.patch('memberships', admin['id'], {
        'deleted': true,
      });
      expect(leave.status, 400);
      final bySuperuser = await pb.superuser.patch('memberships', admin['id'], {
        'role': 'member',
      });
      expect(bySuperuser.status, 400);
      expect((await f.membershipOf(f.admin))['role'], 'admin');
    });

    test('an admin can step down when another admin remains', () async {
      final f = await BandFixture.create(pb);
      final member = await f.membershipOf(f.member);
      (await f.admin.patch('memberships', member['id'], {
        'role': 'admin',
      })).expectStatus(200);
      final admin = await f.membershipOf(f.admin);
      final stepDown = await f.admin.patch('memberships', admin['id'], {
        'role': 'member',
      });
      stepDown.expectStatus(200);
      // Now the former member is the last admin.
      final last = await f.member.patch('memberships', member['id'], {
        'deleted': true,
      });
      expect(last.status, 400);
    });

    test('a removed admin is no admin anymore', () async {
      final f = await BandFixture.create(pb);
      final second = await pb.signUp();
      final m = await BandFixture.addMember(pb, f.id, second, role: 'admin');
      (await f.admin.patch('memberships', m['id'] as String, {
        'deleted': true,
      })).expectStatus(200);
      final r = await second.patch('bands', f.id, {'name': 'Taken over'});
      expect(r.status, 404);
    });
  });

  group('users', () {
    test(
      'users see themselves and the people of their organizations only',
      () async {
        final f = await BandFixture.create(pb);
        final ids = (await f.member.list('users')).map((u) => u['id']);
        expect(ids, unorderedEquals([f.admin.id, f.member.id]));
        expect((await f.member.view('users', f.outsider.id)).status, 404);
        final outsiderSees = (await f.outsider.list('users'))
            .map((u) => u['id']);
        expect(outsiderSees, [f.outsider.id]);
      },
    );

    test('people stay visible while they share an organization', () async {
      final f = await BandFixture.create(pb);
      final m = await f.membershipOf(f.member);
      (await f.admin.patch('memberships', m['id'], {
        'deleted': true,
      })).expectStatus(200);
      // Removed from the band, but still in the organization (ADR-0017).
      expect((await f.admin.view('users', f.member.id)).status, 200);
    });
  });

  group('threshold for songs not played for a while (ADR-0046)', () {
    test(
      'band leaders, set planners and organization admins change it',
      () async {
        final f = await BandFixture.create(pb);
        final leader = await f.addLeader();
        final planner = await f.addPlanner();
        final band = await f.admin.view('bands', f.id);
        expect(band.json['stale_after_months'], 0, reason: 'default');
        for (final (user, months) in [
          (leader, 3),
          (planner, 9),
          (f.admin, 12),
        ]) {
          final r = await user.patch('bands', f.id, {
            'stale_after_months': months,
          });
          r.expectStatus(200);
          expect(r.json['stale_after_months'], months);
        }
        final seen = await f.member.view('bands', f.id);
        expect(seen.json['stale_after_months'], 12);
      },
    );

    test('only 1 to 36 months, or 0 for the default', () async {
      final f = await BandFixture.create(pb);
      for (final months in [37, -1]) {
        final r = await f.admin.patch('bands', f.id, {
          'stale_after_months': months,
        });
        expect(r.status, 400);
      }
      (await f.admin.patch('bands', f.id, {
        'stale_after_months': 0,
      })).expectStatus(200);
    });

    test('set planners change nothing else of the band', () async {
      final f = await BandFixture.create(pb);
      final planner = await f.addPlanner();
      final name = (await f.admin.view('bands', f.id)).json['name'];
      for (final body in [
        {'name': 'Mine'},
        {'name': 'Mine', 'stale_after_months': 3},
        {'stale_after_months': 3, 'deleted': true},
      ]) {
        final r = await planner.patch('bands', f.id, body);
        expect(r.status, greaterThanOrEqualTo(400), reason: '$body');
      }
      final band = await f.admin.view('bands', f.id);
      expect(band.json['name'], name);
      expect(band.json['stale_after_months'], 0);
      expect(band.json['deleted'], false);
    });
  });
}
