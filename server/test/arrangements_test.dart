import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Band arrangements (ADR-0025).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Response> create(
    Client client,
    BandFixture f,
    String songId, {
    int transpose = 3,
  }) => client.post('arrangements', {
    'id': uuid(),
    'band': f.id,
    'song': songId,
    'transpose': transpose,
    'sequence': 'V1 C V2 C',
    'tempo': 96,
  });

  test('leaders, set planners and organization admins maintain them', () async {
    final f = await BandFixture.create(pb);
    final leader = await f.addLeader();
    final planner = await f.addPlanner();
    final song = await f.createSong(f.admin);

    final byLeader = await create(leader, f, song['id'] as String);
    byLeader.expectStatus(200);
    expect(byLeader.json['transpose'], 3);
    expect(byLeader.json['revision'], greaterThan(0));
    final byPlanner = await planner.patch(
      'arrangements',
      byLeader.json['id'] as String,
      {'tempo': 120, 'sequence': ''},
    );
    byPlanner.expectStatus(200);
    expect(byPlanner.json['tempo'], 120);
    (await f.admin.patch('arrangements', byLeader.json['id'] as String, {
      'deleted': true,
    })).expectStatus(200);
  });

  test('members only read them; outsiders see nothing', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final arrangement = await create(f.admin, f, song['id'] as String);
    arrangement.expectStatus(200);
    final id = arrangement.json['id'] as String;

    expect((await f.member.view('arrangements', id)).status, 200);
    expect(
      (await f.member.patch('arrangements', id, {'transpose': 5})).status,
      404,
    );
    expect((await create(f.member, f, song['id'] as String)).status, 400);
    expect((await f.outsider.view('arrangements', id)).status, 404);

    // Organization members of another band do not see it either.
    final other = await pb.signUp('Other');
    await BandFixture.addOrgMember(pb, f.orgId, other);
    expect((await other.view('arrangements', id)).status, 404);
  });

  test('one per band and song; band and song cannot be changed', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final second = await f.createSong(f.admin, title: 'Second');
    final first = await create(f.admin, f, song['id'] as String);
    first.expectStatus(200);
    expect((await create(f.admin, f, song['id'] as String)).status, 400);
    final moved = await f.admin.patch(
      'arrangements',
      first.json['id'] as String,
      {'song': second['id']},
    );
    expect(moved.status, isNot(200));
  });

  test('only songs of the band\'s organization', () async {
    final f = await BandFixture.create(pb);
    final other = await BandFixture.create(pb);
    final foreign = await other.createSong(other.admin);
    await BandFixture.addOrgMember(pb, other.orgId, f.admin);
    expect((await create(f.admin, f, foreign['id'] as String)).status, 400);
  });

  test('values stay in range', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    expect(
      (await create(f.admin, f, song['id'] as String, transpose: 12)).status,
      400,
    );
  });

  test('deleting a song deletes its arrangements', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final arrangement = await create(f.admin, f, song['id'] as String);
    (await f.admin.patch('songs', song['id'] as String, {
      'deleted': true,
      'revision': song['revision'],
    })).expectStatus(200);
    final stored = await f.admin.view(
      'arrangements',
      arrangement.json['id'] as String,
    );
    expect(stored.json['deleted'], isTrue);
    expect(
      stored.json['revision'] as int,
      greaterThan(arrangement.json['revision'] as int),
    );
  });

  test('restoring a song restores its arrangements', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final arrangement = await create(f.admin, f, song['id'] as String);
    final deleted = await f.admin.patch('songs', song['id'] as String, {
      'deleted': true,
      'revision': song['revision'],
    });
    deleted.expectStatus(200);
    (await f.admin.patch('songs', song['id'] as String, {
      'deleted': false,
      'revision': deleted.json['revision'],
    })).expectStatus(200);
    final stored = await f.admin.view(
      'arrangements',
      arrangement.json['id'] as String,
    );
    expect(stored.json['deleted'], isFalse);
    expect(stored.json['transpose'], 3);
  });

  test('synced records cannot be hard-deleted', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final arrangement = await create(f.admin, f, song['id'] as String);
    final r = await f.admin.delete(
      'arrangements',
      arrangement.json['id'] as String,
    );
    expect(r.status, isNot(200));
  });
}
