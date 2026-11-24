import 'dart:io';

import 'package:test/test.dart';

/// The server bundle a test runs (ADR-0063): the release artifact named by
/// `SETDING_TEST_BUNDLE`, or one built now with
/// tool/server-dist/build-bundle.sh, a stub web client and [version].
class TestBundle {
  TestBundle._(this.archive, this.version, this.index, {required this.built});

  /// The `.tar.gz`.
  final String archive;

  /// Its `VERSION`.
  final String version;

  /// Its web client's `index.html`.
  final String index;

  /// Built by the test (with `SHA256SUMS` next to it), not given.
  final bool built;

  /// The directory name inside the archive.
  String get name => 'setding-server-$version';

  static final _root = Directory.current.parent.path;

  static Future<TestBundle> obtain(Directory work, String version) async {
    var archive = Platform.environment['SETDING_TEST_BUNDLE'] ?? '';
    final built = archive.isEmpty;
    if (built) {
      final web = Directory('${work.path}/web')..createSync(recursive: true);
      // Private like a fresh temporary directory: the bundle must still be
      // readable for every user.
      await Process.run('chmod', ['700', web.path]);
      File('${web.path}/index.html').writeAsStringSync(
        '<!doctype html><html><head><base href="/"></head>'
        '<body><!-- setding web client ($version) --></body></html>',
      );
      final build = await Process.run(
        '$_root/tool/server-dist/build-bundle.sh',
        [],
        environment: {
          'OUT': '${work.path}/dist',
          'WEB_DIR': web.path,
          'SERVER_VERSION': version,
        },
      );
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      archive = (build.stdout as String).trim().split('\n').last;
    }
    Future<String> read(String path) async {
      final r = await Process.run('tar', [
        '-xzOf',
        archive,
        '--wildcards',
        '*/$path',
      ]);
      expect(r.exitCode, 0, reason: '$path in $archive: ${r.stderr}');
      return r.stdout as String;
    }

    return TestBundle._(
      archive,
      (await read('VERSION')).trim(),
      await read('pb_public/index.html'),
      built: built,
    );
  }
}
