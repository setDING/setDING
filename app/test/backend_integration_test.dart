// Runs PocketBaseBackend against a real PocketBase with the repository's
// schema and hooks (server/, ADR-0015). The pinned PocketBase version is
// downloaded once by tool/server/fetch-pocketbase.sh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/sync/pocketbase_backend.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:uuid/uuid.dart';
import 'package:realchord_server/pocketbase_harness.dart';

void main() {
  late PocketBase pb;
  late String url;

  setUpAll(() async {
    pb = await PocketBase.start();
    url = pb.baseUrl.toString().replaceAll(RegExp(r'/$'), '');
  });
  tearDownAll(() => pb.stop());

  var n = 0;
  String email() =>
      'app${++n}-${DateTime.now().microsecondsSinceEpoch}@realchord.test';

  Future<BackendErrorKind> kindOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on BackendException catch (e) {
      return e.kind;
    }
    fail('no BackendException');
  }

  test(
    'signs up, restores the session after a restart and signs out',
    () async {
      final store = MemorySessionStore();
      final address = email();
      final first = PocketBaseBackend(serverUrl: url, store: store);
      final user = await first.signUp(
        email: address,
        password: 'password-123',
        name: 'Ann',
      );
      expect(user.email, address);
      expect(user.name, 'Ann');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      first.dispose();

      // "Restart": a new backend on the stored session.
      final second = PocketBaseBackend(serverUrl: url, store: store);
      expect(second.currentUser, user);
      await second.refreshSession();
      expect(second.currentUser, user);

      await second.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.current, isNull);
      second.dispose();
    },
  );

  test('reports wrong credentials, taken email and weak password', () async {
    final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
    final address = email();
    await b.signUp(email: address, password: 'password-123', name: 'C');
    await b.signOut();

    expect(
      await kindOf(() => b.signIn(email: address, password: 'wrong-password')),
      BackendErrorKind.invalidCredentials,
    );
    expect(
      await kindOf(
        () => b.signUp(email: address, password: 'password-123', name: 'C'),
      ),
      BackendErrorKind.emailTaken,
    );
    expect(
      await kindOf(
        () => b.signUp(
          email: 'not-an-email',
          password: 'password-123',
          name: 'D',
        ),
      ),
      BackendErrorKind.invalidEmail,
    );
    expect(
      await kindOf(
        () => b.signUp(email: email(), password: 'short', name: 'E'),
      ),
      BackendErrorKind.weakPassword,
    );
    b.dispose();
  });

  test('accepts a password reset request', () async {
    final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
    await b.requestPasswordReset('nobody@realchord.test');
    b.dispose();
  });

  test('reports a network error when the server is unreachable', () async {
    final b = PocketBaseBackend(
      serverUrl: 'http://127.0.0.1:1',
      store: MemorySessionStore(),
    );
    expect(
      await kindOf(() => b.signIn(email: 'a@b.test', password: 'x')),
      BackendErrorKind.network,
    );
    b.dispose();
  });

  group('organizations and bands (ADR-0017)', () {
    Future<(PocketBaseBackend, AuthUser)> signedIn(String name) async {
      final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
      final user = await b.signUp(
        email: email(),
        password: 'password-123',
        name: name,
      );
      return (b, user);
    }

    test('a new band gets an organization and appears in the list', () async {
      final (ann, _) = await signedIn('Ann');
      final id = const Uuid().v4();
      await ann.createBand(id: id, name: 'Rock');
      final orgs = await ann.fetchOrganizations();
      expect(orgs.single.name, 'Rock');
      expect(orgs.single.members.single.role, BandRole.admin);
      final band = orgs.single.bands.single;
      expect(band.id, id);
      expect(band.organizationId, orgs.single.id);
      expect(band.members.single.name, 'Ann');

      final second = const Uuid().v4();
      await ann.createBand(
        id: second,
        name: 'Jazz',
        organizationId: orgs.single.id,
      );
      expect((await ann.fetchOrganizations()).single.bands, hasLength(2));
      ann.dispose();
    });

    test('band admins add people of the organization, not others', () async {
      final (ann, _) = await signedIn('Ann');
      final (bob, bobUser) = await signedIn('Bob');
      final bandId = const Uuid().v4();
      await ann.createBand(id: bandId, name: 'Rock');
      final orgId = (await ann.fetchOrganizations()).single.id;

      expect(
        await kindOf(
          () => ann.addBandMember(bandId, bobUser.id, BandRole.member),
        ),
        BackendErrorKind.notOrgMember,
      );

      // Joining the organization happens through invitations (#16).
      (await pb.superuser.post('org_memberships', {
        'user': bobUser.id,
        'organization': orgId,
        'role': 'member',
      })).expectStatus(200);
      await ann.addBandMember(bandId, bobUser.id, BandRole.member);
      final seenByBob = await bob.fetchOrganizations();
      expect(seenByBob.single.bands.single.id, bandId);
      expect(
        seenByBob.single.members.map((m) => m.name),
        unorderedEquals(['Ann', 'Bob']),
      );

      // Removed and added again: the old membership is reactivated.
      final membership = seenByBob.single.bands.single.members.firstWhere(
        (m) => m.userId == bobUser.id,
      );
      await ann.removeMember(membership.membershipId);
      expect((await bob.fetchOrganizations()).single.bands, isEmpty);
      await ann.addBandMember(bandId, bobUser.id, BandRole.admin);
      final again = (await bob.fetchOrganizations()).single.bands.single;
      expect(
        again.members.firstWhere((m) => m.userId == bobUser.id).role,
        BandRole.admin,
      );
      ann.dispose();
      bob.dispose();
    });

    test('the last admin is reported', () async {
      final (ann, _) = await signedIn('Ann');
      final bandId = const Uuid().v4();
      await ann.createBand(id: bandId, name: 'Solo');
      final org = (await ann.fetchOrganizations()).single;
      expect(
        await kindOf(
          () => ann.setMemberRole(
            org.bands.single.members.single.membershipId,
            BandRole.member,
          ),
        ),
        BackendErrorKind.lastAdmin,
      );
      expect(
        await kindOf(
          () => ann.removeOrgMember(org.members.single.membershipId),
        ),
        BackendErrorKind.lastAdmin,
      );
      ann.dispose();
    });

    test('band settings and organization name', () async {
      final (ann, _) = await signedIn('Ann');
      final bandId = const Uuid().v4();
      await ann.createBand(id: bandId, name: 'Rock');
      final orgId = (await ann.fetchOrganizations()).single.id;
      await ann.updateBand(bandId, name: 'Rockers', membersCanEditSongs: true);
      await ann.renameOrganization(orgId, 'School');
      final org = (await ann.fetchOrganizations()).single;
      expect(org.name, 'School');
      expect(org.bands.single.name, 'Rockers');
      expect(org.bands.single.membersCanEditSongs, isTrue);
      ann.dispose();
    });
  });
}
