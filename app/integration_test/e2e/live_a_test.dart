// End-to-end story "live", client a: Anna, organization admin and band
// leader, on the Linux desktop (make e2e, issue #692,
// docs/development/e2e-tests.md). Her counterpart is live_b_test.dart: Ben,
// set planner, playing the gig in the web client.
//
// While Ben is on stage, Anna reorders the gig, edits a song of it and
// deletes the song Ben is playing. None of it reaches his stage (ADR-0007);
// all of it does once he leaves live mode.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/data/set_providers.dart';
import 'package:setding/data/song_providers.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'e2e_support.dart';
import 'live_texts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('live: Anna on the Linux desktop', (tester) async {
    await e2eSettings(server: e2eServer);
    await app.main();
    await pumpUntil(tester, find.byType(HomeScreen));
    await signInOnDesktop(tester, annaEmail);
    await waitForFixture(tester);

    final container = containerOf(tester);
    final db = databaseOf(tester);
    final band = await selectFixtureBand(tester);
    final songs = container.read(
      librarySongRepositoryProvider(band.organizationId!),
    );
    final sets = container.read(setRepositoryProvider);

    await signal(tester, 'a-ready');
    await barrier(tester, 'b-ready');

    // 1. A gig today with three songs.
    final ids = (await tester.runAsync(() async {
      return {
        for (final title in liveSongs)
          title: await songs.createSong(source: liveSource(title)),
      };
    }))!;
    final now = DateTime.now();
    final setId = (await tester.runAsync(() async {
      final id = await sets.createSet(
        name: liveGig,
        gigDate: DateTime(now.year, now.month, now.day),
      );
      await sets.addSongs(id, [for (final title in liveSongs) ids[title]!]);
      return id;
    }))!;
    await waitUntilPushed(tester, db, [...ids.values, setId]);
    await signal(tester, 'gig-planned');

    // 2. Ben is on stage, on the second song. Anna moves the last song to
    // the front, edits the first and deletes the one Ben is playing.
    await barrier(tester, 'b-live');
    await tester.runAsync(() async {
      final items = await sets.getItems(setId);
      await sets.reorder(setId, [for (final i in items.reversed) i.item.id]);
      await songs.updateSource(ids[liveOne]!, liveSource(liveOneEdited));
      await songs.deleteSong(ids[liveTwo]!);
    });
    expect(await tester.runAsync(() => setOrder(db, setId)), [
      ids[liveThree],
      ids[liveOne],
    ], reason: 'the deleted song left the set');
    await waitUntilPushed(tester, db, [...ids.values, setId]);
    await signal(tester, 'a-changed');

    await barrier(tester, 'b-done', timeout: const Duration(minutes: 5));
  });
}
