// web-test: no-isolation
//
// The web client without the isolation headers (make web-test,
// docs/development/web-tests.md, ADR-0018): tool/web-test.sh serves this
// build from a plain static server on another port, the API stays on the
// local PocketBase (cross-origin, SETDING_SERVER_URL). The page is not
// cross-origin isolated (no SharedArrayBuffer), so drift cannot use
// opfsLocks: Chrome falls back to IndexedDB; Firefox keeps OPFS through a
// shared worker (opfsShared), as with the headers. One test in two page
// loads:
//
// 1. start: sign in and sync into the fallback storage, then reload;
// 2. reloaded: still signed in, the data survived; sign out.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/bootstrap/platform_services_web.dart';
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:web/web.dart' as web;

import '../support.dart';
import 'web_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'falls back to another storage without the isolation headers ($step)',
    (tester) async {
      expect(web.window.crossOriginIsolated, isFalse);
      await startApp();
      switch (step) {
        case 'start':
          await signIn(tester);
          expect(
            isFallback(webDatabaseStorage),
            isTrue,
            reason: '$webDatabaseStorage',
          );
          await waitForSync(tester);
          then('reload', nextStep: 'reloaded');

        case 'reloaded':
          await pumpUntil(tester, find.byType(HomeScreen));
          expect(isFallback(webDatabaseStorage), isTrue);
          expect(await localSong(tester, itestSong), isNotNull);
          expect(await localSong(tester, itestSheet), isNotNull);
          final db = containerOf(tester).read(databaseProvider);
          await signOut(tester);
          await waitForLocalDataDeleted(tester, db);

        default:
          fail('unknown step $step');
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
