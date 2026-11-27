import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/app.dart';
import 'package:setding/platform/install_source.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/update_check.dart';
import 'package:setding/ui/account/sign_in_screen.dart';
import 'package:setding/ui/widgets/app_info.dart';

import 'test_app.dart';

/// Play installs update in Google Play, not in Obtainium or from the GitHub
/// release (ADR-0067, ADR-0036).
void main() {
  group('detectGooglePlayInstall', () {
    const channel = MethodChannel('app.setding/install_source');

    Future<bool> detect(Object? installer) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'installer');
            if (installer is Exception) throw installer;
            return installer;
          });
      try {
        return await detectGooglePlayInstall(channel: channel);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    }

    test('Google Play', () async {
      expect(await detect('com.android.vending'), isTrue);
    });

    test('other installers, none, or an error', () async {
      expect(await detect('com.google.android.packageinstaller'), isFalse);
      expect(await detect(null), isFalse);
      expect(await detect(PlatformException(code: 'x')), isFalse);
    });

    test('not on other platforms', () async {
      expect(await detectGooglePlayInstall(channel: channel), isFalse);
    });
  });

  test('update page: Google Play or the GitHub release', () {
    expect(
      updatePageUrl('0.7.0', googlePlay: true).toString(),
      'https://play.google.com/store/apps/details?id=app.setding',
    );
    expect(updatePageUrl('0.7.0', googlePlay: false), releasePageUrl('0.7.0'));
  });

  Widget build(TestApp app, Widget home, {required bool googlePlay}) =>
      ProviderScope(
        overrides: [
          ...app.overrides,
          clientVersionProvider.overrideWithValue('0.6.0'),
          updateCheckEnabledProvider.overrideWithValue(true),
          installedFromGooglePlayProvider.overrideWithValue(googlePlay),
        ],
        child: SetdingApp(home: home),
      );

  for (final googlePlay in [true, false]) {
    testWidgets(
      'the update tile names ${googlePlay ? 'Google Play' : 'Obtainium'}',
      (tester) async {
        useTabletSize(tester);
        final app = await TestApp.create(
          prefs: {
            'language': 'en',
            'updateCheck.latest': '0.7.0',
            'updateCheck.checkedAt': DateTime.now().millisecondsSinceEpoch,
          },
        );
        await tester.pumpWidget(
          build(
            app,
            const Scaffold(body: UpdateAvailableTile()),
            googlePlay: googlePlay,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('setDING 0.7.0 is available'), findsOneWidget);
        expect(
          find.textContaining('Update it in Google Play.'),
          googlePlay ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('Obtainium'),
          googlePlay ? findsNothing : findsOneWidget,
        );
        await app.dispose(tester);
      },
    );
  }

  testWidgets('"Please update" offers Google Play instead of the link', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    app.backend.config = const ServerConfig(minClientVersion: '1.0.0');
    await tester.pumpWidget(build(app, const SignInScreen(), googlePlay: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
    expect(find.textContaining('Update it in Google Play.'), findsOneWidget);
    expect(find.textContaining('Obtainium'), findsNothing);
    expect(find.byKey(const Key('update-copy-link')), findsNothing);

    final launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
    await tester.tap(find.text('Open in Google Play'));
    await tester.pumpAndSettle();
    expect(launched, [googlePlayUrl.toString()]);
    await app.dispose(tester);
  });
}
