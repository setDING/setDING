import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/app.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/update_check.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/util/semver.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Unobtrusive hint when a newer release exists (ADR-0036).
void main() {
  group('isUpdate', () {
    test('only newer versions', () {
      expect(isUpdate('0.7.0', '0.6.0'), isTrue);
      expect(isUpdate('0.6.0', '0.6.0'), isFalse);
      expect(isUpdate('0.5.0', '0.6.0'), isFalse);
    });

    test('pre-releases only for people running a pre-release', () {
      expect(isUpdate('1.0.0-beta.1', '0.6.0'), isFalse);
      expect(isUpdate('1.0.0-beta.2', '1.0.0-beta.1'), isTrue);
      expect(isUpdate('1.0.0', '1.0.0-beta.1'), isTrue);
    });

    test('isPrerelease', () {
      expect(isPrerelease('1.0.0-rc.1'), isTrue);
      expect(isPrerelease('1.0.0+3'), isFalse);
    });

    test('release page', () {
      expect(
        releasePageUrl('0.7.0').toString(),
        'https://github.com/setDING/setDING/releases/tag/v0.7.0',
      );
    });
  });

  Widget build(TestApp app, {bool enabled = true, Widget? home}) =>
      ProviderScope(
        overrides: [
          ...app.overrides,
          clientVersionProvider.overrideWithValue('0.6.0'),
          updateCheckEnabledProvider.overrideWithValue(enabled),
        ],
        child: SetdingApp(home: home),
      );

  Future<TestApp> create(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1', ...prefs},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.config = const ServerConfig(latestClientVersion: '0.7.0');
    return app;
  }

  Future<void> afterStartDelay(WidgetTester tester) async {
    await tester.pump(UpdateCheck.startDelay);
    await tester.pumpAndSettle();
  }

  final snackbar = find.byKey(const Key('update-available-snackbar'));
  final dot = find.byKey(const Key('update-available-dot'));

  testWidgets('a newer release shows a dot, a one-time hint and a tile', (
    tester,
  ) async {
    final app = await create(tester);
    await tester.pumpWidget(build(app));
    await tester.pumpAndSettle();
    // Nothing right at the start.
    expect(snackbar, findsNothing);

    await afterStartDelay(tester);
    expect(snackbar, findsOneWidget);
    expect(
      find.descendant(
        of: snackbar,
        matching: find.text('setDING 0.7.0 is available'),
      ),
      findsOneWidget,
    );
    expect(find.text('Details'), findsOneWidget);
    expect(dot, findsWidgets);
    expect(app.prefs.getString('updateCheck.latest'), '0.7.0');
    expect(app.prefs.getInt('updateCheck.checkedAt'), isNotNull);
    expect(app.prefs.getString('updateCheck.notified'), '0.7.0');

    // The hint goes away by itself.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(snackbar, findsNothing);

    // Described in the settings.
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final about = find.byKey(const Key('settings-category-about'));
    await tester.scrollUntilVisible(
      about,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Not the last category: it may be scrolled in only partly.
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-available')), findsOneWidget);
    expect(find.textContaining('Installed: 0.6.0.'), findsOneWidget);
    expect(find.textContaining('Obtainium'), findsOneWidget);

    // The next start: the dot stays, the hint is not repeated, and the
    // server is not asked again within a day.
    app.backend.config = const ServerConfig(latestClientVersion: '0.8.0');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build(app));
    await afterStartDelay(tester);
    expect(dot, findsWidgets);
    expect(snackbar, findsNothing);
    expect(app.prefs.getString('updateCheck.latest'), '0.7.0');
    await app.dispose(tester);
  });

  testWidgets('asks again after a day and hints at the next version', (
    tester,
  ) async {
    final dayAgo = DateTime.now().subtract(UpdateCheck.interval);
    final app = await create(
      tester,
      prefs: {
        'updateCheck.latest': '0.7.0',
        'updateCheck.notified': '0.7.0',
        'updateCheck.checkedAt': dayAgo.millisecondsSinceEpoch,
      },
    );
    app.backend.config = const ServerConfig(latestClientVersion: '0.8.0');
    await tester.pumpWidget(build(app));
    await tester.pumpAndSettle();
    expect(dot, findsWidgets);
    expect(snackbar, findsNothing);

    await afterStartDelay(tester);
    expect(
      find.descendant(
        of: snackbar,
        matching: find.text('setDING 0.8.0 is available'),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('no hint while another screen is on top (e.g. live mode)', (
    tester,
  ) async {
    final app = await create(tester);
    await tester.pumpWidget(build(app));
    await tester.pumpAndSettle();
    // The root navigator, above the tabs' own (ADR-0065).
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Live')),
      ),
    );
    await tester.pumpAndSettle();

    await afterStartDelay(tester);
    expect(snackbar, findsNothing);
    // Shown on a later start instead.
    expect(app.prefs.getString('updateCheck.notified'), isNull);
    await app.dispose(tester);
  });

  testWidgets('silent when the server cannot be reached', (tester) async {
    final app = await create(tester);
    app.backend.failWith = BackendErrorKind.network;
    await tester.pumpWidget(build(app));
    await afterStartDelay(tester);
    expect(snackbar, findsNothing);
    expect(dot, findsNothing);
    expect(app.prefs.getInt('updateCheck.checkedAt'), isNull);
    await app.dispose(tester);
  });

  testWidgets('nothing when the server reports no newer release', (
    tester,
  ) async {
    final app = await create(tester);
    app.backend.config = const ServerConfig(latestClientVersion: '0.6.0');
    await tester.pumpWidget(build(app));
    await afterStartDelay(tester);
    expect(snackbar, findsNothing);
    expect(dot, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('off for the web client, debug and beta builds', (tester) async {
    final app = await create(tester);
    await tester.pumpWidget(build(app, enabled: false));
    await afterStartDelay(tester);
    expect(snackbar, findsNothing);
    expect(dot, findsNothing);
    expect(app.prefs.getInt('updateCheck.checkedAt'), isNull);
    await app.dispose(tester);
  });
}
