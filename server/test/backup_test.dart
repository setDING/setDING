// The backup of a running server on the owner's hosts
// (tool/server/backup-now.sh, installed as setding-backup-now; ADR-0014,
// ADR-0063) and its restore as docs/operations/server.md and the
// self-hosting docs describe it, against a real PocketBase (issue #644,
// #1055). Needs sqlite3, zip and unzip, as the servers have.
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _script = File(
  '${Directory.current.parent.path}/tool/server/backup-now.sh',
).absolute.path;

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Runs the backup script on [pbData].
Future<ProcessResult> _backup(String pbData, [String? name]) => Process.run(
  _script,
  [?name],
  environment: {'PB_DATA': pbData, 'OWNER': 'nobody-setding-test'},
);

void main() {
  test('a backup of the running server restores records, users and files '
      'as documented, and PocketBase lists it', () async {
    var pb = await PocketBase.start();
    addTearDown(() => pb.stop());
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin, title: 'Before backup');
    final songId = song['id'] as String;
    final upload = await f.admin.postMultipart(
      'attachments',
      {
        'id': uuid(),
        'organization': f.orgId,
        'song': songId,
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
    final filePath =
        '/api/files/attachments/$attachmentId/${upload.json['file']}';

    // Online backup while PocketBase runs (SQLite backup API), named like
    // the one before an update.
    final run = await _backup(pb.dataDir, 'pre-update-0.21.0');
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    final archive = File('${pb.dataDir}/backups/pre-update-0_21_0.zip');
    expect(archive.existsSync(), isTrue, reason: '${run.stdout}');
    final listing = await Process.run('unzip', ['-Z1', archive.path]);
    expect(listing.stdout, contains('data.db'));
    expect(listing.stdout, contains('storage/'));
    // No half-written archive is left behind.
    expect(
      Directory(
        '${pb.dataDir}/backups',
      ).listSync().where((e) => e.path.endsWith('.part')),
      isEmpty,
    );

    // PocketBase lists it like its own backups (admin UI, restore there).
    final listed = await pb.superuser.send('GET', '/api/backups');
    listed.expectStatus(200);
    expect(
      (jsonDecode(listed.raw.body) as List).map((b) => (b as Map)['key']),
      contains('pre-update-0_21_0.zip'),
    );

    // Changes after the backup must be gone after the restore.
    (await f.admin.patch('songs', songId, {
      'title': 'After backup',
      'revision': song['revision'],
    })).expectStatus(200);
    final later = await f.createSong(f.admin, title: 'Created later');

    // Restore as documented: stop, empty pb_data except backups/, unzip.
    pb = await pb.restart(
      whileStopped: () async {
        for (final entry in Directory(pb.dataDir).listSync()) {
          if (entry.path.endsWith('/backups')) continue;
          entry.deleteSync(recursive: true);
        }
        final unzip = await Process.run('unzip', [
          '-q',
          archive.path,
          '-d',
          pb.dataDir,
        ]);
        expect(unzip.exitCode, 0, reason: '${unzip.stderr}');
      },
    );

    final restored = await pb.superuser.view('songs', songId);
    restored.expectStatus(200);
    expect(restored.json['title'], 'Before backup');
    expect(
      (await pb.superuser.view('songs', later['id'] as String)).status,
      404,
    );

    // Users and their passwords are back: the admin signs in again.
    final user = await pb.superuser.view('users', f.admin.id);
    user.expectStatus(200);
    final auth = await pb.guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': user.json['email'], 'password': 'password-123'},
    );
    auth.expectStatus(200);

    // The attachment file is back, byte for byte.
    final admin = User(pb, f.admin.id, auth.json['token'] as String);
    final token = await admin.send('POST', '/api/files/token');
    token.expectStatus(200);
    final download = await admin.send(
      'GET',
      '$filePath?token=${token.json['token']}',
    );
    download.expectStatus(200);
    expect(download.raw.bodyBytes, _pdf);
  });

  test('a backup without a name is a dated manual backup', () async {
    final pbData = await Directory.systemTemp.createTemp('setding-pbdata-');
    addTearDown(() => pbData.delete(recursive: true));
    final db = await Process.run('sqlite3', [
      '${pbData.path}/data.db',
      'CREATE TABLE t (x); INSERT INTO t VALUES (1);',
    ]);
    expect(db.exitCode, 0, reason: '${db.stderr}');

    final run = await _backup(pbData.path);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    final names = Directory(
      '${pbData.path}/backups',
    ).listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(names, hasLength(1));
    expect(names.single, matches(RegExp(r'^manual-\d{8}-\d{6}\.zip$')));
  });

  test('without a database there is nothing to back up', () async {
    final pbData = await Directory.systemTemp.createTemp('setding-pbdata-');
    addTearDown(() => pbData.delete(recursive: true));
    final run = await _backup(pbData.path);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, contains('nothing to back up'));
    expect(Directory('${pbData.path}/backups').existsSync(), isFalse);
  });
}
