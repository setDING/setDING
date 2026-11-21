import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/account/account_section.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/util/log.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'u1', email: 'ann@example.test', name: 'Ann');

void main() {
  Future<TestApp> pumpSettings(WidgetTester tester, {AuthUser? user}) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.account);
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

  testWidgets('the eye button shows and hides the passwords', (tester) async {
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();

    bool obscured(String key) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(obscured('account-password'), isTrue);
    expect(obscured('account-password-confirm'), isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-password-visibility')));
    await tester.pumpAndSettle();
    expect(obscured('account-password'), isFalse);
    expect(obscured('account-password-confirm'), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-password-visibility')));
    await tester.pumpAndSettle();
    expect(obscured('account-password'), isTrue);
    expect(obscured('account-password-confirm'), isTrue);
    await app.dispose(tester);
  });

  testWidgets('shows and logs a network error', (tester) async {
    Log.clear();
    final app = await pumpSettings(tester);
    app.backend.failWith = BackendErrorKind.network;
    await tester.tap(find.byKey(const Key('account-open-sign-in')));
    await tester.pumpAndSettle();
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'pw');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No connection to the server'), findsOneWidget);
    // The cause is not shown, but the diagnostic log keeps it (issue #145).
    expect(Log.export(), contains('[account] Sign-in failed'));
    expect(Log.export(), contains('BackendException(network'));
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

  testWidgets('changes the display name (issue #779)', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    await tester.tap(find.byKey(const Key('account-change-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '  Ann Muster ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(app.backend.user!.name, 'Ann Muster');
    expect(find.text('Ann Muster'), findsOneWidget);
    expect(find.text('Name changed.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('changes the password (issue #779)', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    app.backend.accounts[_ann.email] = 'old-password';
    await tester.tap(find.byKey(const Key('account-change-password')));
    await tester.pumpAndSettle();
    await enter(tester, 'change-password-current', 'old-password');
    await enter(tester, 'change-password-new', 'new-password');
    await enter(tester, 'change-password-confirm', 'new-password');
    await tester.tap(find.byKey(const Key('change-password-save')));
    await tester.pumpAndSettle();

    expect(app.backend.accounts[_ann.email], 'new-password');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Password changed.'), findsOneWidget);
    // Still signed in on this device.
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a wrong current password keeps the old one', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    app.backend.accounts[_ann.email] = 'old-password';
    await tester.tap(find.byKey(const Key('account-change-password')));
    await tester.pumpAndSettle();
    await enter(tester, 'change-password-current', 'wrong-password');
    await enter(tester, 'change-password-new', 'new-password');
    await enter(tester, 'change-password-confirm', 'new-password');
    await tester.tap(find.byKey(const Key('change-password-save')));
    await tester.pumpAndSettle();

    expect(app.backend.accounts[_ann.email], 'old-password');
    expect(find.text('The current password is wrong.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a short or unconfirmed new password is not sent', (
    tester,
  ) async {
    final app = await pumpSettings(tester, user: _ann);
    app.backend.accounts[_ann.email] = 'old-password';
    await tester.tap(find.byKey(const Key('account-change-password')));
    await tester.pumpAndSettle();
    await enter(tester, 'change-password-current', 'old-password');
    await enter(tester, 'change-password-new', 'short');
    await enter(tester, 'change-password-confirm', 'other');
    await tester.tap(find.byKey(const Key('change-password-save')));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(app.backend.accounts[_ann.email], 'old-password');
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
      normalizeServerUrl(' https://api.setding.app// '),
      'https://api.setding.app',
    );
    expect(
      normalizeServerUrl('http://localhost:8090'),
      'http://localhost:8090',
    );
    expect(normalizeServerUrl('api.setding.app'), isNull);
    expect(normalizeServerUrl('https://'), isNull);
  });
}
