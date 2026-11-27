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

    await enter(tester, 'account-first-name', 'Ann');
    await enter(tester, 'account-email', 'ann@example.test');
    await enter(tester, 'account-password', 'short');
    await enter(tester, 'account-password-confirm', 'other');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(find.text('The passwords do not match.'), findsOneWidget);
    // The last name is required, the nickname is not (ADR-0062).
    expect(find.text('Required.'), findsOneWidget);
    expect(app.backend.user, isNull);

    await enter(tester, 'account-last-name', 'Muster');
    await enter(tester, 'account-password', 'long-enough');
    await enter(tester, 'account-password-confirm', 'long-enough');
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(app.backend.accounts['ann@example.test'], 'long-enough');
    expect(app.backend.user!.person.complete, isTrue);
    expect(find.text('Ann Muster'), findsOneWidget);
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
    await enter(tester, 'account-first-name', 'Ann');
    await enter(tester, 'account-last-name', 'Muster');
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
    await enter(tester, 'account-first-name', '  Ann ');
    await enter(tester, 'account-last-name', '');
    await tester.tap(find.byKey(const Key('account-name-save')));
    await tester.pumpAndSettle();
    // First and last name are required (ADR-0062).
    expect(find.text('Required.'), findsOneWidget);
    expect(app.backend.user!.lastName, isNull);

    await enter(tester, 'account-last-name', 'Muster ');
    await enter(tester, 'account-nickname', 'Annie');
    await tester.tap(find.byKey(const Key('account-name-save')));
    await tester.pumpAndSettle();

    expect(app.backend.user!.name, 'Annie');
    expect(
      [app.backend.user!.firstName, app.backend.user!.lastName],
      ['Ann', 'Muster'],
    );
    expect(find.text('Annie'), findsOneWidget);
    // The full name under the change-name tile.
    expect(find.text('Ann Muster (Annie)'), findsOneWidget);
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

  group('deleting the account (ADR-0052)', () {
    const bob = AuthUser(id: 'u2', email: 'bob@example.test', name: 'Bob');

    /// Ann in an organization: its only admin, or a member next to Bob.
    Future<TestApp> pumpWithOrg(
      WidgetTester tester, {
      required bool soleAdmin,
    }) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
      app.backend.accounts[_ann.email] = 'secret-pw';
      app.backend.addOrganization(
        'o1',
        'Music School',
        admin: soleAdmin ? _ann : bob,
      );
      if (!soleAdmin) app.backend.addOrgMember('o1', _ann, OrgRole.member);
      await tester.pumpWidget(app.build(home: const SettingsScreen()));
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.account);
      expect(await app.db.select(app.db.organizations).get(), isNotEmpty);
      return app;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('account-delete')));
      expect(
        find.descendant(
          of: find.byKey(const Key('danger-zone')),
          matching: find.byKey(const Key('account-delete')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();
    }

    testWidgets('deletes the account and its data on this device', (
      tester,
    ) async {
      final app = await pumpWithOrg(tester, soleAdmin: false);
      await openDialog(tester);
      final confirm = find.byKey(const Key('delete-account-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await enter(tester, 'delete-account-password', 'secret-pw');
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(app.backend.user, isNull);
      expect(app.backend.accounts, isNot(contains(_ann.email)));
      expect(find.text('Your account was deleted.'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
      expect(await app.db.select(app.db.organizations).get(), isEmpty);
      expect(await app.db.select(app.db.orgMemberships).get(), isEmpty);
      expect(
        await (app.db.select(
          app.db.userSettings,
        )..where((s) => s.ownerId.equals(_ann.id))).get(),
        isEmpty,
      );
      await app.dispose(tester);
    });

    testWidgets('a wrong password keeps the account', (tester) async {
      final app = await pumpWithOrg(tester, soleAdmin: false);
      await openDialog(tester);
      await enter(tester, 'delete-account-password', 'wrong-pw');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(app.backend.user, isNotNull);
      expect(find.text('The current password is wrong.'), findsOneWidget);
      expect(await app.db.select(app.db.organizations).get(), isNotEmpty);
      await app.dispose(tester);
    });

    testWidgets('the only admin of an organization is asked to hand it over', (
      tester,
    ) async {
      final app = await pumpWithOrg(tester, soleAdmin: true);
      await openDialog(tester);

      expect(find.textContaining('only admin'), findsOneWidget);
      expect(find.text('• Music School'), findsOneWidget);
      expect(find.byKey(const Key('delete-account-confirm')), findsNothing);
      expect(find.byKey(const Key('delete-account-password')), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(app.backend.user, isNotNull);
      await app.dispose(tester);
    });

    testWidgets('shows the server\'s refusal for the only admin', (
      tester,
    ) async {
      final app = await pumpWithOrg(tester, soleAdmin: false);
      // The server knows more than this device (e.g. a role changed).
      app.backend.soleAdminOrgs.add('o2');
      await openDialog(tester);
      await enter(tester, 'delete-account-password', 'secret-pw');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(app.backend.user, isNotNull);
      expect(find.byKey(const Key('delete-account-error')), findsOneWidget);
      await app.dispose(tester);
    });
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

  // Issue #1199: plain http to a public server asks first.
  Future<void> enterServer(WidgetTester tester, String url) async {
    await tester.tap(find.textContaining(defaultServerUrl));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, url);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('warns before plain http to a public server, cancel keeps it', (
    tester,
  ) async {
    final app = await pumpSettings(tester, user: _ann);
    await enterServer(tester, 'http://chords.example.com');
    expect(find.text('Unencrypted connection?'), findsOneWidget);
    expect(
      find.textContaining('chords.example.com is not a local server'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.backend.user, _ann);
    expect(app.prefs.getString('serverUrl'), isNull);
    expect(find.textContaining(defaultServerUrl), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('saves plain http to a public server after confirmation', (
    tester,
  ) async {
    final app = await pumpSettings(tester, user: _ann);
    await enterServer(tester, 'http://chords.example.com/');
    await tester.tap(find.text('Use anyway'));
    await tester.pumpAndSettle();
    expect(app.backend.user, isNull);
    expect(app.prefs.getString('serverUrl'), 'http://chords.example.com');
    await app.dispose(tester);
  });

  testWidgets('does not warn for https or a LAN server', (tester) async {
    final app = await pumpSettings(tester, user: _ann);
    await enterServer(tester, 'http://192.168.1.20:8090');
    expect(find.text('Unencrypted connection?'), findsNothing);
    expect(app.prefs.getString('serverUrl'), 'http://192.168.1.20:8090');
    await tester.tap(find.textContaining('http://192.168.1.20:8090'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'https://chords.example.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unencrypted connection?'), findsNothing);
    expect(app.prefs.getString('serverUrl'), 'https://chords.example.com');
    await app.dispose(tester);
  });

  test('plain http is local only for loopback, LAN and local names', () {
    for (final host in [
      'localhost',
      'LOCALHOST',
      'api.localhost',
      'band.local',
      'setding.test',
      'setding.test.',
      '127.0.0.1',
      '127.8.9.10',
      '10.0.0.1',
      '10.255.255.255',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.0.10',
      '169.254.1.1',
      '[::1]',
      '::1',
      'fe80::1',
      'fe80::1%eth0',
      'febf::1',
      'fc00::1',
      'fd12:3456::1',
      '::ffff:192.168.1.2',
    ]) {
      expect(isLocalHost(host), isTrue, reason: host);
    }
    for (final host in [
      'api.setding.app',
      'example.com',
      'local',
      'mylocal',
      'test.example.com',
      'localhost.example.com',
      '8.8.8.8',
      '11.0.0.1',
      '172.15.0.1',
      '172.32.0.1',
      '192.169.0.1',
      '169.253.1.1',
      '128.0.0.1',
      '2001:db8::1',
      'fec0::1',
      '::ffff:8.8.8.8',
      '::',
      '',
    ]) {
      expect(isLocalHost(host), isFalse, reason: host);
    }
  });

  test('finds the host of an insecure server URL', () {
    expect(
      insecureServerHost('http://chords.example.com:8090'),
      'chords.example.com',
    );
    expect(insecureServerHost('https://chords.example.com'), isNull);
    expect(insecureServerHost('http://localhost:8090'), isNull);
    expect(insecureServerHost('http://[fd00::5]:8090'), isNull);
    expect(insecureServerHost('http://[2001:db8::1]:8090'), '2001:db8::1');
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
