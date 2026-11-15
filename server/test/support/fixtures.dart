import 'dart:math';

import 'package:realchord_server/pocketbase_harness.dart';

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

/// A band with an admin, a member and an outsider (no membership).
class BandFixture {
  BandFixture._(this.pb, this.id, this.admin, this.member, this.outsider);

  final PocketBase pb;
  final String id;
  final User admin;
  final User member;
  final User outsider;

  static Future<BandFixture> create(
    PocketBase pb, {
    bool membersCanEditSongs = false,
  }) async {
    final admin = await pb.signUp('Admin');
    final member = await pb.signUp('Member');
    final outsider = await pb.signUp('Outsider');
    final band = await admin.post('bands', {
      'name': 'The Band',
      'members_can_edit_songs': membersCanEditSongs,
    });
    band.expectStatus(200);
    final id = band.json['id'] as String;
    await addMember(pb, id, member);
    return BandFixture._(pb, id, admin, member, outsider);
  }

  /// Adds [user] to the band; in the app this happens through an invitation.
  static Future<Map<String, dynamic>> addMember(
    PocketBase pb,
    String bandId,
    User user, {
    String role = 'member',
  }) async {
    final r = await pb.superuser.post('memberships', {
      'user': user.id,
      'band': bandId,
      'role': role,
    });
    r.expectStatus(200);
    return r.json;
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
      'band': id,
      'title': title,
      'chordpro': '{title: $title}\n[C]Hello [G]world',
    });
    r.expectStatus(200);
    return r.json;
  }
}
