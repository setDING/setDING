// The platform services on a real Android system (make android-test): the
// SQLite file, the attachment files and the secure storage of the session
// keep their data when they are opened again, as after an app restart.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/bootstrap/platform_services.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/session_store.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('songs and attachment files survive closing and reopening', () async {
    var services = await openPlatformServices();
    var songs = SongRepository(services.db, services.storage);
    final pdf = pdfWith(3);
    final id = await songs.createSong(
      source: '{title: Persistent}\n[C]Still [G]here',
    );
    final attachment = await songs.addAttachment(
      id,
      name: 'sheet.pdf',
      bytes: pdf,
    );
    await services.db.close();

    services = await openPlatformServices();
    addTearDown(services.db.close);
    songs = SongRepository(services.db, services.storage);
    final song = await songs.getSong(id);
    expect(song, isNotNull);
    expect(song!.title, 'Persistent');
    expect(song.chordproSource, contains('[C]Still [G]here'));
    final attachments = await songs.getAttachments(id);
    final stored = attachments.singleWhere((a) => a.id == attachment);
    expect(await services.storage.file(stored.fileName).readAsBytes(), pdf);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the session is kept in the secure storage', () async {
    final store = SecureSessionStore();
    await store.write('{"server":"https://example.test","auth":"x"}');

    final reopened = SecureSessionStore();
    await reopened.load();
    expect(reopened.current, '{"server":"https://example.test","auth":"x"}');

    await reopened.delete();
    final empty = SecureSessionStore();
    await empty.load();
    expect(empty.current, isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
