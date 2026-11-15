import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:realchord_server/pocketbase_harness.dart';

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
    final f = await BandFixture.create(pb, membersCanEditSongs: true);
    final created = await f.member.post('songs', songBody(f.orgId));
    created.expectStatus(200);
    final r = await f.member.patch('songs', created.json['id'], {
      'title': 'Fixed typo',
      'revision': created.json['revision'],
    });
    r.expectStatus(200);
  });

  test('outsiders cannot add songs to a band', () async {
    final f = await BandFixture.create(pb, membersCanEditSongs: true);
    expect((await f.outsider.post('songs', songBody(f.orgId))).status, 400);
  });

  test('only admins delete songs', () async {
    final f = await BandFixture.create(pb, membersCanEditSongs: true);
    final song = await f.createSong(f.member);
    final byMember = await f.member.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    });
    expect(byMember.status, 404);
    final byAdmin = await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    });
    byAdmin.expectStatus(200);
    expect(byAdmin.json['deleted'], isTrue);
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
      final f = await BandFixture.create(pb, membersCanEditSongs: true);
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
