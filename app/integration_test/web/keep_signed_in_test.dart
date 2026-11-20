// "Stay signed in" in the web client (make web-test,
// docs/development/web-tests.md, ADR-0018). One test in two page loads:
//
// 1. start: sign in with "Stay signed in", wait for the sync; the driver
//    closes the tab and opens a new one, so no tab can share its session;
// 2. reopened: still signed in from localStorage, the data is still in the
//    browser's database; signing out removes the kept session.
//
// Without "Stay signed in" a new tab with no other tab open shows the
// sign-in gate: tabs_test.dart's tab B only gets its session from tab A.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';

import '../support.dart';
import 'web_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'keeps the session after closing the tab with "Stay signed in" ($step)',
    (tester) async {
      await startApp();
      switch (step) {
        case 'start':
          await signIn(tester, keepSignedIn: true);
          await waitForSync(tester);
          expect(keptSession, contains(Uri.base.origin));
          expect(tabSession, isNull);
          then('replace', tabStep: 'reopened');

        case 'reopened':
          await pumpUntil(tester, find.byType(HomeScreen));
          expect(find.byKey(const Key('web-sign-in')), findsNothing);
          expect(keptSession, isNotNull);
          expect(await localSong(tester, itestSong), isNotNull);
          final db = containerOf(tester).read(databaseProvider);
          await signOut(tester);
          expect(keptSession, isNull);
          expect(tabSession, isNull);
          await waitForLocalDataDeleted(tester, db);

        default:
          fail('unknown step $step');
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
