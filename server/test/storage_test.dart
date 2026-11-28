// Storage limit per organization (ADR-0070, issue #1226): server-set
// sizes, the limit in the create hook (also for parallel uploads), the
// storage route for each role and the purge of a single attachment.
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const _kb = 1024;
const _mb = 1024 * 1024;

final _header = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// A PDF of exactly [size] bytes.
List<int> _pdf(int size) => [
  ..._header,
  ...List<int>.filled(size - _header.length, 32),
];

Future<Response> _upload(
  Client client,
  String org,
  String song, {
  required int size,
  String? id,
  int? claimedSize,
}) => client.postMultipart(
  'attachments',
  {
    'id': id ?? uuid(),
    'organization': org,
    'song': song,
    'name': 'Score',
    'pages': '1',
    'size_bytes': '${claimedSize ?? size}',
  },
  fileField: 'file',
  bytes: _pdf(size),
  filename: 'score.pdf',
  contentType: 'application/pdf',
);

void _expectStorageFull(Response r) {
  expect(r.status, 400, reason: '${r.json}');
  final file = (r.json['data'] as Map<String, dynamic>)['file'] as Map;
  expect(file['code'], 'storage_limit_reached');
}

/// The files PocketBase keeps for the attachment [id].
List<FileSystemEntity> _storedFiles(
  PocketBase pb,
  String collectionId,
  String id,
) {
  final dir = Directory('${pb.dataDir}/storage/$collectionId/$id');
  if (!dir.existsSync()) return const [];
  return dir.listSync(recursive: true).whereType<File>().toList();
}

Future<Map<String, dynamic>> _storage(Client client, String org) async {
  final r = await client.send('GET', '/api/setding/organizations/$org/storage');
  r.expectStatus(200);
  return r.json;
}

