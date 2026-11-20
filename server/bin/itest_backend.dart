// Local PocketBase for the integration tests on Android and in the browser
// (tool/android-test.sh, tool/web-test.sh, docs/development/android-tests.md,
// docs/development/web-tests.md): the repository's schema and hooks, with a
// user in a band of an organization and two songs in its library, one of
// them with a two-page PDF attachment.
//
//   dart run bin/itest_backend.dart [--public-dir <dir>]
//
// --public-dir serves a web build from PocketBase like in production
// (ADR-0018). Prints one JSON line {port, email, password, song, sheet} and
// runs until it gets SIGTERM or SIGINT; then it stops PocketBase and removes
// its data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:setding_server/pocketbase_harness.dart';

const _password = 'itest-password-123';
const _song = 'Synced From Server';
const _sheet = 'Sheet From Server';

Future<void> main(List<String> args) async {
  final dirIndex = args.indexOf('--public-dir');
  final publicDir = dirIndex >= 0 && dirIndex + 1 < args.length
      ? Directory(args[dirIndex + 1]).absolute.path
      : null;
  final pb = await PocketBase.start(publicDir: publicDir);
  try {
    final email = 'itest-${DateTime.now().millisecondsSinceEpoch}@setding.test';
    (await pb.superuser.post('users', {
      'email': email,
      'password': _password,
      'passwordConfirm': _password,
      'name': 'Integration Test',
      'verified': true,
    })).expectStatus(200);
    final auth = await pb.guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': _password},
    );
    auth.expectStatus(200);
    final user = User(
      pb,
      auth.field('record.id')! as String,
      auth.json['token'] as String,
    );
    // Open registration: the band gets a new organization with the user as
    // its admin (ADR-0017, ADR-0024).
    final band = await user.post('bands', {'name': 'Integration Band'});
    band.expectStatus(200);
    final organization = band.json['organization'] as String;
    (await user.post('songs', {
      'organization': organization,
      'title': _song,
      'chordpro': '{title: $_song}\n[C]From the [G]server',
    })).expectStatus(200);
    final sheet = await user.post('songs', {
      'organization': organization,
      'title': _sheet,
      'chordpro': '{title: $_sheet}',
    });
    sheet.expectStatus(200);
    final pdf = _pdfWith(2);
    (await user.postMultipart(
      'attachments',
      {
        'id': _uuid(),
        'organization': organization,
        'song': sheet.json['id'] as String,
        'name': 'Score',
        'pages': '2',
        'size_bytes': '${pdf.length}',
      },
      fileField: 'file',
      bytes: pdf,
      filename: 'score.pdf',
      contentType: 'application/pdf',
    )).expectStatus(200);

    stdout.writeln(
      jsonEncode({
        'port': pb.baseUrl.port,
        'email': email,
        'password': _password,
        'song': _song,
        'sheet': _sheet,
      }),
    );
    await stdout.flush();
    final stop = Completer<void>();
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
      signal.watch().listen((_) {
        if (!stop.isCompleted) stop.complete();
      });
    }
    await stop.future;
  } finally {
    await pb.stop();
  }
  exit(0);
}

/// A random version 4 UUID, as the app generates record IDs (ADR-0004).
String _uuid() {
  final random = Random.secure();
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// A PDF with [pages] empty pages (300 x 400 pt).
List<int> _pdfWith(int pages) {
  final kids = [for (var i = 0; i < pages; i++) '${i + 3} 0 R'].join(' ');
  final objects = [
    for (var i = 0; i < pages; i++)
      '${i + 3} 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj',
  ].join('\n');
  return utf8.encode('''%PDF-1.1
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[$kids]/Count $pages>>endobj
$objects
trailer<</Root 1 0 R>>
%%EOF
''');
}
