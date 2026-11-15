import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/pocketbase.dart';

void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> invite(String band) async {
    final r = await pb.superuser.post('invites', {
      'band': band,
      'token_hash': 'hash-${uuid()}',
      'expires': '2099-01-01 00:00:00.000Z',
    });
    r.expectStatus(200);
    return r.json;
  }

  test('admins list the invitations of their band, without the hash', () async {
    final f = await BandFixture.create(pb);
    final created = await invite(f.id);
    final seen = await f.admin.list('invites');
    expect(seen.map((i) => i['id']), [created['id']]);
    expect(seen.single.containsKey('token_hash'), isFalse);
  });

  test('members and outsiders do not see invitations', () async {
    final f = await BandFixture.create(pb);
    await invite(f.id);
    expect(await f.member.list('invites'), isEmpty);
    expect(await f.outsider.list('invites'), isEmpty);
  });

  test(
    'invitations cannot be created or changed through the API yet',
    () async {
      final f = await BandFixture.create(pb);
      final created = await f.admin.post('invites', {
        'band': f.id,
        'token_hash': 'forged',
        'expires': '2099-01-01 00:00:00.000Z',
      });
      expect(created.status, isNot(200));
      final existing = await invite(f.id);
      final revoke = await f.admin.patch('invites', existing['id'], {
        'revoked': true,
      });
      expect(revoke.status, isNot(200));
    },
  );
}
