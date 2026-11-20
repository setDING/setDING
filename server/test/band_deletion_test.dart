import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Deleting bands (ADR-0044, issue #628): organization admins delete a band
/// with DELETE on the records API; the server keeps it 30 days in the trash
/// with everything that went with it, and refuses writes into it.
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> view(String collection, String id) async =>
      (await pb.superuser.view(collection, id)).json;

  Map<String, dynamic> newSet(String band, [String name = 'Set']) => {
    'id': uuid(),
    'band': band,
    'name': name,
    'items': <dynamic>[],
  };

  /// A band with a set, an earlier deleted set, an arrangement, a leader,
  /// a member, an open invitation and a song of the organization.
  Future<
    ({
      BandFixture f,
      User leader,
      String set,
      String oldSet,
      String arrangement,
      String invite,
      String song,
    })
  >
  setUpBand() async {
    final f = await BandFixture.create(pb);
    final leader = await f.addLeader();
    final song = await f.createSong(f.admin);
    final set = await leader.post('setlists', newSet(f.id));
    set.expectStatus(200);
    final oldSet = await leader.post('setlists', newSet(f.id, 'Old'));
    oldSet.expectStatus(200);
    (await leader.patch('setlists', oldSet.json['id'], {
      'deleted': true,
    })).expectStatus(200);
    final arrangement = await leader.post('arrangements', {
      'id': uuid(),
      'band': f.id,
      'song': song['id'],
      'transpose': 2,
    });
    arrangement.expectStatus(200);
    final invite = await leader.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': f.orgId, 'band': f.id},
    );
    invite.expectStatus(200);
    return (
      f: f,
      leader: leader,
      set: set.json['id'] as String,
      oldSet: oldSet.json['id'] as String,
      arrangement: arrangement.json['id'] as String,
      invite: invite.json['id'] as String,
      song: song['id'] as String,
    );
  }

  test('organization admins delete a band with everything of it', () async {
    final b = await setUpBand();
    final r = await b.f.admin.delete('bands', b.f.id);
    expect(r.status, 204);

    final band = await view('bands', b.f.id);
    expect(band['deleted'], isTrue);
    expect(band['deleted_at'], isNotEmpty);
    expect(band['updated_by'], b.f.admin.id);
    final set = await view('setlists', b.set);
    expect(set['deleted'], isTrue);
    expect(set['deleted_at'], band['deleted_at']);
    expect(set['revision'], greaterThan(band['revision'] as int));
    expect((await view('arrangements', b.arrangement))['deleted'], isTrue);
    for (final user in [b.f.admin, b.f.member, b.leader]) {
      expect((await b.f.membershipOf(user))['deleted'], isTrue);
    }
    expect((await view('invites', b.invite))['revoked'], isTrue);
    // The organization's library stays.
    expect((await view('songs', b.song))['deleted'], isFalse);

    // Members no longer see it; the organization admin does (trash).
    expect((await b.f.member.view('bands', b.f.id)).status, 404);
    expect((await b.f.admin.view('bands', b.f.id)).status, 200);
  });

  test('a deleted band takes no writes', () async {
    final b = await setUpBand();
    (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
    expect(
      (await b.f.admin.post('setlists', newSet(b.f.id))).status,
      greaterThanOrEqualTo(400),
    );
    expect(
      (await b.f.admin.patch('setlists', b.set, {'name': 'x'})).status,
      greaterThanOrEqualTo(400),
    );
    expect(
      (await b.f.admin.patch('bands', b.f.id, {'name': 'x'})).status,
      greaterThanOrEqualTo(400),
    );
    expect(
      (await b.f.admin.post('memberships', {
        'user': b.f.member.id,
        'band': b.f.id,
        'role': 'member',
      })).status,
      greaterThanOrEqualTo(400),
    );
    expect(
      (await b.f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': b.f.orgId, 'band': b.f.id},
      )).status,
      greaterThanOrEqualTo(400),
    );
    expect((await view('bands', b.f.id))['name'], 'The Band');
    // Deleting again changes nothing.
    expect((await b.f.admin.delete('bands', b.f.id)).status, 404);
  });

  test('restoring brings back what went with the band', () async {
    final b = await setUpBand();
    (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
    final r = await b.f.admin.patch('bands', b.f.id, {'deleted': false});
    r.expectStatus(200);
    expect(r.json['deleted'], isFalse);
    expect(r.json['deleted_at'], isEmpty);

    final set = await view('setlists', b.set);
    expect(set['deleted'], isFalse);
    expect(set['deleted_at'], isEmpty);
    expect((await view('arrangements', b.arrangement))['deleted'], isFalse);
    for (final user in [b.f.admin, b.f.member, b.leader]) {
      expect((await b.f.membershipOf(user))['deleted'], isFalse);
    }
    // Deleted before the band: stays deleted. Invitations stay revoked.
    expect((await view('setlists', b.oldSet))['deleted'], isTrue);
    expect((await view('invites', b.invite))['revoked'], isTrue);
    expect((await b.f.member.view('bands', b.f.id)).status, 200);
  });

  test('people who left the organization meanwhile stay out', () async {
    final b = await setUpBand();
    (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
    final org = (await pb.superuser.list(
      'org_memberships',
      filter: 'organization = "${b.f.orgId}" && user = "${b.f.member.id}"',
    )).single;
    (await b.f.member.patch('org_memberships', org['id'] as String, {
      'deleted': true,
    })).expectStatus(200);
    (await b.f.admin.patch('bands', b.f.id, {
      'deleted': false,
    })).expectStatus(200);
    expect((await b.f.membershipOf(b.f.member))['deleted'], isTrue);
    expect((await b.f.membershipOf(b.leader))['deleted'], isFalse);
  });

  test('only organization admins delete and restore bands', () async {
    final b = await setUpBand();
    final g = await BandFixture.create(pb);
    final planner = await b.f.addPlanner();
    final librarian = await pb.signUp('Librarian');
    await BandFixture.addOrgMember(pb, b.f.orgId, librarian, role: 'librarian');
    for (final user in [b.leader, planner, b.f.member, librarian, g.admin]) {
      expect(
        (await user.delete('bands', b.f.id)).status,
        greaterThanOrEqualTo(400),
      );
      expect(
        (await user.patch('bands', b.f.id, {'deleted': true})).status,
        greaterThanOrEqualTo(400),
      );
    }
    expect((await view('bands', b.f.id))['deleted'], isFalse);
    // Not even organization admins delete by PATCH (#627).
    expect(
      (await b.f.admin.patch('bands', b.f.id, {'deleted': true})).status,
      greaterThanOrEqualTo(400),
    );

    (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
    for (final user in [b.leader, planner, b.f.member, librarian, g.admin]) {
      expect(
        (await user.patch('bands', b.f.id, {'deleted': false})).status,
        greaterThanOrEqualTo(400),
      );
    }
    expect((await view('bands', b.f.id))['deleted'], isTrue);
    // The server sets the trash fields.
    expect(
      (await b.f.admin.patch('bands', b.f.id, {
        'deleted': false,
        'purged': true,
      })).status,
      greaterThanOrEqualTo(400),
    );
  });

  test('superusers delete through the trash too', () async {
    final b = await setUpBand();
    expect((await pb.superuser.delete('bands', b.f.id)).status, 204);
    final band = await view('bands', b.f.id);
    expect(band['deleted'], isTrue);
    expect(band['deleted_at'], isNotEmpty);
    expect((await view('setlists', b.set))['deleted'], isTrue);
  });

  group('purge', () {
    Future<void> ageBand(String bandId, int days) async {
      final at = DateTime.now()
          .toUtc()
          .subtract(Duration(days: days))
          .toIso8601String()
          .replaceFirst('T', ' ');
      final before = (await view('bands', bandId))['deleted_at'];
      (await pb.superuser.patch('bands', bandId, {
        'deleted_at': at,
      })).expectStatus(200);
      for (final set in await pb.superuser.list(
        'setlists',
        filter: 'band = "$bandId" && deleted_at = "$before"',
      )) {
        (await pb.superuser.patch('setlists', set['id'] as String, {
          'deleted_at': at,
        })).expectStatus(200);
      }
    }

    test('after 30 days the band is purged and cannot be restored', () async {
      final b = await setUpBand();
      (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
      await ageBand(b.f.id, 31);
      (await pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
      )).expectStatus(200);

      final band = await view('bands', b.f.id);
      expect(band['purged'], isTrue);
      final set = await view('setlists', b.set);
      expect(set['purged'], isTrue);
      expect(set['items'], isEmpty);
      expect(
        await pb.superuser.list('memberships', filter: 'band = "${b.f.id}"'),
        isEmpty,
      );
      expect(
        await pb.superuser.list('arrangements', filter: 'band = "${b.f.id}"'),
        isEmpty,
      );
      expect(
        (await b.f.admin.patch('bands', b.f.id, {'deleted': false})).status,
        greaterThanOrEqualTo(400),
      );
    });

    test('bands deleted less than 30 days ago stay', () async {
      final b = await setUpBand();
      (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
      await ageBand(b.f.id, 29);
      (await pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
      )).expectStatus(200);
      expect((await view('bands', b.f.id))['purged'], isFalse);
    });

    test('operators purge one band at once', () async {
      final b = await setUpBand();
      final live = await pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
        body: {'collection': 'bands', 'id': b.f.id},
      );
      expect(live.status, 400);
      (await b.f.admin.delete('bands', b.f.id)).expectStatus(204);
      expect(
        (await b.f.admin.send(
          'POST',
          '/api/setding/trash/purge',
          body: {'collection': 'bands', 'id': b.f.id},
        )).status,
        anyOf(401, 403),
      );
      final r = await pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
        body: {'collection': 'bands', 'id': b.f.id},
      );
      r.expectStatus(200);
      expect(r.json['purged'], 2);
      expect((await view('bands', b.f.id))['purged'], isTrue);
      expect((await view('setlists', b.set))['purged'], isTrue);
    });
  });
}
