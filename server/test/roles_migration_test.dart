import 'package:realchord_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Migration of `members_can_edit_songs` to the librarian role (ADR-0023).
void main() {
  test(
    'members of bands that allowed song editing become librarians',
    () async {
      var pb = await PocketBase.start(migrationsBefore: '1795300000_roles.js');
      addTearDown(() => pb.stop());

      final relaxed = await BandFixture.create(pb);
      (await relaxed.admin.patch('bands', relaxed.id, {
        'members_can_edit_songs': true,
      })).expectStatus(200);
      final strict = await BandFixture.create(pb);
      // The admin of the relaxed band is admin of its organization already.
      final song = await relaxed.createSong(relaxed.admin);

      pb = await pb.upgrade();
      Future<String> orgRole(BandFixture f, User user) async {
        final m = await pb.superuser.list(
          'org_memberships',
          filter: 'organization = "${f.orgId}" && user = "${user.id}"',
        );
        return m.single['role'] as String;
      }

      expect(await orgRole(relaxed, relaxed.member), 'librarian');
      expect(await orgRole(relaxed, relaxed.admin), 'admin');
      expect(await orgRole(strict, strict.member), 'member');
      final band = await pb.superuser.view('bands', relaxed.id);
      expect(band.json.containsKey('members_can_edit_songs'), isFalse);

      // Existing songs have no creator; the librarian edits them.
      final stored = await pb.superuser.view('songs', song['id'] as String);
      expect(stored.json['created_by'], '');
      final member = await signIn(pb, relaxed.member);
      (await member.patch('songs', song['id'] as String, {
        'title': 'Still editable',
        'revision': stored.json['revision'],
      })).expectStatus(200);
    },
  );
}

/// The same user with a token of the restarted server.
Future<User> signIn(PocketBase pb, User user) async {
  final record = await pb.superuser.view('users', user.id);
  final r = await pb.guest.send(
    'POST',
    '/api/collections/users/auth-with-password',
    body: {'identity': record.json['email'], 'password': 'password-123'},
  );
  r.expectStatus(200);
  return User(pb, user.id, r.json['token'] as String);
}
