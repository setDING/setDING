import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/app.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/account/sign_in_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/widgets/update_required_banner.dart';
import 'package:setding/util/semver.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// "Please update setDING" when the server refuses this version (ADR-0029).
void main() {
  group('compareVersions', () {
    test('orders by SemVer precedence', () {
      const ordered = [
        'garbage',
        '0.6.0',
        '0.6.1',
        '0.10.0',
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '2.0.0',
        '10.0.0',
      ];
      for (var i = 0; i < ordered.length; i++) {
        for (var j = 0; j < ordered.length; j++) {
          expect(
            compareVersions(ordered[i], ordered[j]),
            (i - j).sign,
            reason: '${ordered[i]} vs ${ordered[j]}',
          );
        }
      }
    });

    test('ignores build metadata and a leading v', () {
      expect(compareVersions('1.2.3+7', '1.2.3'), 0);
      expect(compareVersions('v1.2.3', '1.2.3'), 0);
      expect(isOlderThan('0.0.0', '0.0.0'), isFalse);
      expect(isOlderThan('0.6.0', '1.0.0'), isTrue);
    });
  });

  Widget build(TestApp app, Widget? home, {String version = '0.6.0'}) =>
      ProviderScope(
        overrides: [
          ...app.overrides,
          clientVersionProvider.overrideWithValue(version),
        ],
        child: SetdingApp(home: home),
      );

  Future<TestApp> signedIn(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    return app;
  }

  testWidgets('a refused sync shows the banner above all tabs', (tester) async {
    final app = await signedIn(tester);
    await tester.pumpWidget(build(app, null));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-required-banner')), findsNothing);

    app.backend.config = const ServerConfig(minClientVersion: '1.0.0');
    app.backend.failWith = BackendErrorKind.updateRequired;
    await syncNow(tester);

    expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
    expect(find.text('Please update setDING'), findsOneWidget);
    expect(
      find.textContaining('Installed: 0.6.0, needed: 1.0.0 or newer.'),
      findsOneWidget,
    );
    expect(find.textContaining('Obtainium'), findsOneWidget);

    // Still there on the other tabs.
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.account);
    expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
    expect(
      find.textContaining('This version of setDING is too old'),
      findsOneWidget,
    );

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('update-copy-link')));
    await tester.pumpAndSettle();
    expect(copied, releasesUrl);
    expect(find.text('Link copied.'), findsOneWidget);

    // After the update (here: the server accepts again) the banner goes.
    app.backend.failWith = null;
    await syncNow(tester);
    expect(find.byKey(const Key('update-required-banner')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('other sync errors show no banner', (tester) async {
    final app = await signedIn(tester);
    await tester.pumpWidget(build(app, const SettingsScreen()));
    await tester.pumpAndSettle();
    app.backend.failWith = BackendErrorKind.network;
    await syncNow(tester);
    expect(find.byKey(const Key('update-required-banner')), findsNothing);
    await app.dispose(tester);
  });

  group('sign-in screen', () {
    Future<TestApp> signedOut(WidgetTester tester) async {
      useTabletSize(tester);
      return TestApp.create(prefs: {'language': 'en'});
    }

    testWidgets('warns before signing in with an outdated version', (
      tester,
    ) async {
      final app = await signedOut(tester);
      app.backend.config = const ServerConfig(minClientVersion: '1.0.0');
      await tester.pumpWidget(build(app, const SignInScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
      expect(
        find.textContaining('Installed: 0.6.0, needed: 1.0.0 or newer.'),
        findsOneWidget,
      );
      await app.dispose(tester);
    });

    testWidgets('shows nothing for a current version', (tester) async {
      final app = await signedOut(tester);
      app.backend.config = const ServerConfig(minClientVersion: '0.6.0');
      await tester.pumpWidget(build(app, const SignInScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-banner')), findsNothing);
      await app.dispose(tester);
    });
  });
}
