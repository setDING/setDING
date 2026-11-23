import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Lineup per set and substitutes (ADR-0061, #1007).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  const lineupPath = '/api/setding/lineup';
  String emailsPath(String set) => '/api/setding/lineup/$set/emails';

  Future<Map<String, dynamic>> stored(String id) async {
    final r = await pb.superuser.view('setlists', id);
    r.expectStatus(200);
    return r.json;
  }

  /// A person of the organization of [f] who is in none of its bands.
  Future<User> substituteOf(BandFixture f) async {
    final user = await pb.signUp('Substitute');
    await BandFixture.addOrgMember(pb, f.orgId, user);
    return user;
  }

  Future<String> createSet(
    BandFixture f,
    List<String> lineup, {
    List<Object?> items = const [],
    String name = 'Gig',
  }) async {
    final r = await f.admin.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': name,
      'items': items,
      'lineup': lineup,
      'lineup_custom': true,
    });
    r.expectStatus(200);
    return r.json['id'] as String;
  }

  Future<List<String>> substituteSetIds(User user) async {
    final r = await user.send('GET', lineupPath);
    r.expectStatus(200);
    return [for (final s in r.json['sets'] as List) (s as Map)['id'] as String];
  }

  group('lineup field', () {
    test('a set without its own lineup stores nobody', () async {
      final f = await BandFixture.create(pb);
      final r = await f.admin.post('setlists', {
        'id': uuid(),
        'band': f.id,
        'name': 'Gig',
        'items': <dynamic>[],
        'lineup': [f.member.id],
      });
      r.expectStatus(200);
      final set = await stored(r.json['id'] as String);
      expect(set['lineup'], isEmpty);
      expect(set['lineup_custom'], isFalse);
    });

    test('band leaders and set planners choose band members and people of '
        'the organization', () async {
      final f = await BandFixture.create(pb);
      final planner = await f.addPlanner();
      final substitute = await substituteOf(f);
      final id = await createSet(f, [f.member.id]);
      (await planner.patch('setlists', id, {
        'lineup': [f.member.id, substitute.id],
        'lineup_custom': true,
      })).expectStatus(200);
      expect(
        (await stored(id))['lineup'],
        unorderedEquals([f.member.id, substitute.id]),
      );

      // Back to the whole band.
      (await planner.patch('setlists', id, {
        'lineup_custom': false,
      })).expectStatus(200);
      expect((await stored(id))['lineup'], isEmpty);
    });

    test('people outside the organization are refused', () async {
      final f = await BandFixture.create(pb);
      final g = await BandFixture.create(pb);
      final id = await createSet(f, [f.member.id]);
      for (final person in [f.outsider, g.member]) {
        final r = await f.admin.patch('setlists', id, {
          'lineup': [f.member.id, person.id],
          'lineup_custom': true,
        });
        r.expectStatus(400);
        expect((await stored(id))['lineup'], [f.member.id]);
      }
      final created = await f.admin.post('setlists', {
        'id': uuid(),
        'band': f.id,
        'name': 'Gig',
        'items': <dynamic>[],
        'lineup': [f.outsider.id],
        'lineup_custom': true,
      });
      created.expectStatus(400);
    });

    test('somebody who left the organization does not block editing the '
        'set', () async {
      final f = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final id = await createSet(f, [substitute.id]);
      final m = await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${substitute.id}"',
      );
      (await pb.superuser.patch('org_memberships', m.single['id'] as String, {
        'deleted': true,
      })).expectStatus(200);
      (await f.admin.patch('setlists', id, {
        'name': 'Renamed',
      })).expectStatus(200);
      // Adding them back is refused while they are not in the organization.
      (await f.admin.patch('setlists', id, {
        'lineup': <String>[],
        'lineup_custom': true,
      })).expectStatus(200);
      (await f.admin.patch('setlists', id, {
        'lineup': [substitute.id],
        'lineup_custom': true,
      })).expectStatus(400);
    });

    test('a set saved without the lineup fields keeps its lineup (older '
        'apps)', () async {
      final f = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final id = await createSet(f, [substitute.id]);
      (await f.admin.patch('setlists', id, {
        'name': 'Renamed',
        'items': <dynamic>[],
      })).expectStatus(200);
      final set = await stored(id);
      expect(set['lineup'], [substitute.id]);
      expect(set['lineup_custom'], isTrue);
    });

    test(
      'a deleted account leaves the lineup without a new revision',
      () async {
        final f = await BandFixture.create(pb);
        final substitute = await substituteOf(f);
        final id = await createSet(f, [f.member.id, substitute.id]);
        final revision = (await stored(id))['revision'];
        (await substitute.send(
          'DELETE',
          '/api/collections/users/records/${substitute.id}',
          body: {'password': 'password-123'},
        )).expectStatus(204);
        final set = await stored(id);
        expect(set['lineup'], [f.member.id]);
        expect(set['revision'], revision);
      },
    );

    test('purging a set clears its lineup', () async {
      final f = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final id = await createSet(f, [substitute.id]);
      (await f.admin.patch('setlists', id, {
        'deleted': true,
      })).expectStatus(200);
      (await f.admin.patch('setlists', id, {'purged': true})).expectStatus(200);
      final set = await stored(id);
      expect(set['lineup'], isEmpty);
      expect(set['lineup_custom'], isFalse);
      expect(await substituteSetIds(substitute), isEmpty);
    });
  });

  group('substitute sets', () {
    test('a substitute gets their sets with the arrangements of their songs, '
        'the band name and the lineup names, nothing else', () async {
      final f = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final a = (await f.createSong(f.admin, title: 'A'))['id'] as String;
      final b = (await f.createSong(f.admin, title: 'B'))['id'] as String;
      for (final (song, transpose) in [(a, 2), (b, -1)]) {
        (await f.admin.post('arrangements', {
          'id': uuid(),
          'band': f.id,
          'song': song,
          'transpose': transpose,
        })).expectStatus(200);
      }
      final gig = await createSet(
        f,
        [f.member.id, substitute.id],
        items: [
          {'id': uuid(), 'type': 'song', 'song': a},
        ],
      );
      await createSet(f, [f.member.id], name: 'Without them');
      (await f.admin.post('setlists', {
        'id': uuid(),
        'band': f.id,
        'name': 'Whole band',
        'items': <dynamic>[],
      })).expectStatus(200);

      final r = await substitute.send('GET', lineupPath);
      r.expectStatus(200);
      final sets = (r.json['sets'] as List).cast<Map<String, dynamic>>();
      expect([for (final s in sets) s['id']], [gig]);
      expect(sets.single['items'], isNotEmpty);
      expect(r.json['bands'], [
        {'id': f.id, 'name': 'The Band', 'organization': f.orgId},
      ]);
      final arrangements = (r.json['arrangements'] as List)
          .cast<Map<String, dynamic>>();
      expect([for (final x in arrangements) x['song']], [a]);
      expect(arrangements.single['transpose'], 2);
      final people = (r.json['people'] as List).cast<Map<String, dynamic>>();
      expect([
        for (final p in people) p['id'],
      ], unorderedEquals([f.member.id, substitute.id]));
      final body = jsonEncode(r.json);
      expect(body, isNot(contains('@setding.test')));
      expect(body, isNot(contains('Without them')));
      expect(body, isNot(contains('Whole band')));

      // Still not through the records API.
      expect((await substitute.view('setlists', gig)).status, 404);
      expect(await substitute.list('arrangements'), isEmpty);
    });

    test('removing them, the whole band, deleting the set or the band, '
        'leaving the organization end the access', () async {
      final f = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final removed = await createSet(f, [substitute.id]);
      final reset = await createSet(f, [substitute.id]);
      final deleted = await createSet(f, [substitute.id]);
      final kept = await createSet(f, [substitute.id]);
      expect(
        await substituteSetIds(substitute),
        unorderedEquals([removed, reset, deleted, kept]),
      );
      (await f.admin.patch('setlists', removed, {
        'lineup': <String>[],
        'lineup_custom': true,
      })).expectStatus(200);
      (await f.admin.patch('setlists', reset, {
        'lineup_custom': false,
      })).expectStatus(200);
      (await f.admin.patch('setlists', deleted, {
        'deleted': true,
      })).expectStatus(200);
      expect(await substituteSetIds(substitute), [kept]);

      final m = await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "${f.orgId}" && user = "${substitute.id}"',
      );
      (await pb.superuser.patch('org_memberships', m.single['id'] as String, {
        'deleted': true,
      })).expectStatus(200);
      expect(await substituteSetIds(substitute), isEmpty);

      final g = await BandFixture.create(pb);
      final other = await substituteOf(g);
      await createSet(g, [other.id]);
      (await g.admin.delete('bands', g.id)).expectStatus(204);
      expect(await substituteSetIds(other), isEmpty);
    });

    test('band members and organization admins get their sets through the '
        'records API, not as substitutes', () async {
      final f = await BandFixture.create(pb);
      await createSet(f, [f.member.id, f.admin.id]);
      expect(await substituteSetIds(f.member), isEmpty);
      expect(await substituteSetIds(f.admin), isEmpty);
      expect(await substituteSetIds(f.outsider), isEmpty);
      expect((await pb.guest.send('GET', lineupPath)).status, 401);
    });
  });

  group('lineup mail addresses', () {
    test(
      'set editors get the addresses of the lineup or of the whole band',
      () async {
        final f = await BandFixture.create(pb);
        final planner = await f.addPlanner();
        final substitute = await substituteOf(f);
        final custom = await createSet(f, [substitute.id]);
        final whole = await f.admin.post('setlists', {
          'id': uuid(),
          'band': f.id,
          'name': 'Whole band',
          'items': <dynamic>[],
        });
        whole.expectStatus(200);

        for (final user in [f.admin, planner]) {
          final r = await user.send('GET', emailsPath(custom));
          r.expectStatus(200);
          final people = (r.json['people'] as List)
              .cast<Map<String, dynamic>>();
          expect([for (final p in people) p['id']], [substitute.id]);
          expect(people.single['email'], contains('@'));
        }
        final r = await f.admin.send(
          'GET',
          emailsPath(whole.json['id'] as String),
        );
        r.expectStatus(200);
        expect([
          for (final p in r.json['people'] as List) (p as Map)['id'],
        ], unorderedEquals([f.admin.id, f.member.id, planner.id]));
      },
    );

    test('everyone else gets nothing', () async {
      final f = await BandFixture.create(pb);
      final g = await BandFixture.create(pb);
      final substitute = await substituteOf(f);
      final librarian = await pb.signUp('Librarian');
      await BandFixture.addOrgMember(pb, f.orgId, librarian, role: 'librarian');
      final id = await createSet(f, [f.member.id, substitute.id]);
      for (final user in [
        f.member,
        substitute,
        librarian,
        f.outsider,
        g.admin,
      ]) {
        final r = await user.send('GET', emailsPath(id));
        expect(r.status, 404);
        expect(r.raw.body, isNot(contains('@setding.test')));
      }
      expect((await pb.guest.send('GET', emailsPath(id))).status, 401);
      (await f.admin.patch('setlists', id, {
        'deleted': true,
      })).expectStatus(200);
      expect((await f.admin.send('GET', emailsPath(id))).status, 404);
      expect((await f.admin.send('GET', emailsPath('nope'))).status, 404);
    });
  });
}
