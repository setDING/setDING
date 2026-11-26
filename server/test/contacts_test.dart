import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// People without an account in a set's lineup (ADR-0064, #1097).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> stored(String collection, String id) async {
    final r = await pb.superuser.view(collection, id);
    r.expectStatus(200);
    return r.json;
  }

  /// Moves the deletion of a record 31 days back (ADR-0043, ADR-0044).
  Future<void> age(String collection, String id) async {
    final at = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 31))
        .toIso8601String()
        .replaceFirst('T', ' ');
    (await pb.superuser.patch(collection, id, {
      'deleted_at': at,
    })).expectStatus(200);
  }

  Future<void> purgeTrash() async => (await pb.superuser.send(
    'POST',
    '/api/setding/trash/purge',
  )).expectStatus(200);

  Future<String> createContact(
    Client client,
    BandFixture f, {
    String first = 'Guest',
    String email = 'guest@setding.test',
  }) async {
    final r = await client.post('contacts', {
      'id': uuid(),
      'organization': f.orgId,
      'first_name': first,
      'last_name': 'Drummer',
      'email': email,
    });
    r.expectStatus(200);
    return r.json['id'] as String;
  }

  Future<String> createSet(
    BandFixture f, {
    List<String> lineup = const [],
    List<String> contacts = const [],
  }) async {
    final r = await f.admin.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': 'Gig',
      'items': <dynamic>[],
      'lineup': lineup,
      'lineup_contacts': contacts,
      'lineup_custom': true,
    });
    r.expectStatus(200);
    return r.json['id'] as String;
  }

  group('contacts', () {
    test('set editors create and edit contacts; the server keeps its '
        'fields', () async {
      final f = await BandFixture.create(pb);
      final planner = await f.addPlanner();
      final id = uuid();
      final r = await planner.post('contacts', {
        'id': id,
        'organization': f.orgId,
        'first_name': 'Guest',
        'email': 'guest@setding.test',
      });
      r.expectStatus(200);
      final contact = await stored('contacts', id);
      expect(contact['created_by'], planner.id);
      expect(contact['updated_by'], planner.id);
      expect(contact['revision'], greaterThan(0));

      final leader = await f.addLeader();
      (await leader.patch('contacts', id, {
        'last_name': 'Drummer',
      })).expectStatus(200);
      final edited = await stored('contacts', id);
      expect(edited['last_name'], 'Drummer');
      expect(edited['created_by'], planner.id);
      expect(edited['revision'], greaterThan(contact['revision'] as int));
    });

    test('members, librarians and outsiders cannot create or edit '
        'contacts', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final plain = await pb.signUp('Plain');
      await BandFixture.addMember(pb, f.id, plain);
      final id = await createContact(f.admin, f);
      for (final user in [f.member, plain, f.outsider]) {
        final created = await user.post('contacts', {
          'id': uuid(),
          'organization': f.orgId,
          'first_name': 'X',
        });
        expect(created.status, greaterThanOrEqualTo(400));
        final edited = await user.patch('contacts', id, {'first_name': 'X'});
        expect(edited.status, greaterThanOrEqualTo(400));
      }
      expect((await stored('contacts', id))['first_name'], 'Guest');
      expect(
        await pb.superuser.list(
          'contacts',
          filter: 'organization = "${f.orgId}"',
        ),
        hasLength(1),
      );
    });

    test('a contact needs a first name', () async {
      final f = await BandFixture.create(pb);
      final r = await f.admin.post('contacts', {
        'id': uuid(),
        'organization': f.orgId,
        'last_name': 'Only',
      });
      r.expectStatus(400);
    });

    test('everyone in the organization reads the names, only set editors '
        'the mail address', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final planner = await f.addPlanner();
      final plain = await pb.signUp('Plain');
      await BandFixture.addMember(pb, f.id, plain);
      final id = await createContact(f.admin, f);
      for (final user in [f.admin, planner]) {
        final r = await user.view('contacts', id);
        r.expectStatus(200);
        expect(r.json['email'], 'guest@setding.test');
      }
      for (final user in [f.member, plain]) {
        final r = await user.view('contacts', id);
        r.expectStatus(200);
        expect(r.json['first_name'], 'Guest');
        expect(r.json.containsKey('email'), isFalse);
        final listed = await user.list('contacts');
        expect(listed.single.containsKey('email'), isFalse);
      }
      expect((await f.outsider.view('contacts', id)).status, 404);
      expect(await f.outsider.list('contacts'), isEmpty);
    });

    test('server fields and the organization cannot be forged', () async {
      final f = await BandFixture.create(pb);
      final g = await BandFixture.create(pb);
      final forged = await f.admin.post('contacts', {
        'id': uuid(),
        'organization': f.orgId,
        'first_name': 'X',
        'linked_user': f.member.id,
      });
      expect(forged.status, greaterThanOrEqualTo(400));
      final id = await createContact(f.admin, f);
      for (final body in [
        {'organization': g.orgId},
        {'linked_user': f.member.id},
        {'created_by': f.member.id},
      ]) {
        final r = await f.admin.patch('contacts', id, body);
        expect(r.status, greaterThanOrEqualTo(400), reason: '$body');
      }
      final contact = await stored('contacts', id);
      expect(contact['organization'], f.orgId);
      expect(contact['linked_user'], '');
      expect(contact['created_by'], f.admin.id);
      // A contact in another organization is refused too.
      final other = await f.admin.post('contacts', {
        'id': uuid(),
        'organization': g.orgId,
        'first_name': 'X',
      });
      expect(other.status, greaterThanOrEqualTo(400));
    });

    test('only organization admins delete contacts; the mail address goes, '
        'the name stays', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final id = await createContact(leader, f);
      final refused = await leader.patch('contacts', id, {'deleted': true});
      expect(refused.status, greaterThanOrEqualTo(400));
      expect((await stored('contacts', id))['deleted'], isFalse);
      expect(
        (await leader.delete('contacts', id)).status,
        greaterThanOrEqualTo(400),
      );

      (await f.admin.patch('contacts', id, {
        'deleted': true,
      })).expectStatus(200);
      final contact = await stored('contacts', id);
      expect(contact['deleted'], isTrue);
      expect(contact['email'], '');
      expect(contact['first_name'], 'Guest');
      expect(contact['deleted_at'], isNotEmpty);
      // A deleted contact is not edited or restored.
      for (final body in [
        {'first_name': 'Again'},
        {'deleted': false},
      ]) {
        final r = await f.admin.patch('contacts', id, body);
        expect(r.status, greaterThanOrEqualTo(400), reason: '$body');
      }
    });
  });

  group('lineup contacts', () {
    test('set editors put contacts of the organization in a lineup', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, lineup: [f.member.id], contacts: [contact]);
      expect((await stored('setlists', id))['lineup_contacts'], [contact]);
    });

    test('contacts of another organization and deleted ones are '
        'refused', () async {
      final f = await BandFixture.create(pb);
      final g = await BandFixture.create(pb);
      final foreign = await createContact(g.admin, g);
      final deleted = await createContact(f.admin, f, first: 'Gone');
      (await f.admin.patch('contacts', deleted, {
        'deleted': true,
      })).expectStatus(200);
      final id = await createSet(f, lineup: [f.member.id]);
      for (final contact in [foreign, deleted, uuid()]) {
        final r = await f.admin.patch('setlists', id, {
          'lineup_contacts': [contact],
          'lineup_custom': true,
        });
        r.expectStatus(400);
      }
      expect((await stored('setlists', id))['lineup_contacts'], isEmpty);
    });

    test('a contact deleted later stays in the sets it is in', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, contacts: [contact]);
      (await f.admin.patch('contacts', contact, {
        'deleted': true,
      })).expectStatus(200);
      (await f.admin.patch('setlists', id, {
        'name': 'Renamed',
      })).expectStatus(200);
      expect((await stored('setlists', id))['lineup_contacts'], [contact]);
    });

    test('the whole band stores no contacts', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, contacts: [contact]);
      (await f.admin.patch('setlists', id, {
        'lineup_custom': false,
      })).expectStatus(200);
      expect((await stored('setlists', id))['lineup_contacts'], isEmpty);
    });

    test('substitutes get the names of the lineup\'s contacts, set editors '
        'their mail addresses', () async {
      final f = await BandFixture.create(pb);
      final substitute = await pb.signUp('Substitute');
      await BandFixture.addOrgMember(pb, f.orgId, substitute);
      final contact = await createContact(f.admin, f);
      final quiet = await createContact(f.admin, f, first: 'Quiet', email: '');
      final id = await createSet(
        f,
        lineup: [substitute.id],
        contacts: [contact, quiet],
      );

      final lineup = await substitute.send('GET', '/api/setding/lineup');
      lineup.expectStatus(200);
      final names = lineup.json['contacts'] as List;
      expect(
        names.map((c) => (c as Map)['id']),
        unorderedEquals([contact, quiet]),
      );
      for (final c in names) {
        expect((c as Map).containsKey('email'), isFalse);
      }

      final emails = await f.admin.send(
        'GET',
        '/api/setding/lineup/$id/emails',
      );
      emails.expectStatus(200);
      final withMail = emails.json['contacts'] as List;
      expect(withMail, hasLength(1));
      expect((withMail.single as Map)['email'], 'guest@setding.test');
      expect(
        ((emails.json['people'] as List).single as Map)['id'],
        substitute.id,
      );
    });

    test('a purged set clears its contacts', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, contacts: [contact]);
      (await f.admin.patch('setlists', id, {
        'deleted': true,
      })).expectStatus(200);
      await age('setlists', id);
      await purgeTrash();
      expect((await stored('setlists', id))['purged'], isTrue);
      expect((await stored('setlists', id))['lineup_contacts'], isEmpty);
    });
  });

  group('personal invitations', () {
    Future<Response> invite(
      Client client,
      BandFixture f,
      String contact, {
      String? band,
    }) => client.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': f.orgId, 'band': ?band, 'contact': contact},
    );

    test('organization admins and band leaders invite a contact; set '
        'planners and members cannot', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final planner = await f.addPlanner();
      final contact = await createContact(f.admin, f);
      (await invite(f.admin, f, contact)).expectStatus(200);
      (await invite(leader, f, contact, band: f.id)).expectStatus(200);
      expect((await invite(planner, f, contact, band: f.id)).status, 403);
      expect((await invite(f.member, f, contact, band: f.id)).status, 403);
      expect(
        await pb.superuser.list('invites', filter: 'contact = "$contact"'),
        hasLength(2),
      );
    });

    test('contacts of another organization and deleted ones are '
        'refused', () async {
      final f = await BandFixture.create(pb);
      final g = await BandFixture.create(pb);
      final foreign = await createContact(g.admin, g);
      final deleted = await createContact(f.admin, f);
      (await f.admin.patch('contacts', deleted, {
        'deleted': true,
      })).expectStatus(200);
      for (final contact in [foreign, deleted]) {
        expect((await invite(f.admin, f, contact)).status, 400);
      }
    });

    test('the preview prefills the sign-up; signing up and redeeming links '
        'the contact in every lineup', () async {
      final f = await BandFixture.create(pb);
      final second = await f.admin.post('bands', {
        'name': 'Second',
        'organization': f.orgId,
      });
      second.expectStatus(200);
      final contact = await createContact(f.admin, f);
      final other = await createContact(f.admin, f, first: 'Other');
      final first = await createSet(f, contacts: [contact, other]);
      final r = await f.admin.post('setlists', {
        'id': uuid(),
        'band': second.json['id'],
        'name': 'Second gig',
        'items': <dynamic>[],
        'lineup': [f.member.id],
        'lineup_contacts': [contact],
        'lineup_custom': true,
      });
      r.expectStatus(200);
      final secondSet = r.json['id'] as String;
      final revisionBefore =
          (await stored('setlists', secondSet))['revision'] as int;

      final created = await invite(f.admin, f, contact);
      created.expectStatus(200);
      final token = created.json['token'] as String;

      final preview = await pb.guest.send('GET', '/api/setding/invites/$token');
      preview.expectStatus(200);
      final prefill = preview.json['contact'] as Map;
      expect(prefill['first_name'], 'Guest');
      expect(prefill['last_name'], 'Drummer');
      expect(prefill['email'], 'guest@setding.test');

      // Signing up with the personal invitation on the invite-only server.
      final email =
          'joined-${DateTime.now().microsecondsSinceEpoch}@setding.test';
      final signUp = await pb.guest.post('users', {
        'email': email,
        'password': 'password-123',
        'passwordConfirm': 'password-123',
        'first_name': 'Guest',
        'last_name': 'Drummer',
        'invite': token,
      });
      signUp.expectStatus(200);
      final auth = await pb.guest.send(
        'POST',
        '/api/collections/users/auth-with-password',
        body: {'identity': email, 'password': 'password-123'},
      );
      auth.expectStatus(200);
      final userId = signUp.json['id'] as String;
      final joined = User(pb, userId, auth.json['token'] as String);

      (await joined.send(
        'POST',
        '/api/setding/invites/$token/redeem',
      )).expectStatus(200);

      final firstSet = await stored('setlists', first);
      expect(firstSet['lineup'], [userId]);
      expect(firstSet['lineup_contacts'], [other]);
      final secondStored = await stored('setlists', secondSet);
      expect(secondStored['lineup'], unorderedEquals([f.member.id, userId]));
      expect(secondStored['lineup_contacts'], isEmpty);
      expect(secondStored['revision'], greaterThan(revisionBefore));
      expect(secondStored['updated_by'], userId);

      final linked = await stored('contacts', contact);
      expect(linked['linked_user'], userId);
      expect(linked['deleted'], isTrue);
      expect(linked['email'], '');
      expect(
        await pb.superuser.list(
          'org_memberships',
          filter:
              'organization = "${f.orgId}" && user = "$userId" && deleted = false',
        ),
        hasLength(1),
      );
      // The joined person now plays both sets as a substitute.
      final sets = await joined.send('GET', '/api/setding/lineup');
      expect(
        (sets.json['sets'] as List).map((s) => (s as Map)['id']),
        unorderedEquals([first, secondSet]),
      );

      // A personal invitation is used once.
      final again = await pb.signUp('Again');
      final used = await again.send(
        'POST',
        '/api/setding/invites/$token/redeem',
      );
      expect(used.status, 410);
      final state = await pb.guest.send('GET', '/api/setding/invites/$token');
      expect(state.json['status'], 'used');
      expect(state.json['contact'], isNull);
    });

    test('an existing account redeems a personal invitation', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, lineup: [f.member.id], contacts: [contact]);
      final created = await invite(f.admin, f, contact);
      final token = created.json['token'] as String;
      // A band member who turns out to be the contact.
      (await f.member.send(
        'POST',
        '/api/setding/invites/$token/redeem',
      )).expectStatus(200);
      final set = await stored('setlists', id);
      expect(set['lineup'], [f.member.id]);
      expect(set['lineup_contacts'], isEmpty);
    });

    test('deleting a contact revokes its invitations', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final id = await createSet(f, contacts: [contact]);
      final created = await invite(f.admin, f, contact);
      final token = created.json['token'] as String;
      (await f.admin.patch('contacts', contact, {
        'deleted': true,
      })).expectStatus(200);
      final preview = await pb.guest.send('GET', '/api/setding/invites/$token');
      expect(preview.json['status'], 'revoked');
      final joined = await pb.signUp('Late');
      final r = await joined.send('POST', '/api/setding/invites/$token/redeem');
      expect(r.status, 410);
      expect((await stored('setlists', id))['lineup_contacts'], [contact]);
      expect((await stored('contacts', contact))['linked_user'], '');
    });

    test('clients cannot attach a contact to an invitation', () async {
      final f = await BandFixture.create(pb);
      final contact = await createContact(f.admin, f);
      final r = await f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId},
      );
      final id = r.json['id'] as String;
      final patched = await f.admin.patch('invites', id, {'contact': contact});
      expect(patched.status, greaterThanOrEqualTo(400));
      expect((await stored('invites', id))['contact'], '');
    });
  });

  test('closing and purging an organization purges its contacts', () async {
    final f = await BandFixture.create(pb);
    final contact = await createContact(f.admin, f);
    (await f.admin.delete('organizations', f.orgId)).expectStatus(204);
    // While closed, only organization admins read them.
    expect((await f.member.view('contacts', contact)).status, 404);
    (await f.admin.view('contacts', contact)).expectStatus(200);
    await age('organizations', f.orgId);
    await purgeTrash();
    expect((await pb.superuser.view('contacts', contact)).status, 404);
  });
}
