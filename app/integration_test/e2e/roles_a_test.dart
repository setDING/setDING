// End-to-end story "roles", client a: Anna, organization admin and band
// leader, on the Linux desktop (make e2e, issue #692,
// docs/development/e2e-tests.md). Her counterpart is roles_b_test.dart: Ben,
// set planner, in the web client.
//
// Anna deletes a song Ben adjusted for himself and undoes it, deletes it
// again and restores it from the trash (the song only, not its place in the
// set). Then she makes Ben a plain member while he changes the set offline,
// and finally removes him from the band.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/data/band_providers.dart';
import 'package:setding/data/band_role.dart';
import 'package:setding/data/set_providers.dart';
import 'package:setding/data/song_providers.dart';
import 'package:setding/data/trash_providers.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'e2e_support.dart';
import 'roles_texts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('roles: Anna on the Linux desktop', (tester) async {
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
    final trash = container.read(trashRepositoryProvider);
    final bands = container.read(bandServiceProvider);
    Future<void> syncNow() =>
        container.read(syncControllerProvider.notifier).syncNow();

    await signal(tester, 'a-ready');
    await barrier(tester, 'b-ready');

    // 1. A set with three songs.
    final ids = (await tester.runAsync(() async {
      return {
        for (final title in roleSongs)
          title: await songs.createSong(source: roleSource(title)),
      };
    }))!;
    final setId = (await tester.runAsync(() async {
      final id = await sets.createSet(name: roleSet);
      await sets.addSongs(id, [for (final title in roleSongs) ids[title]!]);
      return id;
    }))!;
    await waitUntilPushed(tester, db, [...ids.values, setId]);
    await signal(tester, 'planned');

    // 2. Ben transposes the song for himself; Anna's version stays as it is
    // (personal adjustments, ADR-0006, ADR-0020).
    await barrier(tester, 'b-transposed');
    await tester.runAsync(syncNow);
    expect(
      (await tester.runAsync(() => songs.getOverlay(ids[roleSong]!)))!
          .transpose,
      0,
      reason: "Ben's transposition is his own",
    );

    // 3. Anna deletes the song and undoes it right away: Ben gets the song
    // back in the set, and his transposition with it (ADR-0015).
    final deleted = (await tester.runAsync(
      () => songs.deleteSong(ids[roleSong]!),
    ))!;
    await waitUntilPushed(tester, db, [ids[roleSong]!, setId]);
    await signal(tester, 'a-deleted');
    await barrier(tester, 'b-sees-deleted');
    await tester.runAsync(() => songs.restoreSong(deleted));
    await waitUntilPushed(tester, db, [ids[roleSong]!, setId]);
    await signal(tester, 'a-undone');
    await barrier(tester, 'b-sees-undone');

    // 4. Deleted again and restored from the trash: the song is back, its
    // place in the set is not (ADR-0043).
    await tester.runAsync(() => songs.deleteSong(ids[roleSong]!));
    await waitUntilPushed(tester, db, [ids[roleSong]!, setId]);
    await signal(tester, 'a-deleted-again');
    await barrier(tester, 'b-sees-deleted-again');
    await tester.runAsync(() => trash.restoreSong(ids[roleSong]!));
    await waitUntilPushed(tester, db, [ids[roleSong]!]);
    expect(await tester.runAsync(() => setOrder(db, setId)), [
      ids[otherSong],
      ids[thirdSong],
    ], reason: 'the trash restores the song only');
    await signal(tester, 'a-restored');
    await barrier(tester, 'b-sees-restored');

    // 5. Ben reorders the set offline; meanwhile Anna makes him a plain
    // member. His change is refused and stays on his device (ADR-0004);
    // the band keeps Anna's order.
    await barrier(tester, 'b-offline-reordered');
    final ben = (await tester.runAsync(
      () =>
          (db.select(db.memberships)..where(
                (m) => m.bandId.equals(band.id) & m.userName.equals('Ben'),
              ))
              .getSingle(),
    ))!;
    await tester.runAsync(() => bands.setRole(ben.id, BandRole.member));
    await signal(tester, 'a-demoted');
    await barrier(tester, 'b-demoted');
    await tester.runAsync(syncNow);
    expect(await tester.runAsync(() => setOrder(db, setId)), [
      ids[otherSong],
      ids[thirdSong],
    ], reason: "a member's change of a set does not reach the band");

    // 6. Anna removes Ben from the band.
    await tester.runAsync(() => bands.removeMember(ben.id));
    await signal(tester, 'a-removed');
    await barrier(tester, 'b-removed');
  });
}
