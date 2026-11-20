import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/join_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

void main() {
  test('finds the token in links and pasted text', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz012345';
    expect(inviteTokenFrom('https://api.setding.app/invite/$token'), token);
    expect(inviteTokenFrom(' setding://invite/$token '), token);
    expect(inviteTokenFrom(token), token);
    expect(inviteTokenFrom('https://api.setding.app/invite/short'), isNull);
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
      find.text('https://api.setding.app/invite/${invite.token}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation links'), findsOneWidget);
    expect(find.textContaining('Nobody joined yet'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(invite.revoked, isTrue);
    // Revoked links are not listed (issue #579).
    expect(find.byKey(Key('invite-${invite.id}')), findsNothing);
    expect(find.text('Invitation links'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('lists valid links with their band and shows them again', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    final backend = app.backend
      ..addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.organizations['o1'] = 'School';
    final orgLink = await backend.createInvite('o1');
    final bandLink = await backend.createInvite('o1', bandId: 'b1');
    final expired = await backend.createInvite('o1');
    backend.invites.firstWhere((i) => i.id == expired.id).expires = backend.now
        .subtract(const Duration(days: 1));
    final old = await backend.createInvite('o1');
    backend.invites.firstWhere((i) => i.id == old.id).stored = false;
    await tester.pumpWidget(
      app.build(home: const OrganizationScreen(organizationId: 'o1')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(Key('invite-${expired.id}')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(Key('invite-${bandLink.id}')),
        matching: find.text('Rock'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('invite-${orgLink.id}')),
        matching: find.text('Organization only'),
      ),
      findsOneWidget,
    );
    // Each link says when it was created, not only until when it is valid
    // (issue #637).
    expect(
      find.descendant(
        of: find.byKey(Key('invite-${orgLink.id}')),
        matching: find.textContaining(
          'Created Sun, Nov 15, valid until Sun, Nov 22',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(Key('invite-show-${bandLink.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(bandLink.url), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('invite-show-${old.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.text('This link cannot be shown again. Create a new one.'),
      findsOneWidget,
    );
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
      'https://api.setding.app/invite/${'Z' * 32}',
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
    await openSettingsCategory(tester, SettingsCategory.account);
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

  testWidgets('a link of a band leader leads into the band (ADR-0023)', (
    tester,
  ) async {
    final app = await pump(tester, _bob, const JoinScreen());
    app.backend.user = _ann;
    final invite = await app.backend.createInvite('o1', bandId: 'b1');
    app.backend.user = _bob;
    await tester.enterText(find.byKey(const Key('join-link')), invite.url);
    await tester.tap(find.byKey(const Key('join-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Join Rock (School)?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.pumpAndSettle();
    expect(
      app.backend.members.where((m) => m.user.id == 'bob').single.scopeId,
      'b1',
    );
    await app.dispose(tester);
  });

  group('invite-only server (ADR-0024)', () {
    testWidgets('accounts only with a link; the token goes along', (
      tester,
    ) async {
      final app = await pump(tester, null, const SettingsScreen());
      await openSettingsCategory(tester, SettingsCategory.account);
      app.backend.config = const ServerConfig(
        registration: RegistrationMode.inviteOnly,
      );
      final link = (await _invite(app)).url;

      // Signing in directly offers no sign-up, only joining with a link.
      await tester.tap(find.byKey(const Key('account-open-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-toggle')), findsNothing);
      expect(find.byKey(const Key('account-invite-only')), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-open-join')));
      await tester.pumpAndSettle();

      // The link is checked before signing up.
      await tester.enterText(find.byKey(const Key('join-link')), link);
      await tester.tap(find.byKey(const Key('join-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Join School?'), findsOneWidget);
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
      expect(app.backend.signUpInvites, [inviteTokenFrom(link)]);

      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pumpAndSettle();
      expect(
        app.backend.orgMembers.where((m) => m.user.email == 'bob@example.test'),
        hasLength(1),
      );
      await app.dispose(tester);
    });

    testWidgets('a founder invitation founds the organization', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      final link = app.backend.addFounderInvite('Choir');

      app.links.add(Uri.parse(link));
      await tester.pumpAndSettle();
      expect(find.text('Found Choir?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pumpAndSettle();

      final orgId = app.backend.organizations.entries
          .singleWhere((e) => e.value == 'Choir')
          .key;
      final founder = app.backend.orgMembers.singleWhere(
        (m) => m.scopeId == orgId,
      );
      expect(founder.user.id, 'bob');
      expect(founder.role, OrgRole.admin);

      // Used up.
      app.links.add(Uri.parse(link));
      await tester.pumpAndSettle();
      expect(find.textContaining('was used already'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('asks to confirm the email address after signing up', (
      tester,
    ) async {
      final app = await pump(tester, null, const SettingsScreen());
      await openSettingsCategory(tester, SettingsCategory.account);
      app.backend.config = const ServerConfig(emailVerification: true);
      await tester.tap(find.byKey(const Key('account-open-sign-in')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-toggle')));
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
      expect(find.byKey(const Key('account-verify')), findsOneWidget);
      expect(find.textContaining('bob@example.test'), findsWidgets);

      await tester.tap(find.byKey(const Key('account-verify-resend')));
      await tester.pumpAndSettle();
      expect(app.backend.verificationRequests, ['bob@example.test']);
      expect(find.text('Mail sent.'), findsOneWidget);

      // Confirmed: signing in works.
      app.backend.unverified.clear();
      await tester.tap(find.byKey(const Key('account-submit')));
      await tester.pumpAndSettle();
      expect(app.backend.user?.email, 'bob@example.test');
      await app.dispose(tester);
    });
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
