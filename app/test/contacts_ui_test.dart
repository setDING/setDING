import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/join_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _leo = AuthUser(id: 'leo', email: 'leo@example.test', name: 'Leo');
const _pia = AuthUser(id: 'pia', email: 'pia@example.test', name: 'Pia');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// People without an account on the organization screen and their personal
/// invitation (ADR-0064, #1100).
void main() {
  /// Organization o1 "School" with band b1 (Ann admin of the organization,
  /// Leo leader, Pia set planner, Bob member) and the contact Guest Drummer
  /// on the server and the device.
  Future<TestApp> start(
    WidgetTester tester,
    AuthUser user, {
    Widget? home,
    bool secondBand = false,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    final backend = app.backend
      ..addBand('b1', 'Rock', admin: _ann, organizationId: 'o1')
      ..addMember('b1', _leo, BandRole.admin)
      ..addMember('b1', _pia, BandRole.planner)
      ..addMember('b1', _bob, BandRole.member);
    backend.organizations['o1'] = 'School';
    if (secondBand) {
      backend.addBand('b2', 'Jazz', admin: _leo, organizationId: 'o1');
    }
    const guest = RemoteContact(
      id: 'c1',
      organizationId: 'o1',
      firstName: 'Guest',
      lastName: 'Drummer',
      email: 'guest@example.test',
    );
    backend.putContact(guest);
    await tester.runAsync(() async {
      await BandService(app.db, backend).refresh();
      await app.db
          .into(app.db.contacts)
          .insert(
            ContactsCompanion.insert(
              id: 'c1',
              organizationId: 'o1',
              firstName: 'Guest',
              lastName: const Value('Drummer'),
              email: const Value('guest@example.test'),
              revision: Value(backend.contacts['c1']!.revision),
              updatedAt: DateTime(2026),
            ),
          );
    });
    await tester.pumpWidget(
      app.build(home: home ?? const OrganizationScreen(organizationId: 'o1')),
    );
    await tester.pumpAndSettle();
    return app;
  }

  Future<ContactEntry?> contact(WidgetTester tester, TestApp app, String id) =>
      tester
          .runAsync(
            () => (app.db.select(
              app.db.contacts,
            )..where((c) => c.id.equals(id))).getSingleOrNull(),
          )
          .then((c) => c);

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String action) async {
    final button = find.byKey(const ValueKey('contact-menu-c1'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('organization admins create, edit and delete people without an '
      'account', (tester) async {
    final app = await start(tester, _ann);
    final tile = find.byKey(const ValueKey('contact-c1'));
    await reveal(tester, tile);
    expect(
      find.descendant(of: tile, matching: find.text('Guest Drummer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('guest@example.test')),
      findsOneWidget,
    );

    await reveal(tester, find.byKey(const Key('contact-new')));
    await tester.tap(find.byKey(const Key('contact-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Hans');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    final created = (await tester.runAsync(
      () => app.db.select(app.db.contacts).get(),
    ))!.where((c) => c.firstName == 'Hans');
    expect(created, hasLength(1));
    expect(find.text('Hans'), findsOneWidget);

    await menu(tester, 'Edit');
    await tester.enterText(find.byKey(const Key('contact-nickname')), 'Drums');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect((await contact(tester, app, 'c1'))!.nickname, 'Drums');

    await menu(tester, 'Delete');
    expect(find.text('Delete Drums?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    final deleted = (await contact(tester, app, 'c1'))!;
    expect(deleted.deleted, isTrue);
    expect(deleted.email, isNull);
    expect(find.byKey(const ValueKey('contact-c1')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('set planners edit people without an account but neither '
      'invite nor delete them', (tester) async {
    final app = await start(tester, _pia);
    final button = find.byKey(const ValueKey('contact-menu-c1'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Invite to setDING'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('members do not see people without an account', (tester) async {
    final app = await start(tester, _bob);
    expect(find.text('People without an account'), findsNothing);
    expect(find.byKey(const Key('contact-new')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('an organization admin sends a personal invitation by mail, '
      'with its QR code', (tester) async {
    final app = await start(tester, _ann);
    await menu(tester, 'Invite to setDING');
    final invite = app.backend.invites.single;
    expect(invite.contactId, 'c1');
    expect(invite.bandId, isNull);
    expect(find.text('Personal invitation for Guest Drummer'), findsOneWidget);
    expect(find.byKey(const Key('invite-qr')), findsOneWidget);
    expect(find.byKey(const Key('invite-mail')), findsOneWidget);
    expect(find.byKey(const Key('invite-share')), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    // Personal invitations are not in the list of links.
    expect(find.text('Invitation links'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a leader of two bands chooses the band of the invitation', (
    tester,
  ) async {
    final app = await start(tester, _leo, secondBand: true);
    await menu(tester, 'Invite to setDING');
    expect(find.text('Invite into which band?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contact-invite-band-b2')));
    await tester.pumpAndSettle();
    final invite = app.backend.invites.single;
    expect(invite.bandId, 'b2');
    expect(invite.contactId, 'c1');
    await app.dispose(tester);
  });

  testWidgets('a personal invitation prefills the sign-up and links the '
      'contact in the lineups', (tester) async {
    final app = await start(tester, _ann);
    app.backend.putSet(
      const RemoteSet(
        id: 's1',
        bandId: 'b1',
        name: 'Gig',
        lineup: ['ann'],
        lineupContacts: ['c1'],
        lineupCustom: true,
      ),
    );
    final link = (await app.backend.createInvite('o1', contactId: 'c1')).url;
    await tester.runAsync(() => app.backend.signOut());
    await tester.pumpWidget(app.build(home: JoinScreen(initialLink: link)));
    await tester.pumpAndSettle();
    expect(find.text('This invitation is for Guest Drummer.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('join-sign-up')));
    await tester.pumpAndSettle();
    String text(String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;
    expect(text('account-first-name'), 'Guest');
    expect(text('account-last-name'), 'Drummer');
    expect(text('account-email'), 'guest@example.test');
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'long-enough',
    );
    await tester.enterText(
      find.byKey(const Key('account-password-confirm')),
      'long-enough',
    );
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.pumpAndSettle();

    final user = app.backend.user!;
    expect(app.backend.sets['s1']!.lineup, ['ann', user.id]);
    expect(app.backend.sets['s1']!.lineupContacts, isEmpty);
    expect(app.backend.contacts['c1']!.linkedUserId, user.id);
    expect(app.backend.contacts['c1']!.deleted, isTrue);
    await app.dispose(tester);
  });

  testWidgets('a member of the organization accepts a personal invitation '
      'for themselves', (tester) async {
    final app = await start(tester, _ann);
    final link = (await app.backend.createInvite('o1', contactId: 'c1')).url;
    app.backend.user = _bob;
    await tester.pumpWidget(app.build(home: JoinScreen(initialLink: link)));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your account takes over the sets Guest Drummer is '
        'planned for.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Accept invitation'));
    await tester.pumpAndSettle();
    expect(app.backend.contacts['c1']!.linkedUserId, 'bob');
    await app.dispose(tester);
  });
}