void main() {
  group('with a limit of 1 MB', () {
    late PocketBase pb;

    setUpAll(
      () async => pb = await PocketBase.start(
        environment: {'SETDING_ORG_STORAGE_LIMIT_MB': '1'},
      ),
    );
    tearDownAll(() => pb.stop());

    test(
      'the server sets size_bytes from the file; users cannot change it',
      () async {
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final r = await _upload(
          f.admin,
          f.orgId,
          song['id'],
          size: 10 * _kb,
          claimedSize: 1,
        );
        r.expectStatus(200);
        expect(r.json['size_bytes'], 10 * _kb);
        final id = r.json['id'] as String;
        (await f.admin.patch('attachments', id, {
          'size_bytes': 1,
          'name': 'Renamed',
        })).expectStatus(200);
        final stored = await pb.superuser.view('attachments', id);
        expect(stored.json['size_bytes'], 10 * _kb);
        expect(stored.json['name'], 'Renamed');
      },
    );

    test('an upload over the limit is refused with storage_limit_reached '
        'and leaves no file behind', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final first = await _upload(
        f.admin,
        f.orgId,
        song['id'],
        size: 600 * _kb,
      );
      first.expectStatus(200);
      final collectionId = first.json['collectionId'] as String;

      final id = uuid();
      final refused = await _upload(
        f.admin,
        f.orgId,
        song['id'],
        size: 600 * _kb,
        id: id,
        claimedSize: 1,
      );
      _expectStorageFull(refused);
      final records = await pb.superuser.list(
        'attachments',
        filter: 'id = "$id"',
      );
      expect(records, isEmpty);
      expect(_storedFiles(pb, collectionId, id), isEmpty);

      // What still fits is accepted.
      (await _upload(
        f.admin,
        f.orgId,
        song['id'],
        size: 400 * _kb,
      )).expectStatus(200);
    });

    test(
      'each organization has its own limit; superusers are not limited',
      () async {
        final f = await BandFixture.create(pb);
        final g = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final other = await g.createSong(g.admin);
        (await _upload(
          f.admin,
          f.orgId,
          song['id'],
          size: 900 * _kb,
        )).expectStatus(200);
        (await _upload(
          g.admin,
          g.orgId,
          other['id'],
          size: 900 * _kb,
        )).expectStatus(200);
        _expectStorageFull(
          await _upload(f.admin, f.orgId, song['id'], size: 200 * _kb),
        );
        (await _upload(
          pb.superuser,
          f.orgId,
          song['id'],
          size: 200 * _kb,
        )).expectStatus(200);
      },
    );

    test('parallel uploads at the limit: only one succeeds', () async {
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin);
      final results = await Future.wait([
        for (var i = 0; i < 6; i++)
          _upload(f.admin, f.orgId, song['id'], size: 600 * _kb),
      ]);
      final ok = results.where((r) => r.status == 200).toList();
      expect(ok, hasLength(1), reason: '${results.map((r) => r.status)}');
      for (final r in results.where((r) => r.status != 200)) {
        _expectStorageFull(r);
      }
      final stored = await pb.superuser.list(
        'attachments',
        filter: 'organization = "${f.orgId}"',
      );
      expect(stored, hasLength(1));
      // No file of a refused upload is left in the storage.
      final collectionId = ok.single.json['collectionId'] as String;
      final dirs = Directory('${pb.dataDir}/storage/$collectionId')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toSet();
      final known = (await pb.superuser.list(
        'attachments',
      )).map((a) => a['id'] as String).toSet();
      expect(dirs.difference(known), isEmpty);
    });

    test(
      'the trash counts until it is purged; a purge frees the space',
      () async {
        final f = await BandFixture.create(pb, memberIsLibrarian: true);
        final song = await f.createSong(f.admin);
        final first = await _upload(
          f.admin,
          f.orgId,
          song['id'],
          size: 900 * _kb,
        );
        first.expectStatus(200);
        final id = first.json['id'] as String;
        (await f.member.patch('attachments', id, {
          'deleted': true,
        })).expectStatus(200);
        _expectStorageFull(
          await _upload(f.admin, f.orgId, song['id'], size: 200 * _kb),
        );
        // Everything else still works at the limit (ADR-0070 §5).
        (await f.admin.patch('songs', song['id'], {
          'title': 'Still editable',
          'revision': song['revision'],
        })).expectStatus(200);
        (await f.member.patch('attachments', id, {
          'deleted': false,
        })).expectStatus(200);
        (await f.member.patch('attachments', id, {
          'deleted': true,
        })).expectStatus(200);

        final purged = await f.member.patch('attachments', id, {
          'deleted': true,
          'purged': true,
        });
        purged.expectStatus(200);
        expect(purged.json['purged'], isTrue);
        expect(purged.json['file'], '');
        expect(
          _storedFiles(pb, first.json['collectionId'] as String, id),
          isEmpty,
        );
        (await _upload(
          f.admin,
          f.orgId,
          song['id'],
          size: 900 * _kb,
        )).expectStatus(200);
      },
    );

    test(
      'a file over 1 MB gets the size validation error, not the limit',
      () async {
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        final r = await _upload(f.admin, f.orgId, song['id'], size: _mb + 1);
        expect(r.status, 400);
        final file = (r.json['data'] as Map<String, dynamic>)['file'] as Map;
        expect(file['code'], isNot('storage_limit_reached'));
        expect(file['code'], 'validation_file_size_limit');
      },
    );
  });

  group('storage route', () {
    late PocketBase pb;
    late BandFixture f;
    late User leader;
    late User planner;
    late User librarian;

    setUpAll(() async {
      pb = await PocketBase.start();
      f = await BandFixture.create(pb);
      leader = await f.addLeader();
      planner = await f.addPlanner();
      librarian = await pb.signUp('Librarian');
      await BandFixture.addOrgMember(pb, f.orgId, librarian, role: 'librarian');
      final live = await f.createSong(f.admin);
      final deletedSong = await f.createSong(f.admin, title: 'Deleted');
      (await _upload(
        f.admin,
        f.orgId,
        live['id'],
        size: 10 * _kb,
      )).expectStatus(200);
      final trashed = await _upload(
        f.admin,
        f.orgId,
        live['id'],
        size: 20 * _kb,
      );
      trashed.expectStatus(200);
      (await f.admin.patch('attachments', trashed.json['id'], {
        'deleted': true,
      })).expectStatus(200);
      (await _upload(
        f.admin,
        f.orgId,
        deletedSong['id'],
        size: 30 * _kb,
      )).expectStatus(200);
      (await f.admin.patch('songs', deletedSong['id'], {
        'deleted': true,
        'revision': deletedSong['revision'],
      })).expectStatus(200);
      final purged = await _upload(
        f.admin,
        f.orgId,
        live['id'],
        size: 40 * _kb,
      );
      purged.expectStatus(200);
      (await f.admin.patch('attachments', purged.json['id'], {
        'deleted': true,
        'purged': true,
      })).expectStatus(200);
    });
    tearDownAll(() => pb.stop());

    test('organization admins, librarians and band leaders read the usage, '
        'including the trash', () async {
      for (final user in [f.admin, librarian, leader]) {
        final s = await _storage(user, f.orgId);
        expect(s['used_bytes'], 60 * _kb);
        expect(s['live_bytes'], 10 * _kb);
        expect(s['trash_bytes'], 50 * _kb);
        expect(s['limit_bytes'], 25 * _mb);
      }
    });

    test('everyone else gets 404', () async {
      final g = await BandFixture.create(pb);
      final formerLeader = await f.addLeader();
      (await pb.superuser.patch(
        'memberships',
        (await f.membershipOf(formerLeader))['id'] as String,
        {'deleted': true},
      )).expectStatus(200);
      for (final user in [
        f.member,
        planner,
        f.outsider,
        g.admin,
        formerLeader,
      ]) {
        final r = await user.send(
          'GET',
          '/api/setding/organizations/${f.orgId}/storage',
        );
        expect(r.status, 404, reason: user.id);
      }
      final anonymous = await pb.guest.send(
        'GET',
        '/api/setding/organizations/${f.orgId}/storage',
      );
      expect(anonymous.status, greaterThanOrEqualTo(400));
    });

    test('a closed organization answers 404', () async {
      final c = await BandFixture.create(pb);
      (await c.admin.delete('organizations', c.orgId)).expectStatus(204);
      final r = await c.admin.send(
        'GET',
        '/api/setding/organizations/${c.orgId}/storage',
      );
      expect(r.status, 404);
    });
  });

  group('without a limit', () {
    for (final value in ['0', 'off']) {
      test('SETDING_ORG_STORAGE_LIMIT_MB=$value', () async {
        final pb = await PocketBase.start(
          environment: {'SETDING_ORG_STORAGE_LIMIT_MB': value},
        );
        addTearDown(pb.stop);
        final f = await BandFixture.create(pb);
        final song = await f.createSong(f.admin);
        for (var i = 0; i < 3; i++) {
          (await _upload(
            f.admin,
            f.orgId,
            song['id'],
            size: _mb,
          )).expectStatus(200);
        }
        final s = await _storage(f.admin, f.orgId);
        expect(s['limit_bytes'], isNull);
        expect(s['used_bytes'], 3 * _mb);
      });
    }
  });

  test('an invalid limit stops the start with a message', () async {
    for (final value in ['lots', '-1', '1.5', '25MB']) {
      await expectLater(
        PocketBase.start(environment: {'SETDING_ORG_STORAGE_LIMIT_MB': value}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('SETDING_ORG_STORAGE_LIMIT_MB must be a whole number'),
          ),
        ),
      );
    }
  });

  test('the migration fills in size_bytes and keeps larger files', () async {
    var pb = await PocketBase.start(
      migrationsBefore: '1797500000_storage_limit.js',
    );
    addTearDown(() => pb.stop());
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin);
    final big = await _upload(
      f.admin,
      f.orgId,
      song['id'],
      size: 2 * _mb,
      claimedSize: 7,
    );
    big.expectStatus(200);
    // A record from before the migration, with the size the client sent.
    (await pb.superuser.patch('attachments', big.json['id'] as String, {
      'size_bytes': 7,
    })).expectStatus(200);
    final screenshot = await f.member.postMultipart(
      'song_reports',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'category': 'chords',
      },
      fileField: 'screenshot',
      bytes: _png(500 * _kb),
      filename: 'shot.png',
      contentType: 'image/png',
    );
    screenshot.expectStatus(200);

    pb = await pb.upgrade();
    final admin = await signIn(pb, f.admin);
    final member = await signIn(pb, f.member);
    final id = big.json['id'] as String;
    final stored = await pb.superuser.view('attachments', id);
    expect(stored.json['size_bytes'], 2 * _mb);
    expect(stored.json['file'], big.json['file']);
    // The larger file stays and its record can still be changed.
    (await admin.patch('attachments', id, {
      'name': 'Renamed',
    })).expectStatus(200);
    final report = await pb.superuser.view(
      'song_reports',
      screenshot.json['id'] as String,
    );
    expect(report.json['screenshot'], screenshot.json['screenshot']);
    // New uploads over the maximum sizes are refused.
    expect(
      (await _upload(admin, f.orgId, song['id'], size: 2 * _mb)).status,
      400,
    );
    final tooLarge = await member.postMultipart(
      'song_reports',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'category': 'chords',
      },
      fileField: 'screenshot',
      bytes: _png(301 * _kb),
      filename: 'shot.png',
      contentType: 'image/png',
    );
    expect(tooLarge.status, 400);
    final fits = await member.postMultipart(
      'song_reports',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': song['id'],
        'category': 'chords',
      },
      fileField: 'screenshot',
      bytes: _png(300 * _kb),
      filename: 'shot.png',
      contentType: 'image/png',
    );
    fits.expectStatus(200);
  });
}

/// A PNG signature padded to [size] bytes; PocketBase detects the type from
/// the first bytes.
List<int> _png(int size) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  return [...signature, ...List<int>.filled(size - signature.length, 0)];
}

/// [user] signed in again after a restart.
Future<User> signIn(PocketBase pb, User user) async {
  final record = await pb.superuser.view('users', user.id);
  final r = await pb.guest.send(
    'POST',
    '/api/collections/users/auth-with-password',
    body: {'identity': record.json['email'], 'password': 'password-123'},
  );
  r.expectStatus(200);
  return User(pb, user.id, r.json['token'] as String);
}
