// The Docker image of the server (ADR-0063 §2b, issue #1051), built from a
// bundle with tool/server-dist/build-image.sh and started with the example
// compose file of the self-hosting docs (docker.mdx; only the image and the
// host port replaced).
//
// With SETDING_TEST_IMAGE (and SETDING_TEST_BUNDLE, the bundle it was built
// from) it tests that release image instead (tool/server-dist/release-test.sh).
//
// Needs Docker with Compose. Without it the tests are skipped, unless
// SETDING_REQUIRE_DOCKER=1 (make check-full, make release-gate), where they
// fail instead.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';
import 'package:test/test.dart';

import 'support/dist.dart';
import 'support/fixtures.dart';

final _root = Directory.current.parent.path;

bool _dockerAvailable() {
  try {
    return Process.runSync('docker', ['compose', 'version']).exitCode == 0 &&
        Process.runSync('docker', ['info']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

final _required = Platform.environment['SETDING_REQUIRE_DOCKER'] == '1';
final Object _skip = _required || _dockerAvailable()
    ? false
    : 'Docker with Compose is not available (SETDING_REQUIRE_DOCKER=1 '
          'makes this fail)';

Future<ProcessResult> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    fail('$exe ${args.join(' ')} failed:\n${r.stdout}${r.stderr}');
  }
  return r;
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  late Directory work;
  late TestBundle bundle;
  late String image;
  var builtImage = false;
  String? project;
  String? composeFile;
  late Uri baseUrl;

  Future<ProcessResult> compose(List<String> args) =>
      _run('docker', ['compose', '-p', project!, '-f', composeFile!, ...args]);

  Future<String> containerId() async =>
      ((await compose(['ps', '-q', 'setding'])).stdout as String).trim();

  Future<String> health() async =>
      ((await _run('docker', [
                'inspect',
                '-f',
                '{{.State.Health.Status}}',
                await containerId(),
              ])).stdout
              as String)
          .trim();

  Future<void> waitHealthy() async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (await health() != 'healthy') {
      if (DateTime.now().isAfter(deadline)) {
        final logs = await compose(['logs', 'setding']);
        fail('the container did not become healthy:\n${logs.stdout}');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  setUpAll(() async {
    if (_skip != false) return;
    work = await Directory.systemTemp.createTemp('setding-image-');
    expect(_dockerAvailable(), isTrue, reason: 'Docker with Compose needed');
    bundle = await TestBundle.obtain(work, '9.8.7-imagetest');
    final id = DateTime.now().microsecondsSinceEpoch;
    project = 'setding-image-test-$id';
    image = Platform.environment['SETDING_TEST_IMAGE'] ?? '';
    if (image.isEmpty) {
      image = 'setding-server-test:$id';
      builtImage = true;
      final build = await Process.run(
        '$_root/tool/server-dist/build-image.sh',
        [],
        environment: {'BUNDLE': bundle.archive, 'IMAGE': image},
      );
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    }

    final port = await _freePort();
    baseUrl = Uri.parse('http://127.0.0.1:$port');
    final example = docExample('docker', 'docker-compose.yml');
    final imageLine = RegExp(r'image: \S+');
    final portLine = RegExp(r'"127\.0\.0\.1:8090:8090"');
    expect(example, contains(imageLine));
    expect(example, contains(portLine));
    composeFile = '${work.path}/docker-compose.yml';
    File(composeFile!).writeAsStringSync(
      example
          .replaceFirst(imageLine, 'image: $image')
          .replaceFirst(portLine, '"127.0.0.1:$port:8090"'),
    );
    await compose(['up', '-d']);
    await waitHealthy();
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
  });

  tearDownAll(() async {
    if (_skip != false) return;
    // Only what setUpAll got to start (it may have failed before).
    if (project != null && composeFile != null) {
      await Process.run('docker', [
        'compose',
        '-p',
        project!,
        '-f',
        composeFile!,
        'down',
        '-v',
      ]);
    }
    if (builtImage) await Process.run('docker', ['image', 'rm', '-f', image]);
    await work.delete(recursive: true);
  });

  test('runs as the non-root user with the version and the labels', () async {
    final config =
        jsonDecode(
              ((await _run('docker', [
                    'image',
                    'inspect',
                    '-f',
                    '{{json .Config}}',
                    image,
                  ])).stdout
                  as String),
            )
            as Map<String, dynamic>;
    expect(config['User'], '65532:65532');
    expect(
      (config['Labels'] as Map)['org.opencontainers.image.version'],
      bundle.version,
    );
    expect((config['Healthcheck'] as Map)['Test'], [
      'CMD',
      '/setding/pocketbase',
      'healthcheck',
    ]);
    expect((config['Volumes'] as Map).keys, contains('/setding/pb_data'));
  }, skip: _skip);

  test('serves the API, the version and the web client', () async {
    final pb = await PocketBase.remote(baseUrl);
    addTearDown(pb.stop);
    final config = await pb.guest.send('GET', '/api/setding/config');
    config.expectStatus(200);
    expect(config.json['serverVersion'], bundle.version);
    expect(config.json['registration'], 'invite_only');
    final page = await pb.guest.send('GET', '/');
    page.expectStatus(200);
    expect(page.raw.body, bundle.index);
    expect(await health(), 'healthy');
  }, skip: _skip);

  test('sign-up, a change and the delta sync work, and the data survives '
      'a restart', () async {
    var pb = await PocketBase.remote(baseUrl);
    addTearDown(() => pb.stop());
    final f = await BandFixture.create(pb);
    final song = await f.createSong(f.admin, title: 'From the image');
    final changes = await f.member.list(
      'songs',
      filter: 'organization = "${f.orgId}" && revision > 0',
    );
    expect(changes.map((s) => s['id']), contains(song['id']));

    await compose(['restart', 'setding']);
    await waitHealthy();
    pb = await PocketBase.remote(baseUrl);
    final kept = await pb.superuser.view('songs', song['id'] as String);
    kept.expectStatus(200);
    expect(kept.json['title'], 'From the image');
  }, skip: _skip);

  test('admin commands run in the container', () async {
    final invite = await compose([
      'exec',
      '-T',
      'setding',
      '/setding/pocketbase',
      'founder-invite',
      'Music',
      'school',
    ]);
    expect('${invite.stdout}${invite.stderr}', contains('"token"'));
    final check = await compose([
      'exec',
      '-T',
      'setding',
      '/setding/pocketbase',
      'healthcheck',
    ]);
    expect('${check.stdout}${check.stderr}', contains('healthy'));
  }, skip: _skip);

  test('a backup is written into the volume', () async {
    final pb = await PocketBase.remote(baseUrl);
    addTearDown(pb.stop);
    final backups = await pb.superuser.send('GET', '/api/settings');
    expect((backups.json['backups'] as Map)['cron'], '0 3 * * *');
    (await pb.superuser.send(
      'POST',
      '/api/backups',
      body: {'name': 'image_backup.zip'},
    )).expectStatus(204);
    final list = await pb.superuser.send('GET', '/api/backups');
    list.expectStatus(200);
    expect(
      (jsonDecode(list.raw.body) as List).map((b) => (b as Map)['key']),
      contains('image_backup.zip'),
    );
  }, skip: _skip);
}
