import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Language versions of a song (ADR-0053, #804): the group ID and the
/// language are last writer wins per field and never part of the conflict
/// check; `content_revision` follows the other fields.
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> view(Client c, String id) async {
    final r = await c.view('songs', id);
    r.expectStatus(200);
    return r.json;
  }

  test('a new song has its revision as content revision', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    expect(song['content_revision'], song['revision']);
    expect(song['work_id'], '');
    expect(song['language'], '');
  });

  test('songs are created with a group and a language', () async {
    final f = await BandFixture.create(pb);
    final work = uuid();
    final r = await f.admin.post('songs', {
      'id': uuid(),
      'organization': f.orgId,
      'title': 'Song',
      'work_id': work,
      'language': 'gsw',
    });
    r.expectStatus(200);
    expect(r.json['work_id'], work);
    expect(r.json['language'], 'gsw');
  });

  test(
    'linking needs no base revision and keeps the content revision',
    () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final work = uuid();
      final r = await f.admin.patch('songs', song['id'] as String, {
        'work_id': work,
        'language': 'en',
      });
      r.expectStatus(200);
      expect(r.json['work_id'], work);
      expect(r.json['language'], 'en');
      expect(r.json['revision'], greaterThan(song['revision'] as int));
      expect(r.json['content_revision'], song['content_revision']);

      final cleared = await f.admin.patch('songs', song['id'] as String, {
        'work_id': '',
        'language': '',
      });
      cleared.expectStatus(200);
      expect(cleared.json['work_id'], '');
      expect(cleared.json['language'], '');
    },
  );

  test(
    'a text change based on a revision before a link is no conflict',
    () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      (await f.member.patch('songs', song['id'] as String, {
        'work_id': uuid(),
      })).expectStatus(200);
      final r = await f.admin.patch('songs', song['id'] as String, {
        'chordpro': '{title: Song}\nChanged',
        'revision': song['revision'],
      });
      r.expectStatus(200);
      expect(r.json['content_revision'], r.json['revision']);
      // The link of the librarian stays.
      expect(r.json['work_id'], isNotEmpty);
    },
  );

  test(
    'a text change based on an older content revision is a conflict',
    () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      (await f.member.patch('songs', song['id'] as String, {
        'chordpro': '{title: Song}\nMember',
        'revision': song['revision'],
      })).expectStatus(200);
      final r = await f.admin.patch('songs', song['id'] as String, {
        'chordpro': '{title: Song}\nAdmin',
        'revision': song['revision'],
      });
      expect(r.status, 409);
      expect(
        (await view(f.admin, song['id'] as String))['chordpro'],
        contains('Member'),
      );
    },
  );

  test(
    'linking keeps the last editor: leaders still edit their own songs',
    () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final leader = await f.addLeader();
      final song = await f.createSong(leader);
      final linked = await f.member.patch('songs', song['id'] as String, {
        'work_id': uuid(),
      });
      linked.expectStatus(200);
      expect(linked.json['updated_by'], leader.id);
      final r = await leader.patch('songs', song['id'] as String, {
        'title': 'Still mine',
        'revision': linked.json['revision'],
      });
      r.expectStatus(200);
    },
  );

  test('leaders link their own songs', () async {
    final f = await BandFixture.create(pb);
    final leader = await f.addLeader();
    final song = await f.createSong(leader);
    (await leader.patch('songs', song['id'] as String, {
      'language': 'de',
    })).expectStatus(200);
  });

  test('invalid group IDs and languages are refused', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    for (final body in [
      {'work_id': 'not-a-uuid'},
      {'language': 'xx'},
      {'language': 'DE'},
    ]) {
      final r = await f.admin.patch('songs', song['id'] as String, body);
      expect(r.status, 400, reason: '$body');
    }
    final stored = await view(f.admin, song['id'] as String);
    expect(stored['work_id'], '');
    expect(stored['language'], '');
  });

  test('a group of another organization is refused', () async {
    final f = await BandFixture.create(pb);
    final g = await BandFixture.create(pb);
    final work = uuid();
    final theirs = await g.createSong(g.admin);
    (await g.admin.patch('songs', theirs['id'] as String, {
      'work_id': work,
    })).expectStatus(200);

    final song = await f.createSong(f.admin);
    final r = await f.admin.patch('songs', song['id'] as String, {
      'work_id': work,
    });
    expect(r.status, 400);
    expect((await view(f.admin, song['id'] as String))['work_id'], '');
    final created = await f.admin.post('songs', {
      'id': uuid(),
      'organization': f.orgId,
      'title': 'New',
      'work_id': work,
    });
    expect(created.status, 400);
  });

  test('clients cannot set the content revision', () async {
    final f = await BandFixture.create(pb);
    final created = await f.admin.post('songs', {
      'id': uuid(),
      'organization': f.orgId,
      'title': 'Song',
      'content_revision': 1,
    });
    created.expectStatus(200);
    expect(created.json['content_revision'], created.json['revision']);
    final r = await f.admin.patch('songs', created.json['id'] as String, {
      'title': 'Changed',
      'content_revision': 1,
      'revision': created.json['revision'],
    });
    r.expectStatus(200);
    expect(r.json['content_revision'], r.json['revision']);
  });

  test('the delta pull carries a link change', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final cursor = song['revision'] as int;
    (await f.admin.patch('songs', song['id'] as String, {
      'language': 'fr',
    })).expectStatus(200);
    final changed = await f.member.list(
      'songs',
      filter: 'organization = "${f.orgId}" && revision > $cursor',
    );
    expect(changed.single['language'], 'fr');
  });
}
