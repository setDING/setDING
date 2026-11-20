// End-to-end story "live", client b: Ben, set planner, in the web client
// (make e2e, issue #692, docs/development/e2e-tests.md). His counterpart is
// live_a_test.dart: Anna on the Linux desktop.
//
// Ben plays Anna's gig live. While he is on stage, she reorders it, edits a
// song and deletes the song he is playing: his stage stays as it was and
// his device does not sync (ADR-0007). Once he leaves live mode, the
// changes arrive; the deleted song is gone from the set without a word
// (a hint is #691).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';

import '../support.dart';
import '../web/web_support.dart' show pressKey, signIn, startApp;
import 'e2e_support.dart';
import 'live_texts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('live: Ben in the web client', (tester) async {
    await e2eSettings();
    await startApp();
    await signIn(tester, email: benEmail, password: e2ePassword);
    await waitForFixture(tester);
    final db = databaseOf(tester);
    await selectFixtureBand(tester);

    await signal(tester, 'b-ready');
    await barrier(tester, 'a-ready');

    // 1. Anna's gig today arrives; Ben starts it from the overview and
    // turns to the second song.
    await barrier(tester, 'gig-planned');
    final ids = <String, String>{};
    late String setId;
    await eventually(tester, () async {
      for (final title in liveSongs) {
        final song = await songTitled(db, title);
        if (song == null) return false;
        ids[title] = song.id;
      }
      final set = await setNamed(db, liveGig);
      if (set == null || (await setOrder(db, set.id)).length != 3) {
        return false;
      }
      setId = set.id;
      return true;
    }, reason: "Anna's gig did not reach Ben");
    final planned = [for (final title in liveSongs) ids[title]];
    expect(await tester.runAsync(() => setOrder(db, setId)), planned);

    // The overview is the first tab (its icon is filled when selected).
    final overview = find.byIcon(Icons.dashboard_outlined);
    if (overview.evaluate().isNotEmpty) await tester.tap(overview);
    await pumpUntil(tester, find.text(liveGig));
    final startLive = find.byKey(const Key('overview-start-live'));
    await pumpUntil(tester, startLive);
    await tester.tap(startLive);
    await pumpUntil(tester, find.byType(LiveScreen));
    await pumpUntil(tester, find.text('1 / 3'));
    await pressKey(tester, 'PageDown');
    await pumpUntil(tester, find.text('2 / 3'));
    expect(onStage(liveTwo), findsWidgets);
    await signal(tester, 'b-live');

    // 2. Anna's changes are on the server. Ben's stage stays as it was and
    // his device does not take them: live mode pauses the sync. Nothing
    // can signal that something did not happen, so Ben watches a while
    // (the automatic sync runs a second after a server change).
    await barrier(tester, 'a-changed');
    await pumpFor(tester, const Duration(seconds: 5));
    final two = (await tester.runAsync(() => songById(db, ids[liveTwo]!)))!;
    expect(two.deleted, isFalse, reason: 'no sync in live mode');
    expect(
      (await tester.runAsync(() => songById(db, ids[liveOne]!)))!.title,
      liveOne,
      reason: 'no sync in live mode',
    );
    expect(
      await tester.runAsync(() => setOrder(db, setId)),
      planned,
      reason: 'no sync in live mode',
    );
    expect(find.text('2 / 3'), findsOneWidget, reason: 'still on song 2');
    expect(onStage(liveTwo), findsWidgets);
    await pressKey(tester, 'PageDown');
    await pumpUntil(tester, find.text('3 / 3'));
    expect(onStage(liveThree), findsWidgets);
    await pressKey(tester, 'PageUp');
    await pumpUntil(tester, find.text('2 / 3'));
    await pressKey(tester, 'PageUp');
    await pumpUntil(tester, find.text('1 / 3'));
    expect(onStage(liveOne), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(LiveScreen),
        matching: find.textContaining(liveOneEdited),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    // 3. Ben leaves live mode: the sync he missed runs, and the set has
    // Anna's order without the deleted song.
    Navigator.of(tester.element(find.byType(LiveScreen))).pop();
    await pumpUntil(tester, find.byType(HomeScreen));
    await eventually(
      tester,
      () async =>
          (await songById(db, ids[liveTwo]!))!.deleted &&
          (await songById(db, ids[liveOne]!))!.title == liveOneEdited &&
          (await setOrder(db, setId)).join(',') ==
              '${ids[liveThree]},${ids[liveOne]}',
      reason: "Anna's changes did not arrive after live mode",
    );

    // 4. The next time he plays it, it is Anna's version.
    await pumpUntil(tester, startLive);
    await tester.tap(startLive);
    await pumpUntil(tester, find.byType(LiveScreen));
    await pumpUntil(tester, find.text('1 / 2'));
    expect(onStage(liveThree), findsWidgets);
    await pressKey(tester, 'PageDown');
    await pumpUntil(tester, find.text('2 / 2'));
    expect(onStage(liveOneEdited), findsWidgets);
    expect(onStage(liveTwo), findsNothing);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(LiveScreen))).pop();
    await pumpUntil(tester, find.byType(HomeScreen));
    await signal(tester, 'b-done');
  });
}

/// [text] on the live screen (the overview behind it lists songs, too).
Finder onStage(String text) =>
    find.descendant(of: find.byType(LiveScreen), matching: find.text(text));
