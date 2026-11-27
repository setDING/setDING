// Sign-in and sync against a real PocketBase over the network (make
// android-test): tool/android-test.sh starts it on the development machine
// (server/bin/itest_backend.dart), forwards its port to the device with
// `adb reverse` and passes the account with --dart-define.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/storage_providers.dart';
import 'package:setding/main.dart' as app;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setding/sync/session_store.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const _server = String.fromEnvironment('SETDING_ITEST_SERVER');
const _email = String.fromEnvironment('SETDING_ITEST_EMAIL');
const _password = String.fromEnvironment('SETDING_ITEST_PASSWORD');
const _song = String.fromEnvironment('SETDING_ITEST_SONG');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'signs in, syncs the library and keeps the session',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', 'en');
      await prefs.setString('serverUrl', _server);

      await app.main();
      await pumpUntil(tester, find.byType(HomeScreen));
      final context = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(context, listen: false);

      // Settings → Account → Sign in, through the real UI.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      final account = find.byKey(
        Key('settings-category-${SettingsCategory.account.name}'),
      );
      await pumpUntil(tester, find.byType(SettingsScreen));
      await tester.scrollUntilVisible(
        account,
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(account);
      await pumpUntil(tester, find.byKey(const Key('account-open-sign-in')));
      await tester.tap(find.byKey(const Key('account-open-sign-in')));
      await pumpUntil(tester, find.byKey(const Key('account-email')));
      await tester.enterText(find.byKey(const Key('account-email')), _email);
      await tester.enterText(
        find.byKey(const Key('account-password')),
        _password,
      );
      await tester.tap(find.byKey(const Key('account-submit')));
      await pumpUntil(tester, find.byKey(const Key('account-sign-out')));
      expect(find.byKey(const Key('account-error')), findsNothing);

      // The sync brings the organization's song onto the device.
      final db = container.read(databaseProvider);
      Future<List<SongEntry>> synced() => tester
          .runAsync(
            () => (db.select(
              db.songs,
            )..where((s) => s.title.equals(_song))).get(),
          )
          .then((r) => r!);
      final end = DateTime.now().add(const Duration(seconds: 60));
      while ((await synced()).isEmpty) {
        if (DateTime.now().isAfter(end)) {
          fail('$_song was not synced within 60 s');
        }
        await pumpFor(tester, const Duration(milliseconds: 500));
      }
      expect((await synced()).single.chordproSource, contains('From the'));

      // The session is in the platform's secure storage, for the next start.
      final stored = await tester.runAsync(() async {
        final store = SecureSessionStore();
        await store.load();
        return store.current;
      });
      expect(stored, contains(_server));
    },
    // Needs the server of make android-test.
    skip: _server.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
