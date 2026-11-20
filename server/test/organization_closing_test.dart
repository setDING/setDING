import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Closing organizations (ADR-0044, issue #629): any organization admin
/// closes it with DELETE on the records API; the server keeps it 30 days
/// in the trash, readable only by its admins, then purges it for good.
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> view(String collection, String id) async =>
      (await pb.superuser.view(collection, id)).json;

  /// An organization with two admins, a leader, a member, a band with a
  /// set and an arrangement, a song with an attachment and a personal
  /// adjustment of the member, an earlier deleted song and an invitation.
  Future<
    ({
      BandFixture f,
      User secondAdmin,
      User leader,
      String set,
      String arrangement,
      String song,
      String oldSong,
      String attachment,
      String overlay,
      String invite,
    })
  >
  setUpOrg() async {
    final f = await BandFixture.create(pb);
    final secondAdmin = await pb.signUp('Second admin');
    await BandFixture.addOrgMember(pb, f.orgId, secondAdmin, role: 'admin');
    final leader = await f.addLeader();
    final song = await f.createSong(f.admin);
    final oldSong = await f.createSong(f.admin, title: 'Old');
    (await f.admin.patch('songs', oldSong['id'], {
      'deleted': true,
      'revision': oldSong['revision'],
    })).expectStatus(200);
    final attachment = await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'name': 'Score',
        'pages': '1',
        'size_bytes': '${_pdf.length}',
      },
      fileField: 'file',
      bytes: _pdf,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    );
    attachment.expectStatus(200);
    final set = await leader.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': 'Set',
      'items': <dynamic>[],
    });
    set.expectStatus(200);
    final arrangement = await leader.post('arrangements', {
      'id': uuid(),
      'band': f.id,
      'song': song['id'],
      'transpose': 2,
    });
    arrangement.expectStatus(200);
    final overlay = await f.member.post('overlays', {
      'id': uuid(),
      'user': f.member.id,
      'song': song['id'],
      'data': {'transpose': 1},
    });
    overlay.expectStatus(200);
    final invite = await f.admin.send(
      'POST',
      '/api/setding/invites',
      body: {'organization': f.orgId},
    );
    invite.expectStatus(200);
    return (
      f: f,
      secondAdmin: secondAdmin,
      leader: leader,
      set: set.json['id'] as String,
      arrangement: arrangement.json['id'] as String,
      song: song['id'] as String,
      oldSong: oldSong['id'] as String,
      attachment: attachment.json['id'] as String,
      overlay: overlay.json['id'] as String,
      invite: invite.json['id'] as String,
    );
  }

  Future<String> orgMembershipOf(BandFixture f, User user) async =>
      (await pb.superuser.list(
            'org_memberships',
            filter: 'organization = "${f.orgId}" && user = "${user.id}"',
          )).single['id']
          as String;

  test('closing takes everything of the organization with it', () async {
    final o = await setUpOrg();
    final r = await o.f.admin.delete('organizations', o.f.orgId);
    expect(r.status, 204);

    final org = await view('organizations', o.f.orgId);
    expect(org['deleted'], isTrue);
    expect(org['deleted_at'], isNotEmpty);
    expect(org['updated_by'], o.f.admin.id);
    final at = org['deleted_at'];
    final band = await view('bands', o.f.id);
    expect(band['deleted'], isTrue);
    expect(band['deleted_at'], at);
    expect((await view('setlists', o.set))['deleted'], isTrue);
    expect((await view('arrangements', o.arrangement))['deleted'], isTrue);
    expect((await o.f.membershipOf(o.f.member))['deleted'], isTrue);
    final song = await view('songs', o.song);
    expect(song['deleted'], isTrue);
    expect(song['deleted_at'], at);
    expect((await view('attachments', o.attachment))['deleted'], isTrue);
    expect((await view('overlays', o.overlay))['deleted'], isTrue);
    expect((await view('invites', o.invite))['revoked'], isTrue);
    // The organization memberships stay, so its admins can restore it.
    expect(
      (await view(
        'org_memberships',
        await orgMembershipOf(o.f, o.f.member),
      ))['deleted'],
      isFalse,
    );
  });

  test('members only see that it is closed; admins see it all', () async {
    final o = await setUpOrg();
    (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);

    final seen = await o.f.member.view('organizations', o.f.orgId);
    seen.expectStatus(200);
    expect(seen.json['deleted'], isTrue);
    final people = await o.f.member.list('org_memberships');
    expect(people.map((m) => m['user']), [o.f.member.id]);
    for (final (collection, id) in [
      ('songs', o.song),
      ('attachments', o.attachment),
      ('bands', o.f.id),
      ('setlists', o.set),
      ('arrangements', o.arrangement),
    ]) {
      expect(
        (await o.leader.view(collection, id)).status,
        404,
        reason: collection,
      );
    }
    expect(await o.f.member.list('songs'), isEmpty);

    for (final (collection, id) in [
      ('songs', o.song),
      ('bands', o.f.id),
      ('setlists', o.set),
    ]) {
      (await o.secondAdmin.view(collection, id)).expectStatus(200);
    }
    expect(await o.secondAdmin.list('org_memberships'), hasLength(4));
  });

  test('a closed organization takes no writes', () async {
    final o = await setUpOrg();
    (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
    final f = o.f;
    final song = await view('songs', o.song);
    for (final (what, call) in [
      (
        'create a song',
        () => f.admin.post('songs', {
          'id': uuid(),
          'organization': f.orgId,
          'title': 'T',
          'chordpro': '{title: T}',
        }),
      ),
      (
        'edit a song',
        () => f.admin.patch('songs', o.song, {
          'title': 'x',
          'revision': song['revision'],
        }),
      ),
      (
        'create a band',
        () => f.admin.post('bands', {'name': 'B', 'organization': f.orgId}),
      ),
      ('rename the band', () => f.admin.patch('bands', f.id, {'name': 'x'})),
      (
        'restore the band alone',
        () => f.admin.patch('bands', f.id, {'deleted': false}),
      ),
      (
        'rename the organization',
        () => f.admin.patch('organizations', f.orgId, {'name': 'x'}),
      ),
      (
        'write a personal adjustment',
        () => f.member.post('overlays', {
          'id': uuid(),
          'user': f.member.id,
          'song': o.song,
          'data': {'transpose': 3},
        }),
      ),
      (
        'invite people',
        () => f.admin.send(
          'POST',
          '/api/setding/invites',
          body: {'organization': f.orgId},
        ),
      ),
    ]) {
      expect((await call()).status, greaterThanOrEqualTo(400), reason: what);
    }
    final mine = await orgMembershipOf(f, f.member);
    expect(
      (await f.admin.patch('org_memberships', mine, {
        'role': 'librarian',
      })).status,
      greaterThanOrEqualTo(400),
    );
    expect(
      (await f.member.patch('org_memberships', mine, {'deleted': true})).status,
      greaterThanOrEqualTo(400),
    );
    expect((await view('organizations', f.orgId))['name'], 'The Band');
    // Closing again changes nothing.
    expect((await f.admin.delete('organizations', f.orgId)).status, 404);
  });

  test('another admin restores it with everything', () async {
    final o = await setUpOrg();
    (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
    final r = await o.secondAdmin.patch('organizations', o.f.orgId, {
      'deleted': false,
    });
    r.expectStatus(200);
    expect(r.json['deleted_at'], isEmpty);

    expect((await view('bands', o.f.id))['deleted'], isFalse);
    expect((await view('setlists', o.set))['deleted'], isFalse);
    expect((await view('arrangements', o.arrangement))['deleted'], isFalse);
    expect((await o.f.membershipOf(o.f.member))['deleted'], isFalse);
    expect((await view('songs', o.song))['deleted'], isFalse);
    expect((await view('attachments', o.attachment))['deleted'], isFalse);
    expect((await view('overlays', o.overlay))['deleted'], isFalse);
    // Deleted before: stays deleted. Invitations stay revoked.
    expect((await view('songs', o.oldSong))['deleted'], isTrue);
    expect((await view('invites', o.invite))['revoked'], isTrue);
    (await o.f.member.view('songs', o.song)).expectStatus(200);
  });

  test('a band deleted before the closing stays deleted', () async {
    final o = await setUpOrg();
    (await o.f.admin.delete('bands', o.f.id)).expectStatus(204);
    (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
    (await o.f.admin.patch('organizations', o.f.orgId, {
      'deleted': false,
    })).expectStatus(200);
    expect((await view('bands', o.f.id))['deleted'], isTrue);
    expect((await view('songs', o.song))['deleted'], isFalse);
  });

  test('only organization admins close and restore it', () async {
    final o = await setUpOrg();
    final g = await BandFixture.create(pb);
    final librarian = await pb.signUp('Librarian');
    await BandFixture.addOrgMember(pb, o.f.orgId, librarian, role: 'librarian');
    final others = [o.leader, o.f.member, librarian, g.admin];
    for (final user in others) {
      expect(
        (await user.delete('organizations', o.f.orgId)).status,
        greaterThanOrEqualTo(400),
      );
    }
    expect(
      (await o.f.admin.patch('organizations', o.f.orgId, {
        'deleted': true,
      })).status,
      greaterThanOrEqualTo(400),
      reason: 'closing is DELETE, never PATCH (#627)',
    );
    expect((await view('organizations', o.f.orgId))['deleted'], isFalse);

    (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
    for (final user in others) {
      expect(
        (await user.patch('organizations', o.f.orgId, {
          'deleted': false,
        })).status,
        greaterThanOrEqualTo(400),
      );
    }
    expect(
      (await o.f.admin.patch('organizations', o.f.orgId, {
        'deleted': false,
        'purged': true,
      })).status,
      greaterThanOrEqualTo(400),
    );
    expect((await view('organizations', o.f.orgId))['deleted'], isTrue);
  });

  test('superusers close through the trash too', () async {
    final o = await setUpOrg();
    expect((await pb.superuser.delete('organizations', o.f.orgId)).status, 204);
    final org = await view('organizations', o.f.orgId);
    expect(org['deleted'], isTrue);
    expect((await view('songs', o.song))['deleted'], isTrue);
  });

  group('purge', () {
    Future<void> age(String orgId, int days) async {
      final at = DateTime.now()
          .toUtc()
          .subtract(Duration(days: days))
          .toIso8601String()
          .replaceFirst('T', ' ');
      final before = (await view('organizations', orgId))['deleted_at'];
      (await pb.superuser.patch('organizations', orgId, {
        'deleted_at': at,
      })).expectStatus(200);
      for (final collection in ['bands', 'songs', 'attachments', 'setlists']) {
        for (final r in await pb.superuser.list(
          collection,
          filter: 'deleted_at = "$before"',
        )) {
          (await pb.superuser.patch(collection, r['id'] as String, {
            'deleted_at': at,
          })).expectStatus(200);
        }
      }
    }

    Future<void> purge() async => (await pb.superuser.send(
      'POST',
      '/api/setding/trash/purge',
    )).expectStatus(200);

    test('after 30 days everything is gone for good', () async {
      final o = await setUpOrg();
      (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
      await age(o.f.orgId, 31);
      await purge();

      final org = await view('organizations', o.f.orgId);
      expect(org['purged'], isTrue);
      expect(org['name'], isEmpty);
      for (final (collection, id) in [
        ('bands', o.f.id),
        ('setlists', o.set),
        ('arrangements', o.arrangement),
        ('songs', o.song),
        ('songs', o.oldSong),
        ('attachments', o.attachment),
        ('overlays', o.overlay),
        ('invites', o.invite),
      ]) {
        expect(
          (await pb.superuser.view(collection, id)).status,
          404,
          reason: collection,
        );
      }
      for (final collection in ['org_memberships']) {
        expect(
          await pb.superuser.list(
            collection,
            filter: 'organization = "${o.f.orgId}"',
          ),
          isEmpty,
        );
      }
      expect(
        await pb.superuser.list('memberships', filter: 'band = "${o.f.id}"'),
        isEmpty,
      );
      // Accounts stay.
      (await pb.superuser.view('users', o.f.member.id)).expectStatus(200);
      expect(
        (await o.f.admin.patch('organizations', o.f.orgId, {
          'deleted': false,
        })).status,
        greaterThanOrEqualTo(400),
      );
    });

    test('organizations closed less than 30 days ago stay', () async {
      final o = await setUpOrg();
      (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
      await age(o.f.orgId, 29);
      await purge();
      final org = await view('organizations', o.f.orgId);
      expect(org['purged'], isFalse);
      expect(org['name'], 'The Band');
    });

    test('operators purge one organization at once', () async {
      final o = await setUpOrg();
      Future<Response> now() => pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
        body: {'collection': 'organizations', 'id': o.f.orgId},
      );
      expect((await now()).status, 400);
      (await o.f.admin.delete('organizations', o.f.orgId)).expectStatus(204);
      final r = await now();
      r.expectStatus(200);
      expect(r.json['purged'], 1);
      expect((await view('organizations', o.f.orgId))['purged'], isTrue);
      expect((await pb.superuser.view('songs', o.song)).status, 404);
    });
  });
}
