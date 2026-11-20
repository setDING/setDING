// End-to-end story "conflicts", client a: Anna, organization admin and band
// leader, on the Linux desktop (make e2e, issue #692,
// docs/development/e2e-tests.md). Her counterpart is conflicts_b_test.dart:
// Carla, librarian and set planner, in the web client.
//
// Anna changes and deletes songs while Carla changes the same songs
// offline. Carla resolves each conflict differently (ADR-0004); Anna gets
// the result of every resolution. Carla's offline queue (a new song, a set
// renamed by both: last writer wins) reaches Anna as well.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'conflicts_texts.dart';
import 'e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('conflicts: Anna on the Linux desktop', (tester) async {
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

    // 1. The songs both change, and a set both rename.
    final ids = (await tester.runAsync(() async {
      return {
        for (final title in conflictSongs)
          title: await songs.createSong(source: original(title)),
      };
    }))!;
    final setId = (await tester.runAsync(() async {
      final id = await sets.createSet(name: lwwSet);
      await sets.addSongs(id, [ids[keepMine]!]);
      return id;
    }))!;
    await _waitUntilPushed(tester, db, [...ids.values, setId]);
    await signal(tester, 'songs-created');

    // 2. Carla is offline with her changes; Anna changes the songs on the
    // server meanwhile.
    await barrier(tester, 'b-offline');
    await tester.runAsync(() async {
      for (final title in [keepMine, takeServer, keepBoth]) {
        await songs.updateSource(ids[title]!, annasVersion(title));
      }
      for (final title in [deletedKeep, deletedAccept]) {
        await songs.deleteSong(ids[title]!);
      }
      await sets.updateSet(setId, name: annasSet);
    });
    await _waitUntilPushed(tester, db, [...ids.values, setId]);
    await signal(tester, 'a-changed');

    // 3. Carla resolved the conflicts; their results reach Anna.
    await barrier(tester, 'b-resolved', timeout: const Duration(minutes: 5));
    Future<String?> source(String title) async =>
        (await songById(db, ids[title]!))?.chordproSource;
    await eventually(
      tester,
      () async => await source(keepMine) == carlasVersion(keepMine),
      reason: '"Keep mine": Carla\'s version did not reach Anna',
    );
    expect(
      await tester.runAsync(() => source(takeServer)),
      annasVersion(takeServer),
      reason: '"Use server version" keeps the server version',
    );
    await eventually(tester, () async {
      final copies =
          await (db.select(db.songs)..where(
                (s) =>
                    s.chordproSource.equals(carlasVersion(keepBoth)) &
                    s.deleted.equals(false),
              ))
              .get();
      return copies.length == 1 &&
          copies.single.id != ids[keepBoth] &&
          await source(keepBoth) == annasVersion(keepBoth);
    }, reason: '"Keep both": Carla\'s copy did not reach Anna');
    await eventually(tester, () async {
      final song = await songById(db, ids[deletedKeep]!);
      return song != null &&
          !song.deleted &&
          song.chordproSource == carlasVersion(deletedKeep);
    }, reason: '"Keep mine" on a deleted song: it was not restored');
    expect(
      (await tester.runAsync(() => songById(db, ids[deletedAccept]!)))!.deleted,
      isTrue,
      reason: '"Use server version" on a deleted song keeps it deleted',
    );
    await eventually(
      tester,
      () async => await songTitled(db, offlineSong) != null,
      reason: "the song Carla created offline did not reach Anna",
    );
    await eventually(
      tester,
      () async => (await sets.getSet(setId))?.name == carlasSet,
      reason: 'the set: the last writer (Carla) did not win',
    );
    await signal(tester, 'a-verified');
  });
}

/// Waits until the changes of [ids] reached the server.
Future<void> _waitUntilPushed(
  WidgetTester tester,
  AppDatabase db,
  List<String> ids,
) => eventually(tester, () async {
  for (final id in ids) {
    if (!await pushed(db, id)) return false;
  }
  return true;
}, reason: "Anna's changes were not pushed");
