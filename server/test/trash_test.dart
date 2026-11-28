import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'package:setding_server/pocketbase_harness.dart';

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

// Trash of ADR-0043: `deleted_at`, `purged` and the purge after 30 days.
void main() {
  late PocketBase pb;

  setUpAll(() async => pb = await PocketBase.start());
  tearDownAll(() => pb.stop());

  Future<int> purge() async {
    final r = await pb.superuser.send('POST', '/api/setding/trash/purge');
    r.expectStatus(200);
    return r.json['purged'] as int;
  }

  /// Moves the deletion of a record [days] into the past, as a superuser.
  Future<void> age(String collection, String id, int days) async {
    final at = DateTime.now().toUtc().subtract(Duration(days: days));
    (await pb.superuser.patch(collection, id, {
      'deleted_at': at.toIso8601String().replaceFirst('T', ' '),
    })).expectStatus(200);
  }

  test('deleting records the time, restoring clears it', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final sent = DateTime.utc(2026, 11, 1, 12);
    final deleted = await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'deleted_at': sent.toIso8601String(),
      'revision': song['revision'],
    });
    deleted.expectStatus(200);
    expect(
      DateTime.parse(deleted.json['deleted_at'] as String),
      sent,
      reason: 'the client time of an offline deletion is kept',
    );
    final restored = await f.admin.patch('songs', song['id'], {
      'deleted': false,
      'revision': deleted.json['revision'],
    });
    restored.expectStatus(200);
    expect(restored.json['deleted_at'], '');
  });

  test('a deletion time in the future or missing becomes now', () async {
    final f = await BandFixture.create(pb);
    final set = await f.admin.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': 'Gig',
    });
    final deleted = await f.admin.patch('setlists', set.json['id'], {
      'deleted': true,
      'deleted_at': '2099-01-01 00:00:00.000Z',
    });
    deleted.expectStatus(200);
    final at = DateTime.parse(deleted.json['deleted_at'] as String);
    expect(at.difference(DateTime.now()).inMinutes.abs(), lessThan(5));
  });

  test('clients cannot set purged', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final r = await f.admin.patch('songs', song['id'], {
      'purged': true,
      'revision': song['revision'],
    });
    r.expectStatus(200);
    expect(r.json['purged'], isFalse);
  });

  group('deleting permanently (#866)', () {
    test('a librarian purges a deleted song with its attachments', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      final upload = await f.admin.postMultipart(
        'attachments',
        {
          'id': uuid(),
          'organization': f.orgId,
          'song': song['id'],
          'name': 'Score',
          'pages': '1',
          'size_bytes': '${_pdf.length}',
        },
        fileField: 'file',
        bytes: _pdf,
        filename: 'score.pdf',
        contentType: 'application/pdf',
      );
      upload.expectStatus(200);
      final deleted = await f.member.patch('songs', song['id'], {
        'deleted': true,
        'revision': song['revision'],
      });
      deleted.expectStatus(200);
      final at = deleted.json['deleted_at'];
      final purged = await f.member.patch('songs', song['id'], {
        'deleted': true,
        'purged': true,
        'revision': deleted.json['revision'],
      });
      purged.expectStatus(200);
      final stored = await pb.superuser.view('songs', song['id']);
      expect(stored.json['purged'], isTrue);
      expect(stored.json['deleted'], isTrue);
      expect(stored.json['chordpro'], '');
      expect(stored.json['deleted_at'], at);
      final file = await pb.superuser.view('attachments', upload.json['id']);
      expect(file.json['purged'], isTrue);
      expect(file.json['deleted'], isTrue);
      expect(file.json['file'], '');
    });

    test(
      'a song deleted and purged offline is purged in one request',
      () async {
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final r = await f.admin.patch('songs', song['id'], {
          'deleted': true,
          'purged': true,
          'revision': song['revision'],
        });
        r.expectStatus(200);
        expect(r.json['purged'], isTrue);
        expect(r.json['chordpro'], '');
      },
    );

    test('a set manager purges a deleted set', () async {
      final f = await BandFixture.create(pb);
      final planner = await f.addPlanner();
      final set = await f.admin.post('setlists', {
        'id': uuid(),
        'band': f.id,
        'name': 'Gig',
        'items': [
          {'id': uuid(), 'type': 'pause', 'note': 'Break'},
        ],
      });
      set.expectStatus(200);
      (await planner.patch('setlists', set.json['id'], {
        'deleted': true,
      })).expectStatus(200);
      final r = await planner.patch('setlists', set.json['id'], {
        'deleted': true,
        'purged': true,
      });
      r.expectStatus(200);
      final stored = await pb.superuser.view('setlists', set.json['id']);
      expect(stored.json['purged'], isTrue);
      expect(stored.json['items'], isEmpty);
    });

    test('purged is ignored on a set that is not deleted', () async {
      final f = await BandFixture.create(pb);
      final set = await f.admin.post('setlists', {
        'id': uuid(),
        'band': f.id,
        'name': 'Gig',
      });
      final r = await f.admin.patch('setlists', set.json['id'], {
        'purged': true,
      });
      r.expectStatus(200);
      expect(r.json['purged'], isFalse);
      expect(r.json['deleted'], isFalse);
    });

    Future<Response> uploadTo(BandFixture f, Client client, String song) =>
        client.postMultipart(
          'attachments',
          {
            'id': uuid(),
            'organization': f.orgId,
            'song': song,
            'name': 'Score',
            'pages': '1',
            'size_bytes': '${_pdf.length}',
          },
          fileField: 'file',
          bytes: _pdf,
          filename: 'score.pdf',
          contentType: 'application/pdf',
        );

    test('a librarian purges a single deleted attachment (ADR-0070)', () async {
      final f = await BandFixture.create(pb, memberIsLibrarian: true);
      final song = await f.createSong(f.admin);
      final upload = await uploadTo(f, f.admin, song['id'] as String);
      upload.expectStatus(200);
      final id = upload.json['id'] as String;
      // Not deleted: `purged` is ignored.
      final kept = await f.member.patch('attachments', id, {'purged': true});
      kept.expectStatus(200);
      expect(kept.json['purged'], isFalse);
      expect(kept.json['file'], isNotEmpty);

      final r = await f.member.patch('attachments', id, {
        'deleted': true,
        'purged': true,
      });
      r.expectStatus(200);
      expect(r.json['purged'], isTrue);
      expect(r.json['file'], '');
      final stored = await pb.superuser.view('attachments', id);
      expect(stored.json['purged'], isTrue);
      expect(stored.json['deleted'], isTrue);
      expect(stored.json['file'], '');
      expect(
        Directory(
          '${pb.dataDir}/storage/${upload.json['collectionId']}/$id',
        ).listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
      // The song stays in the library.
      expect(
        (await pb.superuser.view('songs', song['id'])).json['deleted'],
        isFalse,
      );
      // A purged attachment cannot be restored.
      final restore = await f.member.patch('attachments', id, {
        'deleted': false,
      });
      expect(restore.status, 400);
    });

    test(
      'a band leader cannot purge an attachment of their own song',
      () async {
        final f = await BandFixture.create(pb);
        final leader = await f.addLeader();
        final song = await f.createSong(leader);
        final upload = await uploadTo(f, leader, song['id'] as String);
        upload.expectStatus(200);
        final id = upload.json['id'] as String;
        (await f.admin.patch('attachments', id, {
          'deleted': true,
        })).expectStatus(200);
        final r = await leader.patch('attachments', id, {
          'deleted': true,
          'purged': true,
        });
        expect(r.status, greaterThanOrEqualTo(400));
        final stored = await pb.superuser.view('attachments', id);
        expect(stored.json['purged'], isFalse);
        expect(stored.json['file'], isNotEmpty);
      },
    );
  });

  test('a deleted set keeps its items for a restore', () async {
    final f = await BandFixture.create(pb);
    final items = [
      {'id': uuid(), 'type': 'pause', 'note': 'Break'},
    ];
    final set = await f.admin.post('setlists', {
      'id': uuid(),
      'band': f.id,
      'name': 'Gig',
      'items': items,
    });
    (await f.admin.patch('setlists', set.json['id'], {
      'deleted': true,
    })).expectStatus(200);
    final restored = await f.admin.patch('setlists', set.json['id'], {
      'deleted': false,
    });
    restored.expectStatus(200);
    expect(restored.json['items'], items);
  });

  test('the purge empties old deletions and keeps a tombstone', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final kept = await f.createSong(f.admin);
    final upload = await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'name': 'Score',
        'pages': '1',
        'size_bytes': '${_pdf.length}',
      },
      fileField: 'file',
      bytes: _pdf,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    );
    upload.expectStatus(200);
    final attachmentId = upload.json['id'] as String;
    final recent = await f.createSong(f.admin);
    final deleted = await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    });
    deleted.expectStatus(200);
    (await f.admin.patch('attachments', attachmentId, {
      'deleted': true,
    })).expectStatus(200);
    (await f.admin.patch('songs', recent['id'], {
      'deleted': true,
      'revision': recent['revision'],
    })).expectStatus(200);
    await age('songs', song['id'] as String, 31);
    await age('attachments', attachmentId, 31);
    await age('songs', recent['id'] as String, 29);

    expect(await purge(), greaterThanOrEqualTo(2));

    final purged = await f.admin.view('songs', song['id']);
    purged.expectStatus(200);
    expect(purged.json['purged'], isTrue);
    expect(purged.json['deleted'], isTrue);
    expect(purged.json['chordpro'], '');
    expect(
      purged.json['revision'] as int,
      greaterThan(deleted.json['revision'] as int),
      reason: 'devices pull the tombstone',
    );
    final file = await f.admin.view('attachments', attachmentId);
    expect(file.json['purged'], isTrue);
    expect(file.json['file'], '');
    final recentNow = await f.admin.view('songs', recent['id']);
    expect(recentNow.json['purged'], isFalse);
    expect(recentNow.json['chordpro'], isNotEmpty);
    expect((await f.admin.view('songs', kept['id'])).json['purged'], isFalse);
  });

  test('purging a song purges its attachments', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final upload = await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'name': 'Score',
        'pages': '1',
        'size_bytes': '${_pdf.length}',
      },
      fileField: 'file',
      bytes: _pdf,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    );
    upload.expectStatus(200);
    (await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    })).expectStatus(200);
    await age('songs', song['id'] as String, 31);
    await purge();
    final file = await f.admin.view('attachments', upload.json['id']);
    expect(file.json['purged'], isTrue);
    expect(file.json['deleted'], isTrue);
    expect(file.json['file'], '');
  });

  test('purged records cannot be restored', () async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    (await f.admin.patch('songs', song['id'], {
      'deleted': true,
      'revision': song['revision'],
    })).expectStatus(200);
    await age('songs', song['id'] as String, 40);
    await purge();
    final current = await f.admin.view('songs', song['id']);
    final r = await f.admin.patch('songs', song['id'], {
      'deleted': false,
      'revision': current.json['revision'],
    });
    expect(r.status, 400);
  });

  test('only superusers start the purge', () async {
    final f = await BandFixture.create(pb);
    final r = await f.admin.send('POST', '/api/setding/trash/purge');
    expect(r.status, anyOf(401, 403));
  });
}
