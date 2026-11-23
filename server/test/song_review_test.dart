import 'dart:convert';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// A 1×1 PNG, as a stand-in for a screenshot.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Song review status and mistake reports (ADR-0060, #987).
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<Map<String, dynamic>> view(String collection, String id) async =>
      (await pb.superuser.view(collection, id)).json;

  Map<String, dynamic> report(
    BandFixture f,
    String song, {
    String comment = 'Wrong chord',
  }) => {
    'id': uuid(),
    'song': song,
    'organization': f.orgId,
    'category': 'chords',
    'comment': comment,
    'location': {'section': 'Verse 1', 'line': 3},
  };

  group('review status', () {
    test('an import creates songs to review, with who and when', () async {
      final f = await BandFixture.create(pb);
      final r = await f.admin.post('songs', {
        'id': uuid(),
        'organization': f.orgId,
        'title': 'Imported',
        'review_state': 'to_review',
        'review_reason': 'After import',
      });
      r.expectStatus(200);
      expect(r.json['review_state'], 'to_review');
      expect(r.json['review_reason'], 'After import');
      expect(r.json['reviewed_by'], f.admin.id);
      expect(r.json['reviewed_at'], isNotEmpty);
    });

    test('a song without a review state is approved', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      expect(song['review_state'], '');
      expect(song['reviewed_by'], '');
      expect(song['reviewed_at'], '');
    });

    test('approving needs no base revision, keeps the content revision '
        'and the last editor', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final leader = await f.addLeader();
      final song = await leader.post('songs', {
        'id': uuid(),
        'organization': f.orgId,
        'title': 'Leader song',
        'review_state': 'to_review',
        'review_reason': 'After import',
      });
      song.expectStatus(200);
      final approved = await f.member.patch(
        'songs',
        song.json['id'] as String,
        {'review_state': ''},
      );
      approved.expectStatus(200);
      expect(approved.json['review_state'], '');
      expect(approved.json['review_reason'], '', reason: 'cleared');
      expect(approved.json['reviewed_by'], f.member.id);
      expect(approved.json['updated_by'], leader.id);
      expect(approved.json['content_revision'], song.json['content_revision']);
      expect(
        approved.json['revision'],
        greaterThan(song.json['revision'] as int),
      );
    });

    test('a text change after an approval is no conflict', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      (await f.member.patch('songs', song['id'] as String, {
        'review_state': 'to_review',
        'review_reason': 'Check the bridge',
      })).expectStatus(200);
      final r = await f.admin.patch('songs', song['id'] as String, {
        'chordpro': '{title: Song}\nChanged',
        'revision': song['revision'],
      });
      r.expectStatus(200);
      expect(r.json['review_state'], 'to_review');
      expect(r.json['reviewed_by'], f.member.id, reason: 'kept');
    });

    test('who reviewed and when cannot be forged', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      final r = await f.admin.patch('songs', song['id'] as String, {
        'review_state': 'to_review',
        'reviewed_by': f.member.id,
        'reviewed_at': '2020-01-01 00:00:00.000Z',
        // Sent with other fields, a base revision is needed.
        'revision': song['revision'],
      });
      r.expectStatus(200);
      expect(r.json['reviewed_by'], f.admin.id);
      expect(r.json['reviewed_at'], isNot(startsWith('2020')));
      final kept = await f.admin.patch('songs', song['id'] as String, {
        'reviewed_by': f.member.id,
        'revision': r.json['revision'],
      });
      kept.expectStatus(200);
      expect(kept.json['reviewed_by'], f.admin.id);
    });

    test('band leaders approve their own songs', () async {
      final f = await BandFixture.create(pb);
      final leader = await f.addLeader();
      final song = await f.createSong(leader);
      (await leader.patch('songs', song['id'] as String, {
        'review_state': 'to_review',
      })).expectStatus(200);
      (await leader.patch('songs', song['id'] as String, {
        'review_state': '',
      })).expectStatus(200);
    });

    test('unknown review states are refused', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final r = await f.admin.patch('songs', song['id'] as String, {
        'review_state': 'approved',
      });
      expect(r.status, 400);
    });
  });

  group('reports', () {
    late BandFixture f;
    late Map<String, dynamic> song;
    late User other; // a second member of the organization
    late User planner;
    late User leader;

    setUpAll(() async {
      f = await BandFixture.create(pb, memberIsLibrarian: false);
      song = await f.createSong(f.admin);
      other = await pb.signUp('Other');
      await BandFixture.addMember(pb, f.id, other);
      planner = await f.addPlanner();
      leader = await f.addLeader();
    });

    test(
      'members report a mistake; the server sets author and status',
      () async {
        final r = await f.member.post('song_reports', report(f, song['id']));
        r.expectStatus(200);
        expect(r.json['author'], f.member.id);
        expect(r.json['status'], 'open');
        expect(r.json['revision'], greaterThan(0));
        expect(r.json['updated_by'], f.member.id);
        expect((r.json['location'] as Map)['section'], 'Verse 1');
      },
    );

    test('members see only their own reports, the others all', () async {
      final mine = await f.member.post('song_reports', report(f, song['id']));
      mine.expectStatus(200);
      final theirs = await other.post('song_reports', report(f, song['id']));
      theirs.expectStatus(200);
      final filter = 'song = "${song['id']}"';
      final seen = (await f.member.list(
        'song_reports',
        filter: filter,
      )).map((r) => r['id']).toSet();
      expect(seen, contains(mine.json['id']));
      expect(seen, isNot(contains(theirs.json['id'])));
      expect(
        (await f.member.view('song_reports', theirs.json['id'])).status,
        404,
      );
      for (final user in [f.admin, planner, leader]) {
        final ids = (await user.list(
          'song_reports',
          filter: filter,
        )).map((r) => r['id']).toSet();
        expect(ids, containsAll([mine.json['id'], theirs.json['id']]));
      }
      expect(await f.outsider.list('song_reports', filter: filter), isEmpty);
    });

    test('the author changes and withdraws an open report', () async {
      final r = await f.member.post('song_reports', report(f, song['id']));
      final id = r.json['id'] as String;
      final changed = await f.member.patch('song_reports', id, {
        'comment': 'Wrong chord in bar 3',
        'category': 'lyrics',
      });
      changed.expectStatus(200);
      expect(changed.json['comment'], 'Wrong chord in bar 3');
      final withdrawn = await f.member.patch('song_reports', id, {
        'status': 'withdrawn',
      });
      withdrawn.expectStatus(200);
      expect(withdrawn.json['status'], 'withdrawn');
      expect(withdrawn.json['resolved_by'], '');
      final later = await f.member.patch('song_reports', id, {
        'comment': 'Again',
      });
      expect(later.status, greaterThanOrEqualTo(400));
      expect(
        (await view('song_reports', id))['comment'],
        'Wrong chord in bar 3',
      );
    });

    test(
      'approvers resolve with an answer; who and when by the server',
      () async {
        final r = await f.member.post('song_reports', report(f, song['id']));
        final id = r.json['id'] as String;
        final resolved = await f.admin.patch('song_reports', id, {
          'status': 'resolved',
          'resolution': 'Fixed, thanks',
          'resolved_by': f.member.id,
        });
        expect(resolved.status, greaterThanOrEqualTo(400), reason: 'forged');
        final ok = await f.admin.patch('song_reports', id, {
          'status': 'resolved',
          'resolution': 'Fixed, thanks',
        });
        ok.expectStatus(200);
        expect(ok.json['resolved_by'], f.admin.id);
        expect(ok.json['resolved_at'], isNotEmpty);
        expect(ok.json['author'], f.member.id);
        // A resolved report is history: the author cannot change it.
        final edit = await f.member.patch('song_reports', id, {
          'comment': 'More',
        });
        expect(edit.status, greaterThanOrEqualTo(400));
        // Opened again, it has no resolver.
        final reopened = await f.admin.patch('song_reports', id, {
          'status': 'open',
        });
        reopened.expectStatus(200);
        expect(reopened.json['resolved_by'], '');
        expect(reopened.json['resolved_at'], '');
      },
    );

    test('band leaders resolve reports of their own songs', () async {
      final own = await f.createSong(leader, title: 'Own');
      final r = await f.member.post('song_reports', report(f, own['id']));
      (await leader.patch('song_reports', r.json['id'], {
        'status': 'resolved',
      })).expectStatus(200);
    });

    test(
      'a screenshot is added once, also later, and never replaced',
      () async {
        final created = await f.member.postMultipart(
          'song_reports',
          {
            'id': uuid(),
            'song': song['id'] as String,
            'organization': f.orgId,
            'category': 'chords',
          },
          fileField: 'screenshot',
          bytes: _png,
          filename: 'shot.png',
          contentType: 'image/png',
        );
        created.expectStatus(200);
        expect(created.json['screenshot'], isNotEmpty);
        final replaced = await f.member.patchMultipart(
          'song_reports',
          created.json['id'] as String,
          {},
          fileField: 'screenshot',
          bytes: _png,
          filename: 'other.png',
          contentType: 'image/png',
        );
        expect(replaced.status, 400);

        final later = await f.member.post(
          'song_reports',
          report(f, song['id']),
        );
        later.expectStatus(200);
        final added = await f.member.patchMultipart(
          'song_reports',
          later.json['id'] as String,
          {},
          fileField: 'screenshot',
          bytes: _png,
          filename: 'shot.png',
          contentType: 'image/png',
        );
        added.expectStatus(200);
        expect(added.json['screenshot'], isNotEmpty);
      },
    );

    test('reports follow their song into the trash and back', () async {
      final s = await f.createSong(f.admin, title: 'Trash');
      final r = await f.member.post('song_reports', report(f, s['id']));
      final id = r.json['id'] as String;
      final deleted = await f.admin.patch('songs', s['id'] as String, {
        'deleted': true,
        'revision': s['revision'],
      });
      deleted.expectStatus(200);
      expect((await view('song_reports', id))['deleted'], isTrue);
      expect(
        (await f.member.post('song_reports', report(f, s['id']))).status,
        greaterThanOrEqualTo(400),
        reason: 'no reports on deleted songs',
      );
      final restored = await f.admin.patch('songs', s['id'] as String, {
        'deleted': false,
        'revision': deleted.json['revision'],
      });
      restored.expectStatus(200);
      expect((await view('song_reports', id))['deleted'], isFalse);
    });

    test('purging a song purges its reports and screenshots', () async {
      final s = await f.createSong(f.admin, title: 'Purge');
      final r = await f.member.postMultipart(
        'song_reports',
        {
          'id': uuid(),
          'song': s['id'] as String,
          'organization': f.orgId,
          'category': 'other',
          'comment': 'Secret',
        },
        fileField: 'screenshot',
        bytes: _png,
        filename: 'shot.png',
        contentType: 'image/png',
      );
      r.expectStatus(200);
      final deleted = await f.admin.patch('songs', s['id'] as String, {
        'deleted': true,
        'revision': s['revision'],
      });
      (await f.admin.patch('songs', s['id'] as String, {
        'deleted': true,
        'purged': true,
        'revision': deleted.json['revision'],
      })).expectStatus(200);
      final stored = await view('song_reports', r.json['id'] as String);
      expect(stored['purged'], isTrue);
      expect(stored['deleted'], isTrue);
      expect(stored['comment'], '');
      expect(stored['screenshot'], '');
    });

    test('the daily purge purges the reports of old deleted songs', () async {
      final s = await f.createSong(f.admin, title: 'Old');
      final r = await f.member.post('song_reports', report(f, s['id']));
      r.expectStatus(200);
      (await f.admin.patch('songs', s['id'] as String, {
        'deleted': true,
        'deleted_at': '2000-01-01 00:00:00.000Z',
        'revision': s['revision'],
      })).expectStatus(200);
      (await pb.superuser.send(
        'POST',
        '/api/setding/trash/purge',
      )).expectStatus(200);
      final stored = await view('song_reports', r.json['id'] as String);
      expect(stored['purged'], isTrue);
      expect(stored['comment'], '');
    });
  });
}
