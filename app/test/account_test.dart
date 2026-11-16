import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/ui/account/account_section.dart';
import 'package:realchord/ui/settings_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'u1', email: 'ann@example.test', name: 'Ann');

void main() {
  Future<TestApp> pumpSettings(WidgetTester tester, {AuthUser? user}) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> enter(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  testWidgets('shows the signed-out state and the default server', (
    tester,
  ) async {
    final app = await pumpSettings(tester);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.textContaining(defaultServerUrl), findsOneWidget);
    // A stored session is refreshed once on start.
    expect(app.backend.refreshCount, 1);
    await app.dispose(tester);
  });

  testWidgets('signs in and shows the user', (tester) async {
    final app = await pumpSettings(tester);
    app.backend.accounts['ann@example.test'] = 'secret-pw';

    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'secret-pw');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-submit')), findsNothing);
    expect(find.text('ann@example.test'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('shows an error for wrong credentials', (tester) async {
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'wrong');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.byKey(const Key('account-submit')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('shows a network error', (tester) async {
    final app = await pumpSettings(tester);
    app.backend.failWith = BackendErrorKind.network;
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'pw');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No connection to the server'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('creates an account with name', (tester) async {
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();

    await enter(tester, 'account-name', 'Ann');
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'short');
    await enter(tester, 'account-password-confirm', 'other');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(app.backend.user, isNull);

    await enter(tester, 'account-password', 'long-enough');
    await enter(tester, 'account-password-confirm', 'long-enough');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(app.backend.accounts['ann@example.test'], 'long-enough');
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('ann@example.test'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('reports a taken email address', (tester) async {
    final app = await pumpSettings(tester);
    app.backend.accounts['ann@example.test'] = 'x';
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();
    await enter(tester, 'account-name', 'Ann');
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'long-enough');
    await enter(tester, 'account-password-confirm', 'long-enough');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('An account with this email address already exists.'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('requests a password reset', (tester) async {
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await enter(tester, 'account-email', 'ann@example.test');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.backend.resetRequests, ['ann@example.test']);
    expect(find.textContaining('reset email has been sent'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('signs out after confirmation', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    expect(find.text('Ann'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(
      find.text('Songs and sets on this device are kept.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(app.backend.user, isNull);
    expect(find.text('Not signed in'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('changing the server signs out', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    await tester.tap(find.textContaining(defaultServerUrl));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'http://127.0.0.1:8090/',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.backend.user, isNull);
    expect(app.prefs.getString('serverUrl'), 'http://127.0.0.1:8090');
    expect(find.textContaining('http://127.0.0.1:8090'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('rejects an invalid server address', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    await tester.tap(find.textContaining(defaultServerUrl));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ftp://example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('must start with http'), findsOneWidget);
    expect(app.backend.user, _ann);
    expect(find.textContaining(defaultServerUrl), findsOneWidget);
    await app.dispose(tester);
  });

  test('normalizes server URLs', () {
    expect(
      normalizeServerUrl(' https://api.realchord.app// '),
      'https://api.realchord.app',
    );
    expect(
      normalizeServerUrl('http://localhost:8090'),
      'http://localhost:8090',
    );
    expect(normalizeServerUrl('api.realchord.app'), isNull);
    expect(normalizeServerUrl('https://'), isNull);
  });
}
