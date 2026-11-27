import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:setding_server/pocketbase_harness.dart';

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
        (await f.admin.patch('overlays', mine.json['id'], {
          'data': <String, dynamic>{},
        })).status,
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

  test(
    'restoring a song restores the adjustments its deletion removed',
    () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final mine = await f.member.post(
        'overlays',
        overlay(f.member, song['id']),
      );
      mine.expectStatus(200);
      final theirs = await f.admin.post(
        'overlays',
        overlay(f.admin, song['id']),
      );
      theirs.expectStatus(200);
      // Removed before the song was deleted: stays removed.
      (await f.admin.patch('overlays', theirs.json['id'], {
        'deleted': true,
      })).expectStatus(200);

      final deleted = await f.admin.patch('songs', song['id'], {
        'deleted': true,
        'revision': song['revision'],
      });
      deleted.expectStatus(200);
      final removed = (await f.member.list('overlays')).single;
      expect(removed['deleted'], isTrue);

      (await f.admin.patch('songs', song['id'], {
        'deleted': false,
        'revision': deleted.json['revision'],
      })).expectStatus(200);

      final restored = (await f.member.list('overlays')).single;
      expect(restored['deleted'], isFalse);
      expect(restored['revision'], greaterThan(removed['revision'] as int));
      expect((await f.admin.list('overlays')).single['deleted'], isTrue);
    },
  );

  test('the keyboard program has its own field that older clients keep '
      '(ADR-0039)', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    const program = {'msb': 0, 'lsb': 2, 'program': 12};

    final created = await f.member.post('overlays', {
      ...overlay(f.member, song),
      'midi': program,
    });
    created.expectStatus(200);
    final id = created.json['id'] as String;
    expect(created.json['midi'], program);
    expect((created.json['data'] as Map).containsKey('midi'), isFalse);

    // An older client pushes only data and deleted.
    final older = await f.member.patch('overlays', id, {
      'data': {'transpose': -1},
      'deleted': false,
    });
    older.expectStatus(200);
    expect(older.json['midi'], program);
    expect(older.json['data'], {'transpose': -1});
    expect(
      older.json['revision'],
      greaterThan(created.json['revision'] as int),
    );
    expect((await f.member.list('overlays')).single['midi'], program);

    // A newer client changes or removes it.
    final changed = await f.member.patch('overlays', id, {
      'data': {'transpose': -1},
      'midi': {'program': 5},
      'deleted': false,
    });
    changed.expectStatus(200);
    expect(changed.json['midi'], {'program': 5});
    final removed = await f.member.patch('overlays', id, {'midi': null});
    removed.expectStatus(200);
    expect(removed.json['midi'], isNull);

    // Private like the rest of the overlay.
    expect(
      (await f.admin.patch('overlays', id, {'midi': program})).status,
      404,
    );
  });

  test('the keyboard programs per profile have their own field that '
      'v0.16.0 clients keep (ADR-0042)', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    const programs = {
      'nordStage3': {'msb': 0, 'lsb': 2, 'program': 12},
      'motifXf': {'msb': 63, 'lsb': 8, 'program': 0},
    };

    final created = await f.member.post('overlays', {
      ...overlay(f.member, song),
      'midi_programs': programs,
    });
    created.expectStatus(200);
    final id = created.json['id'] as String;
    expect(created.json['midi_programs'], programs);
    expect(created.json['midi'], isNull);

    // A v0.16.0 client pushes data, deleted and its single program.
    final older = await f.member.patch('overlays', id, {
      'data': {'transpose': 2},
      'midi': {'program': 5},
      'deleted': false,
    });
    older.expectStatus(200);
    expect(older.json['midi_programs'], programs);
    expect(older.json['midi'], {'program': 5});

    // A newer client changes or removes them.
    final changed = await f.member.patch('overlays', id, {
      'midi_programs': {
        'generic': {'program': 7},
      },
    });
    changed.expectStatus(200);
    expect(changed.json['midi_programs'], {
      'generic': {'program': 7},
    });
    // An empty map (all removed) stays empty, not "never written", so a
    // v0.16.0 program in `midi` does not count again.
    final emptied = await f.member.patch('overlays', id, {
      'midi_programs': <String, dynamic>{},
    });
    emptied.expectStatus(200);
    expect(emptied.json['midi_programs'], <String, dynamic>{});
    final removed = await f.member.patch('overlays', id, {
      'midi_programs': null,
    });
    removed.expectStatus(200);
    expect(removed.json['midi_programs'], isNull);

    // Private like the rest of the overlay.
    expect(
      (await f.admin.patch('overlays', id, {'midi_programs': programs})).status,
      404,
    );
  });

  test('an overlay without a keyboard program has none', () async {
    final f = await BandFixture.create(pb);
    final song = (await f.createSong(f.admin))['id'] as String;
    final created = await f.member.post('overlays', overlay(f.member, song));
    created.expectStatus(200);
    expect(created.json['midi'], isNull);
  });
}
