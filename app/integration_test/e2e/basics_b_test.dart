// End-to-end story "basics", client b: Ben, set planner, in the web client
// (make e2e, issue #692, docs/development/e2e-tests.md). His counterpart is
// basics_a_test.dart: Anna on the Linux desktop.
//
// Ben sees Anna's new song arrive without syncing by hand, sees her edit on
// the song screen he has open, plays her gig live from the overview and then
// changes the set's order.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/songs/song_screen.dart';

import '../support.dart';
import '../web/web_support.dart' show pressKey, signIn, startApp;
import 'e2e_support.dart';

const _song = 'Realtime Song';
const _edited = 'Realtime Song (edited)';
const _set = 'E2E Gig';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  e2eTest('basics: Ben in the web client', (tester) async {
    await e2eSettings();
    await startApp();
    await signIn(tester, email: benEmail, password: e2ePassword);
    await waitForFixture(tester);
    final db = databaseOf(tester);

    await signal(tester, 'b-ready');
    await barrier(tester, 'a-ready');

    // 1. Anna's new song shows up in the song list by itself (realtime).
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await pumpUntil(tester, find.text(fixtureSong));
    await barrier(tester, 'song-created');
    await pumpUntil(tester, find.text(_song));
    await signal(tester, 'b-sees-song');

    // 2. Her edit reaches the song screen Ben has open.
    await tester.tap(find.text(_song).first);
    await pumpUntil(tester, find.byType(SongScreen));
    await signal(tester, 'b-song-open');
    await barrier(tester, 'song-edited');
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byType(SongScreen),
        matching: find.text(_edited),
      ),
    );
    expect(tester.takeException(), isNull);
    await signal(tester, 'b-sees-edit');
    await tester.pageBack();
    await pumpUntil(tester, find.byType(HomeScreen));

    // 3. Her gig today is the next set on the overview; Ben plays it live,
    // the song and then the PDF fetched from the server.
    await barrier(tester, 'set-created');
    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await pumpUntil(tester, find.text(_set));
    final startLive = find.byKey(const Key('overview-start-live'));
    await pumpUntil(tester, startLive);
    await eventually(
      tester,
      () async => tester.widget<ButtonStyleButton>(startLive).enabled,
      reason: 'the set has no songs on Ben',
    );
    await tester.tap(startLive);
    await pumpUntil(tester, find.byType(LiveScreen));
    await pumpUntil(tester, find.text('1 / 2'));
    await pressKey(tester, 'PageDown');
    await pumpUntil(tester, find.text('2 / 2'));
    await pumpUntil(
      tester,
      find.byType(PdfSpreadView),
      timeout: const Duration(seconds: 60),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(LiveScreen))).pop();
    await pumpUntil(tester, find.byType(HomeScreen));

    // 4. As set planner, Ben puts the PDF song first; Anna gets the order.
    final set = (await tester.runAsync(() => setNamed(db, _set)))!;
    final items = (await tester.runAsync(
      () =>
          (db.select(db.setItems)..where((i) => i.setId.equals(set.id))).get(),
    ))!;
    final sheetId = (await tester.runAsync(() => songTitled(db, fixtureSheet)))!
        .id;
    items.sort((a, b) => a.songId == sheetId ? -1 : 1);
    await tester.runAsync(
      () =>
          containerOf(tester)
              .read(setRepositoryProvider)
              .reorder(set.id, [for (final i in items) i.id]),
    );
    await signal(tester, 'b-reordered');
    await barrier(tester, 'a-sees-order');
  });
}
