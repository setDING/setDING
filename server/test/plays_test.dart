import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Plays of the songs across the bands of an organization (ADR-0046, #662).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  String path(String org) => '/api/setding/plays/$org';

  Map<String, dynamic> song(String id, {String? key}) => {
    'id': uuid(),
    'type': 'song',
    'song': id,
    if (key != null) 'played': {'key': key, 'tempo': 90},
  };

  test('members of the organization see how every band played its songs, '
      'without the sets', () async {
    final f = await BandFixture.create(pb);
    final a = (await f.createSong(f.admin, title: 'A'))['id'] as String;
    final b = (await f.createSong(f.admin, title: 'B'))['id'] as String;
    final jazz = await f.admin.post('bands', {
      'name': 'Jazz',
      'organization': f.orgId,
    });
    jazz.expectStatus(200);
    final jazzId = jazz.json['id'] as String;
    Future<void> gig(
      String band,
      String name,
      String? date,
      List<Object?> items, {
      bool deleted = false,
    }) async {
      final r = await f.admin.post('setlists', {
        'id': uuid(),
        'band': band,
        'name': name,
        'gig_date': ?date,
        'items': items,
      });
      r.expectStatus(200);
      if (deleted) {
        (await f.admin.patch('setlists', r.json['id'] as String, {
          'deleted': true,
        })).expectStatus(200);
      }
    }

    await gig(f.id, 'Winter ball', '2026-01-10 00:00:00.000Z', [
      song(a, key: 'D'),
      song(a, key: 'D'),
      song(b),
      {'id': uuid(), 'type': 'pause'},
    ]);
    await gig(f.id, 'Spring fair', '2026-03-01 00:00:00.000Z', [
      song(a, key: 'E'),
    ]);
    await gig(f.id, 'Far future', '2099-01-01 00:00:00.000Z', [song(a)]);
    await gig(f.id, 'Undated', null, [song(a)]);
    await gig(f.id, 'Deleted', '2026-02-01 00:00:00.000Z', [
      song(a),
    ], deleted: true);
    await gig(jazzId, 'Jazz night', '2025-05-05 00:00:00.000Z', [song(a)]);

    final r = await f.member.send('GET', path(f.orgId));
    r.expectStatus(200);
    final plays = {
      for (final p in (r.json['plays'] as List).cast<Map<String, dynamic>>())
        '${p['song']}|${p['band']}': p,
    };
    expect(
      plays.keys,
      unorderedEquals(['$a|${f.id}', '$b|${f.id}', '$a|$jazzId']),
    );
    final aBand = plays['$a|${f.id}']!;
    expect(aBand['count'], 2);
    expect(aBand['last'], startsWith('2026-03-01'));
    expect(aBand['key'], 'E');
    expect(aBand['bandName'], 'The Band');
    expect(plays['$b|${f.id}']!['key'], isNull);
    expect(plays['$a|$jazzId']!['count'], 1);
    expect(plays['$a|$jazzId']!['bandName'], 'Jazz');
    // Nothing of the sets themselves.
    final body = jsonEncode(r.json);
    for (final name in ['Winter ball', 'Spring fair', 'Jazz night']) {
      expect(body, isNot(contains(name)));
    }

    // A deleted band takes its plays with it (ADR-0044).
    (await f.admin.delete('bands', jazzId)).expectStatus(204);
    final after = await f.member.send('GET', path(f.orgId));
    expect([
      for (final p in after.json['plays'] as List) (p as Map)['band'],
    ], everyElement(f.id));
  });

  test('people outside the organization get nothing', () async {
    final f = await BandFixture.create(pb);
    final g = await BandFixture.create(pb);
    final a = (await f.createSong(f.admin))['id'] as String;
    (await f.admin.post('setlists', {
      'band': f.id,
      'name': 'Gig',
      'gig_date': '2026-01-10 00:00:00.000Z',
      'items': [song(a, key: 'D')],
    })).expectStatus(200);

    for (final user in [f.outsider, g.admin, g.member]) {
      expect((await user.send('GET', path(f.orgId))).status, 404);
    }
    expect((await pb.guest.send('GET', path(f.orgId))).status, 401);
    expect((await f.member.send('GET', path('does-not-exist'))).status, 404);
  });
}
