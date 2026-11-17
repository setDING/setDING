import 'package:realchord_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> orgMembership(String orgId, User user) async =>
      (await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "$orgId" && user = "${user.id}"',
      )).single;

  group('organizations', () {
    test(
      'a band without organization gets one with the creator as admin',
      () async {
        final user = await pb.signUp();
        final band = await user.post('bands', {'name': 'Solo'});
        band.expectStatus(200);
        final orgId = band.json['organization'] as String;
        final org = await user.view('organizations', orgId);
        org.expectStatus(200);
        expect(org.json['name'], 'Solo');
        final m = await user.list('org_memberships');
        expect(m.single['organization'], orgId);
        expect(m.single['role'], 'admin');
      },
    );

    test(
      'organization admins create further bands in their organization',
      () async {
        final f = await BandFixture.create(pb);
        final second = await f.admin.post('bands', {
          'name': 'Second band',
          'organization': f.orgId,
        });
        second.expectStatus(200);
        expect(second.json['organization'], f.orgId);
        final orgs = await f.admin.list('organizations');
        expect(orgs.map((o) => o['id']), [f.orgId]);
      },
    );

    test(
      'members and outsiders cannot create bands in an organization',
      () async {
        final f = await BandFixture.create(pb);
        for (final user in [f.member, f.outsider]) {
          final r = await user.post('bands', {
            'name': 'Rogue',
            'organization': f.orgId,
          });
          expect(r.status, 400, reason: user.id);
        }
      },
    );

    test(
      'anyone signed in can create an organization and becomes its admin',
      () async {
        final user = await pb.signUp();
        final org = await user.post('organizations', {'name': 'Music school'});
        org.expectStatus(200);
        expect((await orgMembership(org.json['id'], user))['role'], 'admin');
      },
    );

    test('only members see an organization', () async {
      final f = await BandFixture.create(pb);
      expect((await f.member.view('organizations', f.orgId)).status, 200);
      expect((await f.outsider.view('organizations', f.orgId)).status, 404);
    });

    test('only organization admins rename it', () async {
      final f = await BandFixture.create(pb);
      expect(
        (await f.member.patch('organizations', f.orgId, {'name': 'X'})).status,
        404,
      );
      (await f.admin.patch('organizations', f.orgId, {
        'name': 'New name',
      })).expectStatus(200);
    });

    test('users cannot add themselves to an organization', () async {
      final f = await BandFixture.create(pb);
      final r = await f.outsider.post('org_memberships', {
        'user': f.outsider.id,
        'organization': f.orgId,
        'role': 'member',
      });
      expect(r.status, isNot(200));
    });

    test(
      'the last organization admin can neither leave nor be demoted',
      () async {
        final f = await BandFixture.create(pb);
        final m = await orgMembership(f.orgId, f.admin);
        expect(
          (await f.admin.patch('org_memberships', m['id'], {
            'role': 'member',
          })).status,
          400,
        );
        expect(
          (await f.admin.patch('org_memberships', m['id'], {
            'deleted': true,
          })).status,
          400,
        );
      },
    );

    test('members cannot change their organization role', () async {
      final f = await BandFixture.create(pb);
      final m = await orgMembership(f.orgId, f.member);
      final r = await f.member.patch('org_memberships', m['id'], {
        'role': 'admin',
      });
      expect(r.status, isNot(200));
    });

    test('leaving the organization also leaves its bands', () async {
      final f = await BandFixture.create(pb);
      final m = await orgMembership(f.orgId, f.member);
      (await f.member.patch('org_memberships', m['id'], {
        'deleted': true,
      })).expectStatus(200);
      expect((await f.membershipOf(f.member))['deleted'], isTrue);
      expect((await f.member.view('bands', f.id)).status, 404);
      expect((await f.member.view('organizations', f.orgId)).status, 404);
      expect((await f.admin.view('users', f.member.id)).status, 404);
    });

    test(
      'removing the last band admin from the organization is allowed',
      () async {
        final f = await BandFixture.create(pb);
        final bandAdmin = await pb.signUp();
        // A second band whose only band admin is an organization member.
        final second = await f.admin.post('bands', {
          'name': 'Second',
          'organization': f.orgId,
        });
        final sm = await BandFixture.addMember(
          pb,
          second.json['id'] as String,
          bandAdmin,
          role: 'admin',
        );
        final creator = (await pb.superuser.list(
          'memberships',
          filter: 'band = "${second.json['id']}" && user = "${f.admin.id}"',
        )).single;
        (await f.admin.patch('memberships', creator['id'], {
          'deleted': true,
        })).expectStatus(200);

        final om = await orgMembership(f.orgId, bandAdmin);
        (await f.admin.patch('org_memberships', om['id'], {
          'deleted': true,
        })).expectStatus(200);
        final after = await pb.superuser.view(
          'memberships',
          sm['id'] as String,
        );
        expect(after.json['deleted'], isTrue);
      },
    );
  });

  group('band membership', () {
    test('band admins add organization members to their band', () async {
      final f = await BandFixture.create(pb);
      final newcomer = await pb.signUp();
      await BandFixture.addOrgMember(pb, f.orgId, newcomer);
      final r = await f.admin.post('memberships', {
        'user': newcomer.id,
        'band': f.id,
        'role': 'member',
      });
      r.expectStatus(200);
      expect((await newcomer.view('bands', f.id)).status, 200);
    });

    test('people outside the organization cannot join its bands', () async {
      final f = await BandFixture.create(pb);
      final r = await f.admin.post('memberships', {
        'user': f.outsider.id,
        'band': f.id,
        'role': 'member',
      });
      expect(r.status, 400);
      final bySuperuser = await pb.superuser.post('memberships', {
        'user': f.outsider.id,
        'band': f.id,
        'role': 'member',
      });
      expect(bySuperuser.status, 400);
    });

    test('band members cannot add people', () async {
      final f = await BandFixture.create(pb);
      final newcomer = await pb.signUp();
      await BandFixture.addOrgMember(pb, f.orgId, newcomer);
      final r = await f.member.post('memberships', {
        'user': newcomer.id,
        'band': f.id,
        'role': 'member',
      });
      expect(r.status, isNot(200));
    });

    test('organization admins manage bands they are not a member of', () async {
      final f = await BandFixture.create(pb);
      final bandAdmin = await pb.signUp();
      final second = await f.admin.post('bands', {
        'name': 'Second',
        'organization': f.orgId,
      });
      final id = second.json['id'] as String;
      await BandFixture.addMember(pb, id, bandAdmin, role: 'admin');
      final own = (await pb.superuser.list(
        'memberships',
        filter: 'band = "$id" && user = "${f.admin.id}"',
      )).single;
      (await f.admin.patch('memberships', own['id'], {
        'deleted': true,
      })).expectStatus(200);

      // Still visible and manageable as organization admin.
      expect((await f.admin.view('bands', id)).status, 200);
      (await f.admin.patch('bands', id, {'name': 'Renamed'})).expectStatus(200);
      (await f.admin.post('setlists', {
        'band': id,
        'name': 'Gig',
      })).expectStatus(200);
    });
  });

  group('shared song library', () {
    test('all bands of an organization see its songs', () async {
      final f = await BandFixture.create(pb);
      final second = await f.admin.post('bands', {
        'name': 'Second',
        'organization': f.orgId,
      });
      final player = await pb.signUp();
      await BandFixture.addMember(pb, second.json['id'] as String, player);
      final song = await f.createSong(f.admin);
      expect((await player.view('songs', song['id'] as String)).status, 200);
    });

    test('songs are not visible across organizations', () async {
      final a = await BandFixture.create(pb);
      final b = await BandFixture.create(pb);
      final song = await a.createSong(a.admin);
      expect((await b.admin.view('songs', song['id'] as String)).status, 404);
      final r = await b.admin.post('songs', {
        'organization': a.orgId,
        'title': 'Intruder',
      });
      expect(r.status, 400);
    });

    test(
      'leaders of another band create songs but edit only their own',
      () async {
        final f = await BandFixture.create(pb);
        final leader = await pb.signUp();
        final second = await f.admin.post('bands', {
          'name': 'Second',
          'organization': f.orgId,
        });
        await BandFixture.addMember(
          pb,
          second.json['id'] as String,
          leader,
          role: 'admin',
        );
        final song = await f.createSong(f.admin);
        final edit = await leader.patch('songs', song['id'] as String, {
          'title': 'Changed for my band',
          'revision': song['revision'],
        });
        expect(edit.status, 404);
        final own = await leader.post('songs', {
          'organization': f.orgId,
          'title': 'Mine',
        });
        own.expectStatus(200);
        (await leader.patch('songs', own.json['id'] as String, {
          'title': 'Mine, fixed',
          'revision': own.json['revision'],
        })).expectStatus(200);
      },
    );

    test('members edit songs only as librarians (ADR-0023)', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final denied = await f.member.patch('songs', song['id'] as String, {
        'title': 'Nope',
        'revision': song['revision'],
      });
      expect(denied.status, 404);
      final m = await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${f.member.id}"',
      );
      (await f.admin.patch('org_memberships', m.single['id'] as String, {
        'role': 'librarian',
      })).expectStatus(200);
      final allowed = await f.member.patch('songs', song['id'] as String, {
        'title': 'Yes',
        'revision': song['revision'],
      });
      allowed.expectStatus(200);
      // Librarians do not manage people.
      final role = await f.member.patch(
        'org_memberships',
        m.single['id'] as String,
        {'role': 'admin'},
      );
      expect(role.status, 404);
    });

    test('organization members without a band only read songs', () async {
      final f = await BandFixture.create(pb);
      final reader = await pb.signUp();
      await BandFixture.addOrgMember(pb, f.orgId, reader);
      final song = await f.createSong(f.admin);
      expect((await reader.view('songs', song['id'] as String)).status, 200);
      final r = await reader.post('songs', {
        'organization': f.orgId,
        'title': 'Mine',
      });
      expect(r.status, 400);
    });
  });
}
