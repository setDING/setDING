// Local PocketBase for the Android integration tests (tool/android-test.sh,
// docs/development/android-tests.md): the repository's schema and hooks, with
// a user in a band of an organization and one song in its library.
//
// Prints one JSON line {port, email, password, song} and runs until it gets
// SIGTERM or SIGINT; then it stops PocketBase and removes its data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:setding_server/pocketbase_harness.dart';

const _password = 'itest-password-123';
const _song = 'Synced From Server';

Future<void> main() async {
  final pb = await PocketBase.start();
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
    (await user.post('songs', {
      'organization': band.json['organization'],
      'title': _song,
      'chordpro': '{title: $_song}\n[C]From the [G]server',
    })).expectStatus(200);

    stdout.writeln(
      jsonEncode({
        'port': pb.baseUrl.port,
        'email': email,
        'password': _password,
        'song': _song,
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
