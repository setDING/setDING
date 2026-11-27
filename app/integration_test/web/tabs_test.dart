// Several loads and tabs of the web client (make web-test,
// docs/development/web-tests.md, ADR-0018). One test in four page loads:
//
// 1. start (tab A): sign in without "Stay signed in", wait for the sync,
//    then reload the tab;
// 2. reloaded (tab A): still signed in, the data is still in OPFS; open a
//    second tab;
// 3. second-tab (tab B): gets the session from tab A over the
//    BroadcastChannel, without signing in; signs out, then the driver goes
//    back to tab A;
// 4. signed-out-elsewhere (tab A): reloaded itself when tab B signed out;
//    shows the sign-in gate, and its local data is deleted.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/bootstrap/platform_services_web.dart';
import 'package:setding/data/storage_providers.dart';
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'web_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'keeps the session on reload, shares it with a new tab and signs out '
    'all tabs ($step)',
    (tester) async {
      await startApp();
      switch (step) {
        case 'start':
          await signIn(tester);
          await waitForSync(tester);
          expect(tabSession, isNotNull);
          then('reload', nextStep: 'reloaded');

        case 'reloaded':
          // No sign-in gate: the session is in this tab's sessionStorage.
          await pumpUntil(tester, find.byType(HomeScreen));
          expect(find.byKey(const Key('web-sign-in')), findsNothing);
          // The synced songs are still in the browser's database.
          expect(isOpfs(webDatabaseStorage), isTrue);
          expect(await localSong(tester, itestSong), isNotNull);
          expect(await localSong(tester, itestSheet), isNotNull);
          then('open', tabStep: 'second-tab', nextStep: 'signed-out-elsewhere');

        case 'second-tab':
          // A new tab has an empty sessionStorage: the open tab shares its
          // session over the BroadcastChannel.
          await pumpUntil(
            tester,
            find.byType(HomeScreen),
            timeout: const Duration(seconds: 60),
          );
          expect(find.byKey(const Key('web-sign-in')), findsNothing);
          expect(tabSession, isNotNull);
          expect(keptSession, isNull);
          await signOut(tester);
          expect(tabSession, isNull);
          then('back');

        case 'signed-out-elsewhere':
          // Tab A reloaded when tab B signed out: no session, and the start
          // without a session deleted the local data.
          await pumpUntil(tester, find.byKey(const Key('web-sign-in')));
          expect(tabSession, isNull);
          final db = containerOf(tester).read(databaseProvider);
          await waitForLocalDataDeleted(tester, db);

        default:
          fail('unknown step $step');
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
