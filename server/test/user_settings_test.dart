import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:setding_server/pocketbase_harness.dart';

/// Personal settings per user, synced with the account (ADR-0027).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  test('settings are private to their user', () async {
    final f = await BandFixture.create(pb);
    final mine = await f.member.post('user_settings', {
      'id': uuid(),
      'user': f.member.id,
      'data': {'instrument': 'bass', 'notation': 'german'},
    });
    mine.expectStatus(200);
    expect(mine.json['revision'], greaterThan(0));
    expect(mine.json['updated_by'], f.member.id);

    expect(await f.member.list('user_settings'), hasLength(1));
    // Not even organization admins see them.
    expect(await f.admin.list('user_settings'), isEmpty);
    expect((await f.admin.view('user_settings', mine.json['id'])).status, 404);
    expect(
      (await f.admin.patch('user_settings', mine.json['id'], {
        'data': {'instrument': 'drums'},
      })).status,
      404,
    );
    // Not for someone else; one record per user; never hard-deleted.
    expect(
      (await f.admin.post('user_settings', {
        'id': uuid(),
        'user': f.member.id,
        'data': <String, dynamic>{},
      })).status,
      400,
    );
    expect(
      (await f.member.post('user_settings', {
        'id': uuid(),
        'user': f.member.id,
        'data': <String, dynamic>{},
      })).status,
      400,
    );
    expect(
      (await f.member.patch('user_settings', mine.json['id'], {
        'user': f.admin.id,
      })).status,
      404,
    );
    expect(
      (await f.member.delete('user_settings', mine.json['id'])).status,
      isNot(204),
    );
  });

  test('an update merges the sent keys into the stored settings', () async {
    final f = await BandFixture.create(pb);
    final created = await f.member.post('user_settings', {
      'id': uuid(),
      'user': f.member.id,
      'data': {'instrument': 'bass', 'notation': 'german', 'future': 1},
    });
    created.expectStatus(200);
    final id = created.json['id'] as String;

    // Two devices change different settings.
    (await f.member.patch('user_settings', id, {
      'data': {'instrument': 'ukulele'},
    })).expectStatus(200);
    final second = await f.member.patch('user_settings', id, {
      'data': {'nashville': true},
    });
    second.expectStatus(200);

    expect(second.json['data'], {
      'instrument': 'ukulele',
      'notation': 'german',
      'future': 1,
      'nashville': true,
    });
    expect(
      second.json['revision'],
      greaterThan(created.json['revision'] as int),
    );
  });
}
