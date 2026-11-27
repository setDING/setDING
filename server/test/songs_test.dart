import 'package:test/test.dart';

import 'support/fixtures.dart';

import 'package:setding_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Map<String, dynamic> songBody(String org) => {
    'id': uuid(),
    'organization': org,
    'title': 'Song',
    'chordpro': '{title: Song}',
  };

  test('members of the band see songs, outsiders do not', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    expect((await f.member.view('songs', song['id'])).status, 200);
    expect((await f.outsider.view('songs', song['id'])).status, 404);
    expect(await f.outsider.list('songs'), isEmpty);
    expect((await pb.guest.view('songs', song['id'])).status, 404);
  });

  test('admins create and edit songs', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final r = await f.admin.patch('songs', song['id'], {
      'chordpro': '{title: Song}\n[Am]Changed',
      'revision': song['revision'],
    });
    r.expectStatus(200);
  });

  test('members cannot create or edit songs by default', () async {
    final f = await BandFixture.create(pb);
    expect((await f.member.post('songs', songBody(f.orgId))).status, 400);
    final song = await f.createSong(f.admin);
    final r = await f.member.patch('songs', song['id'], {
      'title': 'Hijacked',
      'revision': song['revision'],
    });
    expect(r.status, 404);
  });

  test('members create and edit songs if the band allows it', () async {
    final f = await BandFixture.create(pb, memberIsLibrarian: true);
    final created = await f.member.post('songs', songBody(f.orgId));
    created.expectStatus(200);
    final r = await f.member.patch('songs', created.json['id'], {
      'title': 'Fixed typo',
      'revision': created.json['revision'],
    });
    r.expectStatus(200);
  });

  test('outsiders cannot add songs to a band', () async {
    final f = await BandFixture.create(pb, memberIsLibrarian: true);
    expect((await f.outsider.post('songs', songBody(f.orgId))).status, 400);
  });

  test('organization admins and librarians delete songs (ADR-0023)', () async {
    final f = await BandFixture.create(pb, memberIsLibrarian: true);
    final leader = await f.addLeader();
    final own = await f.createSong(leader);
    final byLeader = await leader.patch('songs', own['id'], {
      'deleted': true,
      'revision': own['revision'],
    });
    expect(byLeader.status, 404);
    final byLibrarian = await f.member.patch('songs', own['id'], {
      'deleted': true,
      'revision': own['revision'],
    });
    byLibrarian.expectStatus(200);
    expect(byLibrarian.json['deleted'], isTrue);
    final other = await f.createSong(f.member);
    (await f.admin.patch('songs', other['id'], {
      'deleted': true,
      'revision': other['revision'],
    })).expectStatus(200);
  });

  group('own songs of band leaders (ADR-0023)', () {
    test('the creator is recorded and cannot be changed', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final song = await f.createSong(leader);
      expect(song['created_by'], leader.id);
      final forged = await leader.patch('songs', song['id'], {
        'created_by': f.admin.id,
        'revision': song['revision'],
      });
      expect(forged.status, isNot(200));
      final created = await f.admin.post('songs', {
        'organization': f.orgId,
        'title': 'Forged',
        'created_by': leader.id,
      });
      created.expectStatus(200);
      expect(created.json['created_by'], f.admin.id);
    });

    test('leaders edit their own songs until someone else does', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final leader = await f.addLeader();
      final song = await f.createSong(leader);
      final fixed = await leader.patch('songs', song['id'], {
        'title': 'Fixed',
        'revision': song['revision'],
      });
      fixed.expectStatus(200);

      final byLibrarian = await f.member.patch('songs', song['id'], {
        'title': 'Maintained',
        'revision': fixed.json['revision'],
      });
      byLibrarian.expectStatus(200);
      final again = await leader.patch('songs', song['id'], {
        'title': 'Mine again',
        'revision': byLibrarian.json['revision'],
      });
      expect(again.status, 404);
    });

    test('leaders do not edit songs of others', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final song = await f.createSong(f.admin);
      final r = await leader.patch('songs', song['id'], {
        'title': 'Nope',
        'revision': song['revision'],
      });
      expect(r.status, 404);
    });

    test('a former leader no longer edits their songs', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final song = await f.createSong(leader);
      final membership = await f.membershipOf(leader);
      (await f.admin.patch('memberships', membership['id'] as String, {
        'role': 'member',
      })).expectStatus(200);
      final r = await leader.patch('songs', song['id'], {
        'title': 'Nope',
        'revision': song['revision'],
      });
      expect(r.status, 404);
    });
  });

  test('set planners and members do not create songs', () async {
    final f = await BandFixture.create(pb);
    final planner = await f.addPlanner();
    for (final user in [planner, f.member]) {
      final r = await user.post('songs', {
        'organization': f.orgId,
        'title': 'Nope',
      });
      expect(r.status, 400);
    }
  });

  test('songs cannot be moved to another organization', () async {
    final f = await BandFixture.create(pb);
    final other = await BandFixture.create(pb);
    // f.admin is no member of other; add as admin to make the move plausible.
    await BandFixture.addOrgMember(pb, other.orgId, f.admin, role: 'admin');
    final song = await f.createSong(f.admin);
    final r = await f.admin.patch('songs', song['id'], {
      'organization': other.orgId,
      'revision': song['revision'],
    });
    expect(r.status, isNot(200));
  });

  group('conflicts', () {
    test('an update based on an old revision is refused with 409', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      final first = await f.member.patch('songs', song['id'], {
        'chordpro': '{title: Song}\nMember version',
        'revision': song['revision'],
      });
      first.expectStatus(200);

      final second = await f.admin.patch('songs', song['id'], {
        'chordpro': '{title: Song}\nAdmin version',
        'revision': song['revision'],
      });
      expect(second.status, 409);
      final current = await f.admin.view('songs', song['id']);
      expect(current.json['chordpro'], contains('Member version'));
    });

    test('an update without base revision is refused', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final r = await f.admin.patch('songs', song['id'], {'title': 'Blind'});
      expect(r.status, 400);
    });

    test('superusers may edit without base revision (admin UI)', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final r = await pb.superuser.patch('songs', song['id'], {'title': 'UI'});
      r.expectStatus(200);
    });
  });
}
