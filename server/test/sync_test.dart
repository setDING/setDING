import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:realchord_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;
  late BandFixture band;

  setUpAll(() async {
    pb = await PocketBase.start();
    band = await BandFixture.create(pb);
  });
  tearDownAll(() => pb.stop());

  test('accepts client-generated UUIDs and rejects other IDs', () async {
    final id = uuid();
    final song = await band.admin.post('songs', {
      'id': id,
      'organization': band.orgId,
      'title': 'With UUID',
    });
    song.expectStatus(200);
    expect(song.json['id'], id);

    final bad = await band.admin.post('songs', {
      'id': 'abc123',
      'organization': band.orgId,
      'title': 'Bad ID',
    });
    expect(bad.status, 400);
  });

  test('generates a UUID when the client sends no ID', () async {
    final song = await band.createSong(band.admin);
    final r = await band.admin.post('songs', {
      'organization': band.orgId,
      'title': 'No ID',
    });
    r.expectStatus(200);
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(r.json['id'], matches(pattern));
    expect(song['id'], matches(pattern));
  });

  test('assigns increasing server revisions on create and update', () async {
    final a = await band.createSong(band.admin, title: 'A');
    final b = await band.createSong(band.admin, title: 'B');
    expect(b['revision'], greaterThan(a['revision'] as int));

    final updated = await band.admin.patch('songs', a['id'] as String, {
      'title': 'A2',
      'revision': a['revision'],
    });
    updated.expectStatus(200);
    expect(updated.json['revision'], greaterThan(b['revision'] as int));
  });

  test('revision is shared across collections', () async {
    final song = await band.createSong(band.admin);
    final set = await band.admin.post('setlists', {
      'band': band.id,
      'name': 'Gig',
    });
    set.expectStatus(200);
    expect(set.json['revision'], greaterThan(song['revision'] as int));
  });

  test('clients cannot set revision or updated_by', () async {
    final r = await band.admin.post('songs', {
      'organization': band.orgId,
      'title': 'Forged',
      'revision': 999999,
      'updated_by': band.member.id,
    });
    r.expectStatus(200);
    expect(r.json['revision'], lessThan(999999));
    expect(r.json['updated_by'], band.admin.id);

    final set = await band.admin.post('setlists', {
      'band': band.id,
      'name': 'Forged',
    });
    final u = await band.admin.patch('setlists', set.json['id'] as String, {
      'revision': 1,
      'updated_by': band.member.id,
    });
    u.expectStatus(200);
    expect(u.json['revision'], greaterThan(set.json['revision'] as int));
    expect(u.json['updated_by'], band.admin.id);
  });

  test('records the author of each change in updated_by', () async {
    final pbEdit = await BandFixture.create(pb, membersCanEditSongs: true);
    final song = await pbEdit.createSong(pbEdit.admin);
    expect(song['updated_by'], pbEdit.admin.id);
    final r = await pbEdit.member.patch('songs', song['id'] as String, {
      'chordpro': '{title: Song}\n[D]Edited',
      'revision': song['revision'],
    });
    r.expectStatus(200);
    expect(r.json['updated_by'], pbEdit.member.id);
  });

  test('delta sync returns the changes since a revision', () async {
    final before = await band.createSong(band.admin, title: 'Before');
    final cursor = before['revision'] as int;
    final after = await band.createSong(band.admin, title: 'After');
    final deleted = await band.admin.patch('songs', before['id'] as String, {
      'deleted': true,
      'revision': before['revision'],
    });
    deleted.expectStatus(200);

    final changes = await band.member.list(
      'songs',
      filter: 'organization = "${band.orgId}" && revision > $cursor',
    );
    expect(changes.map((s) => s['id']), [after['id'], before['id']]);
    expect(changes.last['deleted'], isTrue);
  });

  test(
    'synced records cannot be hard-deleted, not even by superusers',
    () async {
      final song = await band.createSong(band.admin);
      final id = song['id'] as String;
      expect((await band.admin.delete('songs', id)).status, isNot(204));
      expect((await pb.superuser.delete('songs', id)).status, 400);
      expect((await band.admin.view('songs', id)).status, 200);
    },
  );
}
