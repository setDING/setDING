// Links from outside the app on Android (make android-test, ADR-0065 §6):
// tool/android-test.sh fires App Links and setding:// links with
// `adb shell am start` (openLink), Android hands them to the running app
// through its intent filters, and the app opens the set or the join screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setding/main.dart' as app;
import 'package:setding/providers.dart';
import 'package:setding/ui/bands/join_screen.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const _token = 'abcdefghijklmnop0123456789';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Links and setding:// links open their set and the join screen',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', 'en');

      await app.main();
      await pumpUntil(tester, find.byType(HomeScreen));
      final context = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(context, listen: false);
      final setId = (await tester.runAsync(
        () =>
            container.read(setRepositoryProvider).createSet(name: 'Linked set'),
      ))!;

      final setPage = find.byWidgetPredicate(
        (w) => w is SetScreen && w.setId == setId && !w.embedded,
      );
      Future<void> opens(String link, Finder screen) async {
        GoRouter.of(context).go('/');
        await pumpUntil(tester, find.byType(HomeScreen));
        await pumpFor(tester, const Duration(milliseconds: 300));
        expect(screen, findsNothing);
        openLink(link);
        await pumpUntil(tester, screen);
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: link);
      }

      // App Link on the web client's host, as shared from the set screen.
      await opens('https://app.setding.app/sets/$setId', setPage);
      expect(find.text('Linked set'), findsWidgets);
      // The protocol link of the desktops also opens on Android.
      await opens('setding://sets/$setId', setPage);

      // Invitations on both hosts and as setding:// link.
      final join = find.byWidgetPredicate(
        (w) => w is JoinScreen && w.initialLink == _token,
      );
      await opens('https://api.setding.app/invite/$_token', join);
      await opens('https://app.setding.app/invite/$_token', join);
      await opens('setding://invite/$_token', join);
    },
    // Needs the runner of make android-test to fire the links.
    skip: !linksFromRunner,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
