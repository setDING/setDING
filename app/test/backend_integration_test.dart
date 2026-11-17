// Runs PocketBaseBackend against a real PocketBase with the repository's
// schema and hooks (server/, ADR-0015). The pinned PocketBase version is
// downloaded once by tool/server/fetch-pocketbase.sh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/sync/pocketbase_backend.dart';
import 'package:setding/sync/session_store.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:uuid/uuid.dart';
import 'package:setding_server/pocketbase_harness.dart';

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
      'app${++n}-${DateTime.now().microsecondsSinceEpoch}@setding.test';

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
    await b.requestPasswordReset('nobody@setding.test');
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
      expect(orgs.single.members.single.role, OrgRole.admin);
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
      await ann.updateBand(bandId, name: 'Rockers');
      await ann.renameOrganization(orgId, 'School');
      final org = (await ann.fetchOrganizations()).single;
      expect(org.name, 'School');
      expect(org.bands.single.name, 'Rockers');
      expect(org.members.single.role, OrgRole.admin);
      expect(org.bands.single.members.single.role, BandRole.admin);
      ann.dispose();
    });
  });

  group('invitations (ADR-0005, ADR-0017)', () {
    Future<(PocketBaseBackend, AuthUser)> signedIn(String name) async {
      final b = PocketBaseBackend(serverUrl: url, store: MemorySessionStore());
      final user = await b.signUp(
        email: email(),
        password: 'password-123',
        name: name,
      );
      return (b, user);
    }

    test('admins invite, people join with the link', () async {
      final (ann, _) = await signedIn('Ann');
      final (bob, _) = await signedIn('Bob');
      await ann.createBand(id: const Uuid().v4(), name: 'Rock');
      final orgId = (await ann.fetchOrganizations()).single.id;

      final invite = await ann.createInvite(orgId);
      final token = inviteTokenFrom(invite.url)!;
      expect(invite.url, endsWith('/invite/$token'));

      final preview = await bob.previewInvite(token);
      expect(preview.organizationName, 'Rock');
      expect(preview.status, InviteStatus.valid);
      expect(preview.alreadyMember, isFalse);

      expect(await bob.redeemInvite(token), orgId);
      final bobsOrgs = await bob.fetchOrganizations();
      expect(bobsOrgs.single.id, orgId);
      expect(bobsOrgs.single.bands, isEmpty);

      final links = await ann.fetchInvites(orgId);
      expect(links.single.joined, ['Bob']);
      expect(links.single.statusAt(DateTime.now()), InviteStatus.valid);

      await ann.revokeInvite(links.single.id);
      final (carol, _) = await signedIn('Carol');
      expect(
        await kindOf(() => carol.redeemInvite(token)),
        BackendErrorKind.inviteRevoked,
      );
      expect((await bob.previewInvite(token)).status, InviteStatus.revoked);
      ann.dispose();
      bob.dispose();
      carol.dispose();
    });

    test('members cannot invite; unknown links are reported', () async {
      final (ann, _) = await signedIn('Ann');
      await ann.createBand(id: const Uuid().v4(), name: 'Rock');
      final orgId = (await ann.fetchOrganizations()).single.id;
      final (bob, _) = await signedIn('Bob');
      expect(
        await kindOf(() => bob.createInvite(orgId)),
        BackendErrorKind.notAllowed,
      );
      expect(
        await kindOf(() => bob.redeemInvite('Q' * 32)),
        BackendErrorKind.inviteUnknown,
      );
      expect(
        await kindOf(() => bob.previewInvite('../../x')),
        BackendErrorKind.inviteUnknown,
      );
      ann.dispose();
      bob.dispose();
    });
  });

  group('roles (ADR-0023)', () {
    test('leaders invite into their band and edit their own songs', () async {
      final ann = PocketBaseBackend(
        serverUrl: url,
        store: MemorySessionStore(),
      );
      await ann.signUp(email: email(), password: 'password-123', name: 'Ann');
      final bandId = const Uuid().v4();
      await ann.createBand(id: bandId, name: 'Rock');
      final orgId = (await ann.fetchOrganizations()).single.id;

      // Bob joins with an organization link; Ann makes him leader.
      final bob = PocketBaseBackend(
        serverUrl: url,
        store: MemorySessionStore(),
      );
      final bobUser = await bob.signUp(
        email: email(),
        password: 'password-123',
        name: 'Bob',
      );
      final orgLink = await ann.createInvite(orgId);
      await bob.redeemInvite(inviteTokenFrom(orgLink.url)!);
      await ann.addBandMember(bandId, bobUser.id, BandRole.admin);

      // A link of the leader leads into the band.
      final link = await bob.createInvite(orgId, bandId: bandId);
      final token = inviteTokenFrom(link.url)!;
      final carol = PocketBaseBackend(
        serverUrl: url,
        store: MemorySessionStore(),
      );
      await carol.signUp(email: email(), password: 'password-123', name: 'C');
      expect((await carol.previewInvite(token)).bandName, 'Rock');
      await carol.redeemInvite(token);
      final carolsBand = (await carol.fetchOrganizations()).single.bands.single;
      expect(carolsBand.id, bandId);
      expect((await bob.fetchInvites(orgId, bandId: bandId)).map((i) => i.id), [
        link.id,
      ]);

      // Own songs: recorded creator, editable until someone else edits.
      final song = await bob.pushSong(
        RemoteSong(
          id: const Uuid().v4(),
          organizationId: orgId,
          title: 'Mine',
          chordpro: '{title: Mine}',
        ),
        create: true,
      );
      expect(song.createdBy, bobUser.id);
      expect(song.updatedBy, bobUser.id);
      final fixed = await bob.pushSong(
        RemoteSong(
          id: song.id,
          organizationId: orgId,
          title: 'Mine',
          chordpro: '{title: Mine}\n[C]Fixed',
          revision: song.revision,
        ),
        create: false,
      );
      final byAnn = await ann.pushSong(
        RemoteSong(
          id: song.id,
          organizationId: orgId,
          title: 'Mine',
          chordpro: '{title: Mine}\n[C]Maintained',
          revision: fixed.revision,
        ),
        create: false,
      );
      expect(byAnn.updatedBy, isNot(bobUser.id));
      expect(
        await kindOf(
          () => bob.pushSong(
            RemoteSong(
              id: song.id,
              organizationId: orgId,
              title: 'Mine',
              chordpro: '{title: Mine}\n[C]Again',
              revision: byAnn.revision,
            ),
            create: false,
          ),
        ),
        BackendErrorKind.notAllowed,
      );
      ann.dispose();
      bob.dispose();
      carol.dispose();
    });
  });

  group('invite-only server (ADR-0024)', () {
    late PocketBase closed;
    late String closedUrl;

    setUpAll(() async {
      closed = await PocketBase.start(
        environment: {'SETDING_REGISTRATION': 'invite_only'},
      );
      closedUrl = closed.baseUrl.toString().replaceAll(RegExp(r'/$'), '');
    });
    tearDownAll(() => closed.stop());

    test('sign-up needs a link, which also works signed out', () async {
      final guest = PocketBaseBackend(
        serverUrl: closedUrl,
        store: MemorySessionStore(),
      );
      final config = await guest.fetchServerConfig();
      expect(config.inviteOnly, isTrue);
      expect(config.emailVerification, isFalse);
      expect(
        await kindOf(
          () => guest.signUp(
            email: email(),
            password: 'password-123',
            name: 'Eve',
          ),
        ),
        BackendErrorKind.invitationRequired,
      );

      // An organization admin (created by the operator) invites.
      final admin = await closed.signUp('Ann');
      final org = await closed.superuser.post('organizations', {
        'name': 'School',
      });
      org.expectStatus(200);
      (await closed.superuser.post('org_memberships', {
        'user': admin.id,
        'organization': org.json['id'],
        'role': 'admin',
      })).expectStatus(200);
      final created = await admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': org.json['id']},
      );
      final token = created.json['token'] as String;

      final preview = await guest.previewInvite(token);
      expect(preview.organizationName, 'School');
      expect(preview.founder, isFalse);

      await guest.signUp(
        email: email(),
        password: 'password-123',
        name: 'Bob',
        invite: token,
      );
      expect(await guest.redeemInvite(token), org.json['id']);
      expect(
        await kindOf(() => guest.createBand(id: const Uuid().v4(), name: 'X')),
        BackendErrorKind.founderInvitationRequired,
      );
      guest.dispose();
    });

    test('an unreachable server reports a network error', () async {
      final backend = PocketBaseBackend(
        serverUrl: 'http://127.0.0.1:1',
        store: MemorySessionStore(),
      );
      expect(await kindOf(backend.fetchServerConfig), BackendErrorKind.network);
      backend.dispose();
    });
  });
}
