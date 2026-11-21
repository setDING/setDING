import 'package:test/test.dart';

import 'support/fixtures.dart';

import 'package:setding_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  test('admins manage sets with their items as one record', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final items = [
      {'id': uuid(), 'type': 'song', 'song': song['id'], 'transpose': 2},
      {'id': uuid(), 'type': 'pause', 'note': 'Break'},
    ];
    final created = await f.admin.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': 'Summer gig',
      'gig_date': '2027-06-21 20:00:00.000Z',
      'venue': 'Bern',
      'items': items,
    });
    created.expectStatus(200);
    expect(created.json['items'], items);

    final reordered = await f.admin.patch('setlists', created.json['id'], {
      'items': items.reversed.toList(),
    });
    reordered.expectStatus(200);
    final seen = await f.member.view('setlists', created.json['id']);
    expect(seen.json['items'], items.reversed.toList());
  });

  test('the origin of an imported set is stored and kept on updates '
      'without it (#707)', () async {
    final f = await BandFixture.create(pb);
    final origin = uuid();
    final created = await f.admin.post('setlists', {
      'band': f.id,
      'name': 'Imported',
      'origin': origin,
    });
    created.expectStatus(200);
    expect(created.json['origin'], origin);
    // Apps before the field send updates without it.
    final renamed = await f.admin.patch('setlists', created.json['id'], {
      'name': 'Renamed',
    });
    renamed.expectStatus(200);
    expect(renamed.json['origin'], origin);
    final seen = await f.member.view('setlists', created.json['id']);
    expect(seen.json['origin'], origin);
  });

  test('sets use last writer wins (no base revision needed)', () async {
    final f = await BandFixture.create(pb);
    final second = await pb.signUp();
    await BandFixture.addMember(pb, f.id, second, role: 'admin');
    final set = await f.admin.post('setlists', {'band': f.id, 'name': 'A'});
    (await f.admin.patch('setlists', set.json['id'], {
      'name': 'B',
    })).expectStatus(200);
    final last = await second.patch('setlists', set.json['id'], {
      'name': 'C',
      'revision': set.json['revision'],
    });
    last.expectStatus(200);
    expect(last.json['name'], 'C');
  });

  test('members only read sets', () async {
    final f = await BandFixture.create(pb, memberIsLibrarian: true);
    final byMember = await f.member.post('setlists', {
      'band': f.id,
      'name': 'Mine',
    });
    expect(byMember.status, 400);
    final set = await f.admin.post('setlists', {'band': f.id, 'name': 'Gig'});
    expect((await f.member.view('setlists', set.json['id'])).status, 200);
    final edit = await f.member.patch('setlists', set.json['id'], {
      'name': 'Renamed',
    });
    expect(edit.status, 404);
    final delete = await f.member.patch('setlists', set.json['id'], {
      'deleted': true,
    });
    expect(delete.status, 404);
  });

  test('set planners manage sets, not the band (ADR-0023)', () async {
    final f = await BandFixture.create(pb);
    final planner = await f.addPlanner();
    final set = await planner.post('setlists', {'band': f.id, 'name': 'Gig'});
    set.expectStatus(200);
    (await planner.patch('setlists', set.json['id'] as String, {
      'name': 'Big gig',
    })).expectStatus(200);
    (await planner.patch('setlists', set.json['id'] as String, {
      'deleted': true,
    })).expectStatus(200);
    expect((await planner.patch('bands', f.id, {'name': 'Mine'})).status, 404);
    final membership = await f.membershipOf(f.member);
    final promote = await planner.patch(
      'memberships',
      membership['id'] as String,
      {'role': 'admin'},
    );
    expect(promote.status, 404);
  });

  test('leaders who are no organization admin manage sets', () async {
    final f = await BandFixture.create(pb);
    final leader = await f.addLeader();
    (await leader.post('setlists', {
      'band': f.id,
      'name': 'Gig',
    })).expectStatus(200);
  });

  test('outsiders neither see nor create sets', () async {
    final f = await BandFixture.create(pb);
    final set = await f.admin.post('setlists', {'band': f.id, 'name': 'Gig'});
    expect((await f.outsider.view('setlists', set.json['id'])).status, 404);
    final r = await f.outsider.post('setlists', {'band': f.id, 'name': 'X'});
    expect(r.status, 400);
  });

  test('sets cannot be moved to another band', () async {
    final f = await BandFixture.create(pb);
    final other = await BandFixture.create(pb);
    await BandFixture.addMember(pb, other.id, f.admin, role: 'admin');
    final set = await f.admin.post('setlists', {'band': f.id, 'name': 'Gig'});
    final r = await f.admin.patch('setlists', set.json['id'], {
      'band': other.id,
    });
    expect(r.status, isNot(200));
  });

  group('song play history (ADR-0046)', () {
    test('an older app saving a set keeps how its songs were played', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final played = {'key': 'D', 'tempo': 96};
      final frozen = {
        'id': uuid(),
        'type': 'song',
        'song': song['id'],
        'played': played,
      };
      final changed = {
        'id': uuid(),
        'type': 'song',
        'song': song['id'],
        'played': {'key': 'E'},
      };
      final set = await f.admin.post('setlists', {
        'band': f.id,
        'name': 'Last week',
        'gig_date': '2026-11-13 00:00:00.000Z',
        'items': [frozen, changed],
      });
      set.expectStatus(200);

      // An app before 0.17.0 sends the items without `played`; a newer one
      // sends a corrected value, and a new item has none.
      final added = {'id': uuid(), 'type': 'song', 'song': song['id']};
      final saved = await f.admin.patch('setlists', set.json['id'], {
        'name': 'Renamed',
        'items': [
          {'id': frozen['id'], 'type': 'song', 'song': song['id']},
          {
            ...changed,
            'played': {'key': 'F'},
          },
          added,
        ],
      });
      saved.expectStatus(200);
      final items =
          (await f.member.view('setlists', set.json['id'])).json['items']
              as List;
      expect((items[0] as Map)['played'], played);
      expect((items[1] as Map)['played'], {'key': 'F'});
      expect((items[2] as Map).containsKey('played'), isFalse);
    });

    test('members and outsiders still cannot change a set', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final item = {
        'id': uuid(),
        'type': 'song',
        'song': song['id'],
        'played': {'key': 'D'},
      };
      final set = await f.admin.post('setlists', {
        'band': f.id,
        'name': 'Gig',
        'items': [item],
      });
      for (final user in [f.member, f.outsider]) {
        final r = await user.patch('setlists', set.json['id'], {
          'items': [
            {'id': item['id'], 'type': 'song', 'song': song['id']},
            {'id': uuid(), 'type': 'pause'},
          ],
        });
        expect(r.status, anyOf(400, 403, 404));
      }
      final stored = await f.admin.view('setlists', set.json['id']);
      expect(stored.json['items'], [item]);
    });
  });
}
