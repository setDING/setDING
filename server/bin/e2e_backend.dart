// Backend of the end-to-end tests (make e2e, issue #692,
// docs/development/e2e-tests.md): a local PocketBase with the repository's
// schema and hooks, the people and songs of the tests, and one proxy per
// client with the coordination endpoints (lib/e2e_coordinator.dart).
//
//   dart run bin/e2e_backend.dart [--public-dir <dir>] [--clients a,b]
//
// The fixture: Anna administers the organization and leads its band "E2E
// Band"; Ben is a member of the organization and plans the band's sets
// (ADR-0023). The library has a song and a song with a two-page PDF only.
//
// --public-dir serves a web build from PocketBase like in production
// (ADR-0018). Prints one JSON line
//   {"port": <PocketBase>, "clients": {"a": <proxy port>, ...},
//    "accounts": {"anna": {"email", "password"}, "ben": {...}},
//    "song": ..., "sheet": ...}
// and runs until it gets SIGTERM or SIGINT; then it stops the proxies and
// PocketBase and removes its data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:setding_server/e2e_coordinator.dart';
import 'package:setding_server/pocketbase_harness.dart';

const _password = 'e2e-password-123';
const _song = 'Fixture Song';
const _sheet = 'Fixture Sheet';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final publicDir = option('--public-dir');
  final clients = (option('--clients') ?? 'a,b').split(',');
  final pb = await PocketBase.start(
    publicDir: publicDir == null ? null : Directory(publicDir).absolute.path,
  );
  final coordinator = E2eCoordinator(pb.baseUrl);
  try {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final anna = await _person(pb, 'anna-$stamp@setding.test', 'Anna');
    final ben = await _person(pb, 'ben-$stamp@setding.test', 'Ben');

    // Open registration: the band gets a new organization with Anna as its
    // admin and band leader (ADR-0017, ADR-0024).
    final band = await anna.user.post('bands', {'name': 'E2E Band'});
    band.expectStatus(200);
    final bandId = band.json['id'] as String;
    final organization = band.json['organization'] as String;
    (await pb.superuser.post('org_memberships', {
      'user': ben.user.id,
      'organization': organization,
      'role': 'member',
    })).expectStatus(200);
    (await pb.superuser.post('memberships', {
      'user': ben.user.id,
      'band': bandId,
      'role': 'planner',
    })).expectStatus(200);

    (await anna.user.post('songs', {
      'id': _uuid(),
      'organization': organization,
      'title': _song,
      'chordpro': '{title: $_song}\n[C]From the [G]fixture',
    })).expectStatus(200);
    final sheet = await anna.user.post('songs', {
      'id': _uuid(),
      'organization': organization,
      'title': _sheet,
      'chordpro': '{title: $_sheet}',
    });
    sheet.expectStatus(200);
    final pdf = _pdfWith(2);
    (await anna.user.postMultipart(
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

    final ports = <String, int>{};
    for (final client in clients) {
      ports[client] = (await coordinator.addClient(client)).url.port;
    }

    stdout.writeln(
      jsonEncode({
        'port': pb.baseUrl.port,
        'clients': ports,
        'accounts': {
          for (final p in [anna, ben])
            p.key: {'email': p.email, 'password': _password},
        },
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
    await coordinator.close();
    await pb.stop();
  }
  exit(0);
}

/// A verified person with a password, signed in.
Future<({String key, String email, User user})> _person(
  PocketBase pb,
  String email,
  String name,
) async {
  (await pb.superuser.post('users', {
    'email': email,
    'password': _password,
    'passwordConfirm': _password,
    'name': name,
    'verified': true,
  })).expectStatus(200);
  final auth = await pb.guest.send(
    'POST',
    '/api/collections/users/auth-with-password',
    body: {'identity': email, 'password': _password},
  );
  auth.expectStatus(200);
  return (
    key: name.toLowerCase(),
    email: email,
    user: User(
      pb,
      auth.field('record.id')! as String,
      auth.json['token'] as String,
    ),
  );
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
