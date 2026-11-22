// End-to-end story "conflicts", client b: Carla, librarian and set planner,
// in the web client (make e2e, issue #692, docs/development/e2e-tests.md).
// Her counterpart is conflicts_a_test.dart: Anna on the Linux desktop.
//
// Carla goes offline and changes the songs Anna changes or deletes
// meanwhile, creates a song and renames a set. Back online, every song is a
// conflict (ADR-0004), which Carla resolves on the song's screen: keep
// mine, use the server version, keep both; and for a song Anna deleted,
// keep mine (restores it) or use the server version (accepts the deletion).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/providers.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import '../support.dart';
import '../web/web_support.dart' show signIn, startApp;
import 'conflicts_texts.dart';
import 'e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('conflicts: Carla in the web client', (tester) async {
    await e2eSettings();
    await startApp();
    await signIn(tester, email: carlaEmail, password: e2ePassword);
    await waitForFixture(tester);

    final container = containerOf(tester);
    final db = databaseOf(tester);
    final band = await selectFixtureBand(tester);
    final songs = container.read(
      librarySongRepositoryProvider(band.organizationId!),
    );
    final sets = container.read(setRepositoryProvider);

    await signal(tester, 'b-ready');
    await barrier(tester, 'a-ready');

    // 1. Anna's songs and set arrive.
    await barrier(tester, 'songs-created');
    final ids = <String, String>{};
    late SetlistEntry set;
    await eventually(tester, () async {
      for (final title in conflictSongs) {
        final song = await songTitled(db, title);
        if (song == null) return false;
        ids[title] = song.id;
      }
      final found = await setNamed(db, lwwSet);
      if (found == null) return false;
      set = found;
      return true;
    }, reason: "Anna's songs and set did not reach Carla");

    // 2. Offline, Carla changes all of them, creates a song and renames the
    // set. Nothing reaches the server.
    await setOnline(tester, online: false);
    final offlineId = (await tester.runAsync(() async {
      for (final title in conflictSongs) {
        await songs.updateSource(ids[title]!, carlasVersion(title));
      }
      await sets.updateSet(set.id, name: carlasSet);
      return songs.createSong(source: '{title: $offlineSong}\n[E]Queued');
    }))!;
    final report = await tester.runAsync(
      () => container.read(syncControllerProvider.notifier).syncNow(),
    );
    expect(report?.error, isNotNull, reason: 'a sync offline fails');
    for (final id in [...ids.values, set.id, offlineId]) {
      expect(
        await tester.runAsync(() => pushed(db, id)),
        isFalse,
        reason: 'offline, the changes wait in the outbox',
      );
    }
    await signal(tester, 'b-offline');

    // 3. Back online after Anna's changes: every song is a conflict.
    await barrier(tester, 'a-changed');
    await setOnline(tester, online: true);
    await eventually(
      tester,
      () async {
        await container.read(syncControllerProvider.notifier).syncNow();
        final conflicts = await db.select(db.songConflicts).get();
        return conflicts.length == conflictSongs.length;
      },
      reason: 'the conflicts were not detected',
      timeout: const Duration(seconds: 60),
    );

    // 4. Carla resolves them on the songs' screens.
    await tester.tap(find.byKey(const Key('nav-songs')));
    await pumpUntil(tester, find.text(offlineSong));

    await _resolve(tester, keepMine, 'conflict-keep-mine');
    await _resolve(tester, takeServer, 'conflict-take-server');
    await eventually(
      tester,
      () async =>
          (await songById(db, ids[takeServer]!))!.chordproSource ==
          annasVersion(takeServer),
      reason: '"Use server version": the server version was not taken',
    );
    await _resolve(tester, keepBoth, 'conflict-keep-both');
    await pumpUntil(
      tester,
      find.text('Your version was saved as a separate song.'),
    );
    await _resolve(tester, deletedKeep, 'conflict-keep-mine', deleted: true);
    await _resolve(
      tester,
      deletedAccept,
      'conflict-take-server',
      deleted: true,
      back: false,
    );
    await eventually(
      tester,
      () async => (await songById(db, ids[deletedAccept]!))!.deleted,
      reason: '"Use server version": the deletion was not taken',
    );
    Navigator.of(tester.element(find.byType(Navigator).first))
        .popUntil((route) => route.isFirst);
    await pumpUntil(tester, find.byType(HomeScreen));

    // 5. Everything is pushed: no conflict and no change is left.
    await eventually(
      tester,
      () async {
        await container.read(syncControllerProvider.notifier).syncNow();
        return (await db.select(db.songConflicts).get()).isEmpty &&
            (await db.select(db.syncOutbox).get()).isEmpty;
      },
      reason: "Carla's resolutions were not pushed",
      timeout: const Duration(seconds: 60),
    );
    expect(
      (await tester.runAsync(() => sets.getSet(set.id)))!.name,
      carlasSet,
      reason: "the set: Carla's later push wins",
    );
    await signal(tester, 'b-resolved');
    await barrier(tester, 'a-verified');
  });
}

/// Opens [title] from the song list, checks its conflict banner and taps
/// the button with [button]; goes back to the list unless [back] is false.
Future<void> _resolve(
  WidgetTester tester,
  String title,
  String button, {
  bool deleted = false,
  bool back = true,
}) async {
  final entry = find.text(title).first;
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await pumpUntil(tester, find.byType(SongScreen));
  final banner = find.byKey(const Key('conflict-banner'));
  await pumpUntil(tester, banner);
  expect(
    find.descendant(
      of: banner,
      matching: find.text(
        deleted
            ? 'This song was deleted on the server and changed on this device.'
            : 'This song was changed on the server and on this device.',
      ),
    ),
    findsOneWidget,
    reason: title,
  );
  expect(
    find.byKey(const Key('conflict-keep-both')),
    deleted ? findsNothing : findsOneWidget,
    reason: '"Keep both" only for a changed song',
  );
  final action = find.byKey(Key(button));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await eventually(
    tester,
    () async => banner.evaluate().isEmpty,
    reason: '$title: the banner stayed',
  );
  expect(tester.takeException(), isNull);
  if (back) {
    await tester.pageBack();
    await pumpUntil(tester, find.byType(HomeScreen));
  }
}
