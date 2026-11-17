import 'dart:math';

import 'package:setding_server/pocketbase_harness.dart';

final _random = Random.secure();

/// A random version 4 UUID, as the app generates record IDs (ADR-0004).
String uuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// A band with an admin (leader), a member and an outsider (no membership);
/// with `memberIsLibrarian` the member is a librarian of the organization.
///
/// The band is created without an organization, so the server creates one
/// with the admin as organization admin (ADR-0017); on an invite-only server
/// (ADR-0024) the organization is created first. The member belongs to the
/// organization and the band.
class BandFixture {
  BandFixture._(
    this.pb,
    this.id,
    this.orgId,
    this.admin,
    this.member,
    this.outsider,
  );

  final PocketBase pb;
  final String id;

  /// The band's organization.
  final String orgId;
  final User admin;
  final User member;
  final User outsider;

  static Future<BandFixture> create(
    PocketBase pb, {
    bool memberIsLibrarian = false,
  }) async {
    final admin = await pb.signUp('Admin');
    final member = await pb.signUp('Member');
    final outsider = await pb.signUp('Outsider');
    var band = await admin.post('bands', {'name': 'The Band'});
    if (band.status == 403) {
      // Invite-only server (ADR-0024): the organization comes first, as a
      // founder invitation would create it.
      final org = await pb.superuser.post('organizations', {
        'name': 'The Band',
      });
      org.expectStatus(200);
      await addOrgMember(pb, org.json['id'] as String, admin, role: 'admin');
      band = await admin.post('bands', {
        'name': 'The Band',
        'organization': org.json['id'],
      });
    }
    band.expectStatus(200);
    final id = band.json['id'] as String;
    final orgId = band.json['organization'] as String;
    await addMember(pb, id, member);
    if (memberIsLibrarian) {
      // The member maintains the song library (ADR-0023).
      final m = await pb.superuser.list(
        'org_memberships',
        filter: 'organization = "$orgId" && user = "${member.id}"',
      );
      (await pb.superuser.patch('org_memberships', m.single['id'] as String, {
        'role': 'librarian',
      })).expectStatus(200);
    }
    return BandFixture._(pb, id, orgId, admin, member, outsider);
  }

  /// Adds [user] to an organization; in the app this happens through an
  /// invitation (#16). Does nothing if the user is already a member.
  static Future<Map<String, dynamic>> addOrgMember(
    PocketBase pb,
    String orgId,
    User user, {
    String role = 'member',
  }) async {
    final existing = await pb.superuser.list(
      'org_memberships',
      filter: 'organization = "$orgId" && user = "${user.id}"',
    );
    if (existing.isNotEmpty) return existing.single;
    final r = await pb.superuser.post('org_memberships', {
      'user': user.id,
      'organization': orgId,
      'role': role,
    });
    r.expectStatus(200);
    return r.json;
  }

  /// Adds [user] to the band and, if needed, to its organization.
  static Future<Map<String, dynamic>> addMember(
    PocketBase pb,
    String bandId,
    User user, {
    String role = 'member',
  }) async {
    final band = await pb.superuser.view('bands', bandId);
    await addOrgMember(pb, band.json['organization'] as String, user);
    final r = await pb.superuser.post('memberships', {
      'user': user.id,
      'band': bandId,
      'role': role,
    });
    r.expectStatus(200);
    return r.json;
  }

  /// A new person who leads this band but is no organization admin
  /// (ADR-0023).
  Future<User> addLeader() async {
    final leader = await pb.signUp('Leader');
    await addMember(pb, id, leader, role: 'admin');
    return leader;
  }

  /// A new person who plans this band's sets (ADR-0023).
  Future<User> addPlanner() async {
    final planner = await pb.signUp('Planner');
    await addMember(pb, id, planner, role: 'planner');
    return planner;
  }

  /// The membership record of [user] in this band.
  Future<Map<String, dynamic>> membershipOf(User user) async {
    final items = await pb.superuser.list(
      'memberships',
      filter: 'band = "$id" && user = "${user.id}"',
    );
    return items.single;
  }

  Future<Map<String, dynamic>> createSong(
    Client client, {
    String title = 'Song',
  }) async {
    final r = await client.post('songs', {
      'id': uuid(),
      'organization': orgId,
      'title': title,
      'chordpro': '{title: $title}\n[C]Hello [G]world',
    });
    r.expectStatus(200);
    return r.json;
  }
}
