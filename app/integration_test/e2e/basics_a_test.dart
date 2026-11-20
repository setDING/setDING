// End-to-end story "basics", client a: Anna, organization admin and band
// leader, on the Linux desktop (make e2e, issue #692,
// docs/development/e2e-tests.md). Her counterpart is basics_b_test.dart:
// Ben, set planner, in the web client.
//
// Anna creates a song, edits it while Ben has it open and plans a gig with
// it; Ben plays the gig live and then changes the set's order, which
// reaches Anna.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'e2e_support.dart';

const _song = 'Realtime Song';
const _edited = 'Realtime Song (edited)';
const _set = 'E2E Gig';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('basics: Anna on the Linux desktop', (tester) async {
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

    await signal(tester, 'a-ready');
    await barrier(tester, 'b-ready');

    // 1. A new song reaches Ben without him syncing by hand (realtime).
    final songId = (await tester.runAsync(
      () => songs.createSong(
        source: '{title: $_song}\n{key: C}\n[C]Hello [G]world',
      ),
    ))!;
    await signal(tester, 'song-created');
    await barrier(tester, 'b-sees-song');

    // 2. An edit reaches the song screen Ben has open.
    await barrier(tester, 'b-song-open');
    await tester.runAsync(
      () => songs.updateSource(
        songId,
        '{title: $_edited}\n{key: C}\n[Am]Changed [F]line',
      ),
    );
    await signal(tester, 'song-edited');
    await barrier(tester, 'b-sees-edit');

    // 3. A gig today with the song and the PDF-only song: Ben plays it.
    final sheetId = (await tester.runAsync(() => songTitled(db, fixtureSheet)))!
        .id;
    final sets = container.read(setRepositoryProvider);
    final now = DateTime.now();
    final setId = (await tester.runAsync(() async {
      final id = await sets.createSet(
        name: _set,
        gigDate: DateTime(now.year, now.month, now.day),
      );
      await sets.addSongs(id, [songId, sheetId]);
      return id;
    }))!;
    await signal(tester, 'set-created');

    // 4. Ben (set planner) changes the order after the gig; it reaches Anna.
    await barrier(tester, 'b-reordered', timeout: const Duration(minutes: 5));
    await eventually(
      tester,
      () async => (await setOrder(db, setId)).join(',') == '$sheetId,$songId',
      reason: "Ben's new order did not reach Anna",
    );
    await signal(tester, 'a-sees-order');
  });
}
