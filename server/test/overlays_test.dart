import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:realchord_server/pocketbase_harness.dart';

/// Personal adjustments per user (ADR-0020).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Map<String, dynamic> overlay(User user, String song, {int transpose = 2}) => {
    'id': uuid(),
    'user': user.id,
    'song': song,
    'data': {'transpose': transpose, 'notes': 'Solo after the bridge'},
  };

  test(
    'members keep private adjustments for songs of their organization',
    () async {
      final f = await BandFixture.create(pb);
      final song = (await f.createSong(f.admin))['id'] as String;

      final mine = await f.member.post('overlays', overlay(f.member, song));
      mine.expectStatus(200);
      expect(mine.json['revision'], greaterThan(0));
      expect(mine.json['updated_by'], f.member.id);

      // Private: not even organization admins see it.
      expect(await f.member.list('overlays'), hasLength(1));
      expect(await f.admin.list('overlays'), isEmpty);
      expect((await f.admin.view('overlays', mine.json['id'])).status, 404);

      final changed = await f.member.patch('overlays', mine.json['id'], {
        'data': {'transpose': -1},
      });
      changed.expectStatus(200);
      expect(
        changed.json['revision'],
        greaterThan(mine.json['revision'] as int),
      );
      expect(
        (await f.admin.patch('overlays', mine.json['id'], {'data': {}})).status,
        404,
      );
    },
  );

  test(
    'no adjustments for others or for songs of other organizations',
    () async {
      final f = await BandFixture.create(pb);
      final song = (await f.createSong(f.admin))['id'] as String;

      // For another user.
      expect(
        (await f.admin.post('overlays', overlay(f.member, song))).status,
        400,
      );
      // Outside the organization.
      expect(
        (await f.outsider.post('overlays', overlay(f.outsider, song))).status,
        400,
      );
      // One per user and song.
      (await f.member.post(
        'overlays',
        overlay(f.member, song),
      )).expectStatus(200);
      expect(
        (await f.member.post('overlays', overlay(f.member, song))).status,
        400,
      );

      // User and song cannot be changed; records are never hard-deleted.
      final other = (await f.createSong(f.admin, title: 'Other'))['id'];
      final id = (await f.member.list('overlays')).single['id'] as String;
      expect(
        (await f.member.patch('overlays', id, {'song': other})).status,
        404,
      );
      expect((await f.member.delete('overlays', id)).status, isNot(204));
    },
  );

  test('deleting a song deletes its adjustments for everyone', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    (await f.member.post(
      'overlays',
      overlay(f.member, song['id']),
    )).expectStatus(200);
    (await f.admin.post(
      'overlays',
      overlay(f.admin, song['id']),
    )).expectStatus(200);
    final before = (await f.member.list('overlays')).single;

    (await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    })).expectStatus(200);

    final after = await pb.superuser.list(
      'overlays',
      filter: 'song = "${song['id']}"',
    );
    expect(after.map((o) => o['deleted']), [true, true]);
    final mine = (await f.member.list('overlays')).single;
    expect(mine['revision'], greaterThan(before['revision'] as int));
  });
}
