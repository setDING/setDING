// End-to-end story "roles", client b: Ben, set planner, in the web client
// (make e2e, issue #692, docs/development/e2e-tests.md). His counterpart is
// roles_a_test.dart: Anna on the Linux desktop.
//
// Ben transposes a song for himself. Anna deletes it and undoes it: the
// song, its place in the set and Ben's transposition come back. Deleted
// again and restored from the trash, only the song comes back. Ben reorders
// the set offline while Anna makes him a plain member: back online, he can
// no longer plan sets and his change stays on his device. Removed from the
// band, the band disappears from his device with a notice.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/providers.dart';
import 'package:setding/sync/sync_controller.dart';

import '../support.dart';
import '../web/web_support.dart' show signIn, startApp;
import 'e2e_support.dart';
import 'roles_texts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('roles: Ben in the web client', (tester) async {
    await e2eSettings();
    await startApp();
    await signIn(tester, email: benEmail, password: e2ePassword);
    await waitForFixture(tester);

    final container = containerOf(tester);
    final db = databaseOf(tester);
    final band = await selectFixtureBand(tester);
    final songs = container.read(
      librarySongRepositoryProvider(band.organizationId!),
    );
    final sets = container.read(setRepositoryProvider);
    Future<void> syncNow() =>
        container.read(syncControllerProvider.notifier).syncNow();

    await signal(tester, 'b-ready');
    await barrier(tester, 'a-ready');

    // 1. Anna's set arrives; Ben transposes the song for himself.
    await barrier(tester, 'planned');
    final ids = <String, String>{};
    late String setId;
    await eventually(tester, () async {
      for (final title in roleSongs) {
        final song = await songTitled(db, title);
        if (song == null) return false;
        ids[title] = song.id;
      }
      final set = await setNamed(db, roleSet);
      if (set == null || (await setOrder(db, set.id)).length != 3) {
        return false;
      }
      setId = set.id;
      return true;
    }, reason: "Anna's set did not reach Ben");
    final song = ids[roleSong]!;
    await tester.runAsync(
      () => songs.updateOverlay(
        song,
        (o) => o.copyWith(transpose: bensTranspose),
      ),
    );
    await eventually(
      tester,
      () async => (await db.select(db.syncOutbox).get()).isEmpty,
      reason: "Ben's transposition was not pushed",
    );
    await signal(tester, 'b-transposed');

    Future<int> transpose() async => (await songs.getOverlay(song)).transpose;
    Future<bool> isDeleted() async => (await songById(db, song))!.deleted;

    // 2. Anna deletes the song: it leaves Ben's library and the set.
    await barrier(tester, 'a-deleted');
    await eventually(
      tester,
      () async =>
          await isDeleted() &&
          (await setOrder(db, setId)).join(',') ==
              '${ids[otherSong]},${ids[thirdSong]}',
      reason: 'the deletion did not reach Ben',
    );
    await signal(tester, 'b-sees-deleted');

    // 3. She undoes it: the song is back in its place, with Ben's
    // transposition.
    await barrier(tester, 'a-undone');
    await eventually(
      tester,
      () async =>
          !await isDeleted() &&
          (await setOrder(db, setId)).join(',') ==
              '$song,${ids[otherSong]},${ids[thirdSong]}' &&
          await transpose() == bensTranspose,
      reason:
          'the undo did not bring back the song, its place and '
          "Ben's transposition",
    );
    await signal(tester, 'b-sees-undone');

    // 4. Deleted again and restored from the trash: the song and Ben's
    // transposition are back, its place in the set is not.
    await barrier(tester, 'a-deleted-again');
    await eventually(
      tester,
      () async => await isDeleted(),
      reason: 'the second deletion did not reach Ben',
    );
    await signal(tester, 'b-sees-deleted-again');
    await barrier(tester, 'a-restored');
    await eventually(
      tester,
      () async => !await isDeleted() && await transpose() == bensTranspose,
      reason: 'the restore from the trash did not reach Ben',
    );
    expect(await tester.runAsync(() => setOrder(db, setId)), [
      ids[otherSong],
      ids[thirdSong],
    ], reason: 'the trash restores the song only');
    await signal(tester, 'b-sees-restored');

    // 5. Offline, Ben (still set planner here) reorders the set. Meanwhile
    // Anna makes him a plain member: back online he can no longer plan
    // sets, the server refuses his change and it stays on his device.
    expect(container.read(currentBandProvider).canManageSets, isTrue);
    await setOnline(tester, online: false);
    final items = (await tester.runAsync(() => sets.getItems(setId)))!;
    await tester.runAsync(
      () => sets.reorder(setId, [for (final i in items.reversed) i.item.id]),
    );
    await signal(tester, 'b-offline-reordered');
    await barrier(tester, 'a-demoted');
    await setOnline(tester, online: true);
    await eventually(
      tester,
      () async {
        await syncNow();
        return !container.read(currentBandProvider).canManageSets &&
            await pushed(db, setId);
      },
      reason: 'Ben is still set planner on his device',
      timeout: const Duration(seconds: 60),
    );
    expect(await tester.runAsync(() => setOrder(db, setId)), [
      ids[thirdSong],
      ids[otherSong],
    ], reason: 'a refused change stays on the device (ADR-0004)');
    await signal(tester, 'b-demoted');

    // 6. Removed from the band, Ben gets a notice and the band is gone
    // from his device (ADR-0044).
    await barrier(tester, 'a-removed');
    await eventually(
      tester,
      () async {
        await syncNow();
        return (await fixtureBand(db))!.deleted;
      },
      reason: 'the band was not removed from Ben\'s device',
      timeout: const Duration(seconds: 60),
    );
    await pumpUntil(
      tester,
      find.textContaining('$e2eBand is no longer available to you'),
    );
    expect(tester.takeException(), isNull);
    await signal(tester, 'b-removed');
  });
}
