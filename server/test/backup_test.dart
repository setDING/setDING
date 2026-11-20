// The server backup (tool/server/setding-backup.sh, ADR-0014) and its restore
// as docs/operations/server.md describes it, against a real PocketBase
// (issue #644). Needs sqlite3 and tar, as the server does.
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _script = File(
  '${Directory.current.parent.path}/tool/server/setding-backup.sh',
).absolute.path;

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Runs the backup script on [pbData], writing to [backupDir].
Future<ProcessResult> _backup(
  String pbData,
  String backupDir, {
  String keepDays = '14',
}) => Process.run(
  _script,
  [],
  environment: {
    'PB_DATA': pbData,
    'BACKUP_DIR': backupDir,
    'KEEP_DAYS': keepDays,
  },
);

List<String> _archives(Directory dir) =>
    dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith('setding-') && n.endsWith('.tar.gz'))
        .toList()
      ..sort();

void main() {
  late Directory backups;

  setUp(() async {
    backups = await Directory.systemTemp.createTemp('setding-backups-');
  });
  tearDown(() => backups.delete(recursive: true));

  test('a backup of the running server restores records, users and files '
      'as documented', () async {
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

    // Online backup while PocketBase runs (SQLite backup API).
    final run = await _backup(pb.dataDir, backups.path);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, contains('backup written: '));
    final archives = _archives(backups);
    expect(archives, hasLength(1));
    final archive = '${backups.path}/${archives.single}';
    final listing = await Process.run('tar', ['-tzf', archive]);
    expect(listing.stdout, contains('data.db'));
    expect(listing.stdout, contains('storage/'));

    // Changes after the backup must be gone after the restore.
    (await f.admin.patch('songs', songId, {
      'title': 'After backup',
      'revision': song['revision'],
    })).expectStatus(200);
    final later = await f.createSong(f.admin, title: 'Created later');

    // Restore as in docs/operations/server.md: stop, remove the WAL files,
    // unpack into pb_data, start.
    pb = await pb.restart(
      whileStopped: () async {
        for (final name in ['data.db-wal', 'data.db-shm']) {
          final file = File('${pb.dataDir}/$name');
          if (file.existsSync()) file.deleteSync();
        }
        final untar = await Process.run('tar', [
          '-xzf',
          archive,
          '-C',
          pb.dataDir,
        ]);
        expect(untar.exitCode, 0, reason: '${untar.stderr}');
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

  test('backups older than KEEP_DAYS are deleted, others are kept', () async {
    final pbData = await Directory.systemTemp.createTemp('setding-pbdata-');
    addTearDown(() => pbData.delete(recursive: true));
    final db = await Process.run('sqlite3', [
      '${pbData.path}/data.db',
      'CREATE TABLE t (x); INSERT INTO t VALUES (1);',
    ]);
    expect(db.exitCode, 0, reason: '${db.stderr}');

    final now = DateTime.now();
    File('${backups.path}/setding-20200101-033000.tar.gz')
      ..writeAsStringSync('old')
      ..setLastModifiedSync(now.subtract(const Duration(days: 20)));
    File('${backups.path}/setding-20200102-033000.tar.gz')
      ..writeAsStringSync('recent')
      ..setLastModifiedSync(now.subtract(const Duration(days: 5)));
    File('${backups.path}/manual-copy.tar.gz')
      ..writeAsStringSync('other')
      ..setLastModifiedSync(now.subtract(const Duration(days: 20)));

    final run = await _backup(pbData.path, backups.path, keepDays: '14');
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');

    final names = _archives(backups);
    expect(names, hasLength(2));
    expect(names, contains('setding-20200102-033000.tar.gz'));
    expect(names, isNot(contains('setding-20200101-033000.tar.gz')));
    expect(File('${backups.path}/manual-copy.tar.gz').existsSync(), isTrue);
    // No half-written archive is left behind.
    expect(backups.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test('without a database there is nothing to back up', () async {
    final pbData = await Directory.systemTemp.createTemp('setding-pbdata-');
    addTearDown(() => pbData.delete(recursive: true));
    final run = await _backup(pbData.path, backups.path);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, contains('nothing to back up'));
    expect(backups.listSync(), isEmpty);
  });
}
