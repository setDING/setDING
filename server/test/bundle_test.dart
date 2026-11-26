// The server bundle (ADR-0063 §1, issue #1050), built with
// tool/server-dist/build-bundle.sh and started the two documented ways: as it
// is (`./pocketbase serve`) and with the example systemd unit's command
// (native.mdx of the self-hosting docs). With SETDING_TEST_BUNDLE it tests that
// release artifact instead (tool/server-dist/release-test.sh).
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/dist.dart';
import 'support/fixtures.dart';

final _root = Directory.current.parent.path;

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// The `ExecStart` of [unit] split into arguments (continuation lines
/// joined).
List<String> _execStart(String unit) {
  final joined = unit.replaceAll(RegExp(r'\\\n\s*'), ' ');
  final line = joined.split('\n').firstWhere((l) => l.startsWith('ExecStart='));
  return line.substring('ExecStart='.length).trim().split(RegExp(r'\s+'));
}

late TestBundle _bundle;

/// Unpacks the bundle into a new temporary directory and returns it with the
/// bundle directory inside.
Future<(Directory, String)> _unpack() async {
  final dir = await Directory.systemTemp.createTemp('setding-bundle-run-');
  final r = await Process.run('tar', ['-xzf', _bundle.archive, '-C', dir.path]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return (dir, '${dir.path}/${_bundle.name}');
}

void main() {
  late Directory out;

  setUpAll(() async {
    out = await Directory.systemTemp.createTemp('setding-bundle-');
    _bundle = await TestBundle.obtain(out, '9.8.7-bundletest');
  });
  tearDownAll(() => out.delete(recursive: true));

  test('contains the server, the web client, the version and the licences, '
      'with a matching checksum', () async {
    expect(
      _bundle.archive,
      matches(
        RegExp(
          '/${RegExp.escape(_bundle.name)}-linux-(amd64|arm64)\\.tar\\.gz\$',
        ),
      ),
    );
    if (_bundle.built) {
      final check = await Process.run('sha256sum', [
        '-c',
        'SHA256SUMS',
      ], workingDirectory: File(_bundle.archive).parent.path);
      expect(check.exitCode, 0, reason: '${check.stdout}${check.stderr}');
    }

    final (dir, bundle) = await _unpack();
    addTearDown(() => dir.delete(recursive: true));
    expect(File('$bundle/VERSION').readAsStringSync().trim(), _bundle.version);
    expect(
      File('$bundle/pb_hooks/setding-version.txt').readAsStringSync().trim(),
      _bundle.version,
    );
    for (final hook in Directory(
      '$_root/server/pb_hooks',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.pb.js'))) {
      final name = hook.uri.pathSegments.last;
      expect(
        File('$bundle/pb_hooks/$name').readAsStringSync(),
        hook.readAsStringSync(),
        reason: name,
      );
    }
    expect(
      Directory('$bundle/pb_migrations').listSync().length,
      Directory(
        '$_root/server/pb_migrations',
      ).listSync().where((e) => e.path.endsWith('.js')).length,
    );
    expect(
      File('$bundle/pb_public/index.html').readAsStringSync(),
      contains('<base href="/">'),
    );
    expect(File('$bundle/LICENSES/setDING.txt').existsSync(), isTrue);
    expect(
      File('$bundle/LICENSES/PocketBase.md').readAsStringSync(),
      contains('MIT'),
    );
    final mode = (await Process.run('stat', [
      '-c',
      '%a',
      '$bundle/pocketbase',
    ])).stdout.toString().trim();
    expect(mode, '755');

    // Readable for the server's user, also from sources that were not (a web
    // build in a private directory made the image answer 404).
    final private = await Process.run('find', [
      bundle,
      '(',
      '-type',
      'd',
      '!',
      '-perm',
      '-0555',
      ')',
      '-o',
      '(',
      '-type',
      'f',
      '!',
      '-perm',
      '-0444',
      ')',
      '-o',
      '-perm',
      '/0022',
    ]);
    expect((private.stdout as String).trim(), isEmpty);
  });

  test('runs as it is, with everything next to the binary', () async {
    final (dir, bundle) = await _unpack();
    final pb = await PocketBase.startInstalled(
      binary: '$bundle/pocketbase',
      flags: const [],
      cleanup: dir,
    );
    addTearDown(pb.stop);

    final config = await pb.guest.send('GET', '/api/setding/config');
    config.expectStatus(200);
    expect(config.json['serverVersion'], _bundle.version);
    final page = await pb.guest.send('GET', '/');
    page.expectStatus(200);
    expect(page.raw.body, _bundle.index);
    expect(File('$bundle/pb_data/data.db').existsSync(), isTrue);
  });

  test('the build prints an absolute path also for a relative OUT '
      '(issue #1064)', () async {
    // The release workflow passes OUT=dist-server, the tests run in server/.
    final cwd = await Directory.systemTemp.createTemp('setding-bundle-cwd-');
    addTearDown(() => cwd.delete(recursive: true));
    final web = Directory('${cwd.path}/web')..createSync();
    File('${web.path}/index.html').writeAsStringSync('<html></html>');
    final build = await Process.run(
      '$_root/tool/server-dist/build-bundle.sh',
      [],
      workingDirectory: cwd.path,
      environment: {
        'OUT': 'relative/out',
        'WEB_DIR': web.path,
        'SERVER_VERSION': '9.8.7-relative',
      },
    );
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final printed = (build.stdout as String).trim().split('\n').last;
    expect(printed, startsWith('/'));
    expect(
      printed,
      startsWith('${cwd.resolveSymbolicLinksSync()}/relative/out/'),
    );
    expect(File(printed).existsSync(), isTrue);
  });

  group('with the example systemd unit', () {
    late List<String> exec;

    setUpAll(() {
      exec = _execStart(docExample('native', 'setding.service'));
    });

    /// The unit's command with its paths moved into [dir].
    Future<PocketBase> start(
      Directory dir,
      String bundle, {
      Map<String, String>? environment,
    }) {
      final current = Link('${dir.path}/current')..createSync(bundle);
      String map(String a) => a
          .replaceAll('/opt/setding/current', current.path)
          .replaceAll('/var/lib/setding', '${dir.path}/var');
      return PocketBase.startInstalled(
        binary: map(exec.first),
        flags: exec.skip(2).map(map).toList(),
        cleanup: dir,
        environment: environment,
      );
    }

    test('the unit starts the bundle with serve and keeps the data apart', () {
      expect(exec.first, '/opt/setding/current/pocketbase');
      expect(exec[1], 'serve');
      expect(exec, contains('--dir=/var/lib/setding/pb_data'));
      expect(exec, contains('--http=127.0.0.1:8090'));
    });

    test('serves the API, the version and the web client', () async {
      final (dir, bundle) = await _unpack();
      final pb = await start(
        dir,
        bundle,
        environment: {'SETDING_WEB_URL': 'https://web.test'},
      );
      addTearDown(pb.stop);
      expect(File('${dir.path}/var/pb_data/data.db').existsSync(), isTrue);
      expect(Directory('$bundle/pb_data').existsSync(), isFalse);

      final config = await pb.guest.send('GET', '/api/setding/config');
      config.expectStatus(200);
      expect(config.json['serverVersion'], _bundle.version);
      final page = await pb.guest.send('GET', '/');
      page.expectStatus(200);
      expect(page.raw.body, _bundle.index);

      // The landing page finds the bundled web client without
      // SETDING_PUBLIC_DIR.
      final f = await BandFixture.create(pb);
      final invite = await f.admin.send(
        'POST',
        '/api/setding/invites',
        body: {'organization': f.orgId},
      );
      invite.expectStatus(200);
      final landing = await pb.guest.send(
        'GET',
        '/invite/${invite.json['token']}',
      );
      landing.expectStatus(200);
      expect(landing.raw.body, contains('Open in the browser'));
    });

    test('sign-up, a change and the delta sync work', () async {
      final (dir, bundle) = await _unpack();
      final pb = await start(dir, bundle);
      addTearDown(pb.stop);
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin, title: 'From the bundle');
      final changes = await f.member.list(
        'songs',
        filter: 'organization = "${f.orgId}" && revision > 0',
      );
      expect(changes.map((s) => s['id']), contains(song['id']));
    });

    test(
      'founder-invite and the health check run on the installed data',
      () async {
        final (dir, bundle) = await _unpack();
        final pb = await start(dir, bundle);
        addTearDown(pb.stop);
        final invite = await pb.command(['founder-invite', 'Music', 'school']);
        expect(invite.exitCode, 0, reason: '${invite.stderr}');
        expect('${invite.stdout}${invite.stderr}', contains('"token"'));
        final health = await pb.command(['healthcheck', '${pb.baseUrl}']);
        expect(health.exitCode, 0, reason: '${health.stdout}${health.stderr}');
      },
    );

    test('a backup restores the data', () async {
      final (dir, bundle) = await _unpack();
      var pb = await start(dir, bundle);
      addTearDown(() => pb.stop());
      final f = await BandFixture.create(pb);
      final song = await f.createSong(f.admin, title: 'Before backup');
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
      (await pb.superuser.send(
        'POST',
        '/api/backups',
        body: {'name': 'bundle_backup.zip'},
      )).expectStatus(204);
      final backup = File('${pb.dataDir}/backups/bundle_backup.zip');
      expect(backup.existsSync(), isTrue);
      final later = await f.createSong(f.admin, title: 'Created later');

      pb = await pb.restart(
        whileStopped: () async {
          for (final entry in Directory(pb.dataDir).listSync()) {
            if (entry.path.endsWith('/backups')) continue;
            entry.deleteSync(recursive: true);
          }
          final unzip = await Process.run('unzip', [
            '-q',
            backup.path,
            '-d',
            pb.dataDir,
          ]);
          expect(unzip.exitCode, 0, reason: '${unzip.stderr}');
        },
      );
      expect(
        (await pb.superuser.view('songs', song['id'] as String)).status,
        200,
      );
      expect(
        (await pb.superuser.view('songs', later['id'] as String)).status,
        404,
      );
      expect(
        (await pb.superuser.view(
          'attachments',
          upload.json['id'] as String,
        )).status,
        200,
      );
    });
  });
}
