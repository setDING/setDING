// Upgrading from the previous release (ADR-0063 §6, issue #1052): data
// written by the previous release's server is served by the new one after the
// documented update (the bundle directory replaced, the image tag changed).
//
// Runs only when tool/server-dist/release-test.sh (make release-gate, the
// release workflow) passes the artifacts:
//   SETDING_TEST_PREVIOUS_BUNDLE  the previous release's bundle
//   SETDING_TEST_BUNDLE           the new bundle (else one built now)
//   SETDING_TEST_PREVIOUS_IMAGE   the previous release's image (optional)
//   SETDING_TEST_IMAGE            the new image (with the previous image)
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/dist.dart';
import 'support/fixtures.dart';

final _env = Platform.environment;

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// What the previous release wrote, checked on the new one.
class _Seed {
  _Seed(this.songId, this.title, this.filePath, this.email, this.adminId);

  final String songId;
  final String title;
  final String filePath;
  final String email;
  final String adminId;

  static Future<_Seed> write(PocketBase pb) async {
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin, title: 'Written before');
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
    final user = await pb.superuser.view('users', f.admin.id);
    return _Seed(
      song['id'] as String,
      'Written before',
      '/api/files/attachments/${upload.json['id']}/${upload.json['file']}',
      user.json['email'] as String,
      f.admin.id,
    );
  }

  Future<void> check(PocketBase pb, String version) async {
    final config = await pb.guest.send('GET', '/api/setding/config');
    config.expectStatus(200);
    expect(config.json['serverVersion'], version);

    final song = await pb.superuser.view('songs', songId);
    song.expectStatus(200);
    expect(song.json['title'], title);

    final auth = await pb.guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': 'password-123'},
    );
    auth.expectStatus(200);
    final admin = User(pb, adminId, auth.json['token'] as String);
    final token = await admin.send('POST', '/api/files/token');
    token.expectStatus(200);
    final download = await admin.send(
      'GET',
      '$filePath?token=${token.json['token']}',
    );
    download.expectStatus(200);
    expect(download.raw.bodyBytes, _pdf);

    // The new server writes to the upgraded data.
    final changed = await admin.patch('songs', songId, {
      'title': 'Written after',
      'revision': song.json['revision'],
    });
    changed.expectStatus(200);
  }
}

void main() {
  final previousBundle = _env['SETDING_TEST_PREVIOUS_BUNDLE'] ?? '';

  test(
    'the new bundle takes over the data of the previous release',
    () async {
      final work = await Directory.systemTemp.createTemp('setding-upgrade-');
      addTearDown(() => work.delete(recursive: true));
      final next = await TestBundle.obtain(work, '9.8.7-upgradetest');

      Future<String> unpack(String archive) async {
        final r = await Process.run('tar', ['-xzf', archive, '-C', work.path]);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        final listing = await Process.run('tar', ['-tzf', archive]);
        final top = (listing.stdout as String).split('\n').first.split('/')[0];
        return '${work.path}/$top';
      }

      final previous = await unpack(previousBundle);
      final current = await unpack(next.archive);
      final previousVersion = File('$previous/VERSION')
          .readAsStringSync()
          .trim();
      expect(previousVersion, isNot(next.version));

      // The example unit's command, with /opt/setding/current a link to the
      // bundle in use and the data in its own directory.
      final unit = docExample(
        'native',
        'setding.service',
      ).replaceAll(RegExp(r'\\\n\s*'), ' ');
      final exec = unit
          .split('\n')
          .firstWhere((l) => l.startsWith('ExecStart='))
          .substring('ExecStart='.length)
          .trim()
          .split(RegExp(r'\s+'));
      final link = Link('${work.path}/current')..createSync(previous);
      String map(String a) => a
          .replaceAll('/opt/setding/current', link.path)
          .replaceAll('/var/lib/setding', '${work.path}/var');
      Future<PocketBase> start() async => PocketBase.startInstalled(
        binary: map(exec.first),
        flags: exec.skip(2).map(map).toList(),
        cleanup: await Directory.systemTemp.createTemp('setding-upgrade-run-'),
      );

      var pb = await start();
      final seed = await _Seed.write(pb);
      final config = await pb.guest.send('GET', '/api/setding/config');
      expect(config.json['serverVersion'], previousVersion);
      await pb.stop();

      // The documented update: point the link to the new bundle, restart.
      link.updateSync(current);
      pb = await start();
      addTearDown(pb.stop);
      await seed.check(pb, next.version);
    },
    skip: previousBundle.isEmpty
        ? 'needs SETDING_TEST_PREVIOUS_BUNDLE (tool/server-dist/release-test.sh)'
        : false,
  );

  final previousImage = _env['SETDING_TEST_PREVIOUS_IMAGE'] ?? '';
  final image = _env['SETDING_TEST_IMAGE'] ?? '';

  test(
    'the new image takes over the volume of the previous release',
    () async {
      final work = await Directory.systemTemp.createTemp('setding-upgrade-');
      addTearDown(() => work.delete(recursive: true));
      final next = await TestBundle.obtain(work, '9.8.7-upgradetest');
      final project =
          'setding-upgrade-test-${DateTime.now().microsecondsSinceEpoch}';
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final example = docExample('docker', 'docker-compose.yml');
      final composeFile = '${work.path}/docker-compose.yml';
      void write(String img) => File(composeFile).writeAsStringSync(
        example
            .replaceFirst(RegExp(r'image: \S+'), 'image: $img')
            .replaceFirst('"127.0.0.1:8090:8090"', '"127.0.0.1:$port:8090"'),
      );
      Future<ProcessResult> compose(List<String> args) async {
        final r = await Process.run('docker', [
          'compose',
          '-p',
          project,
          '-f',
          composeFile,
          ...args,
        ]);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
        return r;
      }

      addTearDown(
        () => Process.run('docker', [
          'compose',
          '-p',
          project,
          '-f',
          composeFile,
          'down',
          '-v',
        ]),
      );
      final baseUrl = Uri.parse('http://127.0.0.1:$port');
      Future<void> waitUp() async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (true) {
          try {
            final r = await HttpClient()
                .getUrl(baseUrl.resolve('/api/health'))
                .then((q) => q.close());
            if (r.statusCode == 200) return;
          } on SocketException {
            // not up yet
          } on HttpException {
            // not up yet
          }
          if (DateTime.now().isAfter(deadline)) {
            fail('the server did not start');
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      write(previousImage);
      await compose(['up', '-d']);
      await waitUp();
      await compose([
        'exec',
        '-T',
        'setding',
        '/setding/pocketbase',
        'superuser',
        'upsert',
        PocketBase.superuserEmail,
        PocketBase.superuserPassword,
      ]);
      var pb = await PocketBase.remote(baseUrl);
      final seed = await _Seed.write(pb);
      await pb.stop();

      // The documented update: change the image, recreate the container.
      write(image);
      await compose(['up', '-d']);
      await waitUp();
      pb = await PocketBase.remote(baseUrl);
      addTearDown(pb.stop);
      await seed.check(pb, next.version);
    },
    skip: previousImage.isEmpty || image.isEmpty
        ? 'needs SETDING_TEST_PREVIOUS_IMAGE and SETDING_TEST_IMAGE '
              '(tool/server-dist/release-test.sh)'
        : false,
  );
}
