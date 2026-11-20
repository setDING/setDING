import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// List filters of clients must not reveal records the client cannot see:
/// neither through joins of other collections (`@collection.*`) nor through
/// relation and back-relation paths (`memberships_via_user.band.name`). The
/// result of a probe must not depend on data of another organization, on
/// personal data of other people or on hidden fields (issue #618, ADR-0017).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Response> list(Client client, String collection, String filter) =>
      client.send(
        'GET',
        Uri(
          path: '/api/collections/$collection/records',
          queryParameters: {'perPage': '500', 'filter': filter},
        ).toString(),
      );

  /// The IDs a filtered list returns, or null when the server refuses the
  /// filter (which reveals nothing either).
  Future<Set<String>?> probe(
    Client client,
    String collection,
    String filter,
  ) async {
    final r = await list(client, collection, filter);
    if (r.status != 200) return null;
    return {
      for (final item in (r.json['items'] as List).cast<Map<String, dynamic>>())
        item['id'] as String,
    };
  }

  /// Probes [collection] with a condition that matches a real value and one
  /// that matches nothing; both must give the same answer.
  Future<void> expectNoLeak(
    Client attacker,
    String collection,
    String Function(String value) condition,
    String real,
  ) async {
    final hit = await probe(attacker, collection, condition(real));
    final miss = await probe(attacker, collection, condition('none-$real'));
    expect(hit, miss, reason: '${condition(real)} on $collection reveals data');
  }

  late BandFixture a;
  late BandFixture b;

  /// A person in both organizations: the bridge a probe could cross.
  late User both;
  late String marker;

  setUp(() async {
    a = await BandFixture.create(pb);
    b = await BandFixture.create(pb);
    marker = 'secret-${uuid()}';
    both = await pb.signUp('Both');
    await BandFixture.addMember(pb, a.id, both);
    await BandFixture.addOrgMember(pb, b.orgId, both, role: 'librarian');
    await BandFixture.addMember(pb, b.id, both);
    await b.createSong(both, title: marker);
    (await pb.superuser.patch('organizations', b.orgId, {
      'name': marker,
    })).expectStatus(200);
    (await pb.superuser.patch('bands', b.id, {
      'name': marker,
    })).expectStatus(200);
    (await both.post('user_settings', {
      'id': uuid(),
      'user': both.id,
      'data': {'note': marker},
    })).expectStatus(200);
  });

  test('clients cannot join other collections at all', () async {
    for (final filter in [
      '@collection.songs.title ?= "$marker"',
      '@collection.memberships.user ?= @request.auth.id',
    ]) {
      expect((await list(a.member, 'bands', filter)).status, 403);
    }
  });

  test('relation filters work on data the client can see (control)', () async {
    final hit = await probe(
      a.member,
      'users',
      'memberships_via_user.band ?= "${a.id}"',
    );
    expect(hit, containsAll([a.member.id, both.id]));
    expect(
      await probe(a.member, 'users', 'memberships_via_user.band ?= "none"'),
      isEmpty,
    );
  });

  group('a shared person does not open the other organization', () {
    final paths = <String, String Function(String)>{
      'band memberships': (v) => 'memberships_via_user.band.name ?= "$v"',
      'organization memberships': (v) =>
          'org_memberships_via_user.organization.name ?= "$v"',
      'songs they edited': (v) => 'songs_via_updated_by.title ?= "$v"',
      'personal settings': (v) => 'user_settings_via_user.data ?~ "$v"',
    };
    paths.forEach((name, condition) {
      test(name, () => expectNoLeak(a.member, 'users', condition, marker));
    });

    test('band and organization IDs', () async {
      await expectNoLeak(
        a.member,
        'users',
        (v) => 'memberships_via_user.band ?= "$v"',
        b.id,
      );
      await expectNoLeak(
        a.member,
        'users',
        (v) => 'org_memberships_via_user.organization ?= "$v"',
        b.orgId,
      );
    });
  });

  test('hidden emails stay hidden, also through relations', () async {
    await a.createSong(a.admin);
    final email =
        (await pb.superuser.view('users', a.admin.id)).json['email'] as String;
    await expectNoLeak(a.member, 'users', (v) => 'email = "$v"', email);
    await expectNoLeak(
      a.member,
      'songs',
      (v) => 'updated_by.email = "$v"',
      email,
    );
    await expectNoLeak(
      a.member,
      'bands',
      (v) => 'memberships_via_band.user.email ?= "$v"',
      email,
    );
  });

  test('hidden invitation fields cannot be probed', () async {
    final link = await b.admin.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': b.orgId},
    );
    link.expectStatus(200);
    final stored = await pb.superuser.view(
      'invites',
      link.json['id'] as String,
    );
    final hash = stored.json['token_hash'] as String;
    // Even the admin who sees the invitation cannot probe its hash.
    await expectNoLeak(b.admin, 'invites', (v) => 'token_hash = "$v"', hash);
    await expectNoLeak(
      b.admin,
      'organizations',
      (v) => 'invites_via_organization.token_hash ?= "$v"',
      hash,
    );
  });
}
