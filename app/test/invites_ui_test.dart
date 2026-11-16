import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/ui/bands/join_screen.dart';
import 'package:realchord/ui/bands/organization_screen.dart';
import 'package:realchord/ui/settings_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

void main() {
  test('finds the token in links and pasted text', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz012345';
    expect(inviteTokenFrom('https://api.realchord.app/invite/$token'), token);
    expect(inviteTokenFrom(' realchord://invite/$token '), token);
    expect(inviteTokenFrom(token), token);
    expect(inviteTokenFrom('https://api.realchord.app/invite/short'), isNull);
    expect(inviteTokenFrom('hello world'), isNull);
  });

  Future<TestApp> pump(WidgetTester tester, AuthUser? user, Widget home) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    await tester.pumpWidget(app.build(home: home));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('admins create a link with QR code and can revoke it', (
    tester,
  ) async {
    final app = await pump(
      tester,
      _ann,
      const OrganizationScreen(organizationId: 'o1'),
    );
    await tester.tap(find.byKey(const Key('invite-create')));
    await tester.pumpAndSettle();

    final invite = app.backend.invites.single;
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text('https://api.realchord.app/invite/${invite.token}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation links'), findsOneWidget);
    expect(find.text('Nobody joined yet'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(invite.revoked, isTrue);
    expect(find.text('Revoked'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members cannot invite', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.pumpWidget(
      app.build(home: const OrganizationScreen(organizationId: 'o1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-create')), findsNothing);
    expect(find.textContaining('Ask an admin'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('joins an organization with a pasted link', (tester) async {
    final app = await pump(tester, _bob, const JoinScreen());
    final link = (await _invite(app)).url;

    await tester.enterText(find.byKey(const Key('join-link')), link);
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Join School?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.pumpAndSettle();

    expect(
      app.backend.orgMembers.where((m) => m.user.id == 'bob').single.scopeId,
      'o1',
    );
    expect(find.byKey(const Key('join-button')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('reports invalid, unknown and expired links', (tester) async {
    final app = await pump(tester, _bob, const JoinScreen());
    await tester.enterText(find.byKey(const Key('join-link')), 'nonsense');
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.text('This is not a valid invitation link.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('join-link')),
      'https://api.realchord.app/invite/${'Z' * 32}',
    );
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not exist'), findsOneWidget);

    final invite = await _invite(app);
    app.backend.now = app.backend.now.add(const Duration(days: 8));
    await tester.enterText(find.byKey(const Key('join-link')), invite.url);
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.textContaining('has expired'), findsOneWidget);
    expect(find.byKey(const Key('join-button')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('asks to sign in first and continues afterwards', (tester) async {
    final app = await pump(tester, null, const JoinScreen());
    final link = (await _invite(app)).url;
    await tester.enterText(find.byKey(const Key('join-link')), link);
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in or create an account'), findsOneWidget);

    app.backend.accounts['bob@example.test'] = 'secret-pw';
    await tester.tap(find.byKey(const Key('join-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account-email')),
      'bob@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'secret-pw',
    );
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Join School?'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('signed out: join from the settings and create an account', (
    tester,
  ) async {
    final app = await pump(tester, null, const SettingsScreen());
    final link = (await _invite(app)).url;
    await tester.tap(find.byKey(const Key('account-open-join')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-link')), link);
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('join-sign-up')));
    await tester.pumpAndSettle();
    for (final (key, value) in [
      ('account-name', 'Bob'),
      ('account-email', 'bob@example.test'),
      ('account-password', 'long-enough'),
      ('account-password-confirm', 'long-enough'),
    ]) {
      await tester.enterText(find.byKey(Key(key)), value);
    }
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Join School?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.pumpAndSettle();

    expect(
      app.backend.orgMembers.where((m) => m.user.email == 'bob@example.test'),
      hasLength(1),
    );
    await app.dispose(tester);
  });

  testWidgets('an invitation link opens the join screen', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    final invite = await _invite(app);

    app.links.add(Uri.parse(invite.url));
    await tester.pumpAndSettle();
    expect(find.text('Join School?'), findsOneWidget);
    await app.dispose(tester);
  });
}

/// Creates a link as Ann (organization admin) and switches back.
Future<CreatedInvite> _invite(TestApp app) async {
  final user = app.backend.user;
  app.backend.user = _ann;
  final invite = await app.backend.createInvite('o1');
  app.backend.user = user;
  return invite;
}
