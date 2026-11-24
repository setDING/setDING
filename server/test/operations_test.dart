// Running the server without an installer (ADR-0063, issue #1049): the
// required configuration, the automatic backups with their restore and the
// `healthcheck` console command, against a real PocketBase.
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

Future<Map<String, dynamic>> _backupSettings(PocketBase pb) async {
  final r = await pb.superuser.send('GET', '/api/settings');
  r.expectStatus(200);
  return r.json['backups'] as Map<String, dynamic>;
}

/// Starting must fail, with [message] in the server's output.
Future<void> _expectRefused(
  Map<String, String> environment,
  String message,
) async {
  await expectLater(
    PocketBase.start(environment: environment),
    throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(message)),
    ),
  );
}

void main() {
  group('required configuration', () {
    test('the server does not start without SETDING_INVITE_KEY', () async {
      await _expectRefused({
        'SETDING_INVITE_KEY': '',
      }, 'missing environment variable(s) SETDING_INVITE_KEY');
      await _expectRefused({
        'SETDING_INVITE_KEY': '   ',
      }, 'missing environment variable(s) SETDING_INVITE_KEY');
    });

    test('console commands work without it', () async {
      final pb = await PocketBase.start();
      addTearDown(pb.stop);
      final env = {'SETDING_INVITE_KEY': ''};
      final health = await pb.command([
        'healthcheck',
        '${pb.baseUrl}',
      ], environment: env);
      expect(health.exitCode, 0, reason: '${health.stdout}${health.stderr}');
      final invite = await pb.command([
        'founder-invite',
        'Music school',
      ], environment: env);
      expect(invite.exitCode, 0, reason: '${invite.stderr}');
    });
  });

  group('healthcheck command', () {
    test('exits with 0 while the server answers', () async {
      final pb = await PocketBase.start();
      addTearDown(pb.stop);
      final r = await pb.command(['healthcheck', '${pb.baseUrl}']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('healthy: ${pb.baseUrl}'));
    });

    test('exits with 1 when nothing answers', () async {
      final pb = await PocketBase.start();
      addTearDown(pb.stop);
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closed = socket.port;
      await socket.close();
      final r = await pb.command(['healthcheck', 'http://127.0.0.1:$closed']);
      expect(r.exitCode, 1);
      expect('${r.stdout}${r.stderr}', contains('unhealthy'));
    });

    test('uses SETDING_HEALTH_URL without an argument', () async {
      final pb = await PocketBase.start();
      addTearDown(pb.stop);
      final r = await pb.command(
        ['healthcheck'],
        environment: {'SETDING_HEALTH_URL': '${pb.baseUrl}/'},
      );
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });

  group('automatic backups', () {
    test('are on by default: daily at 03:00, 14 kept', () async {
      final pb = await PocketBase.start();
      addTearDown(pb.stop);
      final backups = await _backupSettings(pb);
      expect(backups['cron'], '0 3 * * *');
      expect(backups['cronMaxKeep'], 14);
    });

    test('follow SETDING_BACKUP_CRON and SETDING_BACKUP_KEEP, also over '
        'changes in the admin UI', () async {
      var pb = await PocketBase.start(
        environment: {
          'SETDING_BACKUP_CRON': '30 2 * * 1',
          'SETDING_BACKUP_KEEP': '3',
        },
      );
      addTearDown(() => pb.stop());
      var backups = await _backupSettings(pb);
      expect(backups['cron'], '30 2 * * 1');
      expect(backups['cronMaxKeep'], 3);

      (await pb.superuser.send(
        'PATCH',
        '/api/settings',
        body: {
          'backups': {'cron': '0 0 * * *', 'cronMaxKeep': 99},
        },
      )).expectStatus(200);
      pb = await pb.restart();
      backups = await _backupSettings(pb);
      expect(backups['cron'], '30 2 * * 1');
      expect(backups['cronMaxKeep'], 3);
    });

    test('are off with SETDING_BACKUP_CRON=off', () async {
      final pb = await PocketBase.start(
        environment: {'SETDING_BACKUP_CRON': 'off'},
      );
      addTearDown(pb.stop);
      expect((await _backupSettings(pb))['cron'], '');
    });

    test('invalid settings stop the start with a message', () async {
      await _expectRefused({
        'SETDING_BACKUP_CRON': 'every night',
      }, 'SETDING_BACKUP_CRON "every night" is not a valid cron expression');
      await _expectRefused({
        'SETDING_BACKUP_KEEP': '0',
      }, 'SETDING_BACKUP_KEEP must be a whole number of at least 1');
      await _expectRefused({
        'SETDING_BACKUP_KEEP': 'many',
      }, 'SETDING_BACKUP_KEEP must be a whole number of at least 1');
    });

    test('a backup restores records, users and files', () async {
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
      final filePath =
          '/api/files/attachments/${upload.json['id']}/${upload.json['file']}';

      // The backup function the cron job runs, while the server runs.
      (await pb.superuser.send(
        'POST',
        '/api/backups',
        body: {'name': 'test_backup.zip'},
      )).expectStatus(204);
      final archive = File('${pb.dataDir}/backups/test_backup.zip');
      expect(archive.existsSync(), isTrue);

      // Changes after the backup must be gone after the restore.
      (await f.admin.patch('songs', songId, {
        'title': 'After backup',
        'revision': song['revision'],
      })).expectStatus(200);
      final later = await f.createSong(f.admin, title: 'Created later');

      // Restore as the self-hosting docs describe it: stop, empty pb_data
      // except the backups, unpack the archive into it, start.
      pb = await pb.restart(
        whileStopped: () async {
          for (final entry in Directory(pb.dataDir).listSync()) {
            if (entry.uri.pathSegments.where((s) => s.isNotEmpty).last ==
                'backups') {
              continue;
            }
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

      final user = await pb.superuser.view('users', f.admin.id);
      user.expectStatus(200);
      final auth = await pb.guest.send(
        'POST',
        '/api/collections/users/auth-with-password',
        body: {'identity': user.json['email'], 'password': 'password-123'},
      );
      auth.expectStatus(200);

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
  });
}
