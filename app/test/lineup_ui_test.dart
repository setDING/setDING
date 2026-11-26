import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/contact_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/lineup.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/sets/lineup_view.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/l10n/generated/app_localizations_en.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');
const _cleo = AuthUser(id: 'cleo', email: 'cleo@example.test', name: 'Cleo');

/// Choosing a set's lineup and seeing it (ADR-0061, #1009).
void main() {
  /// Band b1 of organization o1 with Ann (leader) and Bob (member); Cleo is
  /// in the organization only. Signed in as [user]; one set "Gig".
  Future<(TestApp, String)> start(
    WidgetTester tester, {
    required AuthUser user,
    List<String>? lineup,
    List<String> contacts = const [],
    bool withContacts = false,
    bool openSet = true,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: user,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    app.backend.addOrgMember('o1', _cleo, OrgRole.member);
    final id = (await tester.runAsync(() async {
      await BandService(app.db, app.backend).refresh();
      if (withContacts) {
        // Guest Drummer and Zoe, people without an account (ADR-0064).
        for (final (id, first, last) in [
          ('c1', 'Guest', 'Drummer'),
          ('c2', 'Zoe', ''),
        ]) {
          await app.db
              .into(app.db.contacts)
              .insert(
                ContactsCompanion.insert(
                  id: id,
                  organizationId: 'o1',
                  firstName: first,
                  lastName: Value(last),
                  revision: const Value(1),
                  updatedAt: DateTime(2026),
                ),
              );
        }
      }
      final sets = SetRepository(app.db, app.storage, bandId: 'b1');
      final id = await sets.createSet(name: 'Gig');
      if (lineup != null) {
        await sets.setLineup(id, lineup, contacts: contacts);
      }
      return id;
    }))!;
    await tester.pumpWidget(
      app.build(home: openSet ? SetScreen(setId: id) : null),
    );
    await tester.pumpAndSettle();
    return (app, id);
  }

  Future<SetlistEntry> stored(
    WidgetTester tester,
    TestApp app,
    String id,
  ) async => (await tester.runAsync(
    () => (app.db.select(
      app.db.setlists,
    )..where((s) => s.id.equals(id))).getSingle(),
  ))!;

  testWidgets('a leader chooses band members and a substitute, then the '
      'whole band again', (tester) async {
    final (app, id) = await start(tester, user: _ann);
    final row = find.byKey(const Key('set-lineup'));
    expect(
      find.descendant(of: row, matching: find.text('Lineup · Whole band')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Ann, Bob')),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Band members'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lineup-bob')));
    await tester.tap(find.byKey(const Key('lineup-add-people')));
    await tester.pumpAndSettle();
    // Only people of the organization outside the band and the lineup.
    expect(find.byKey(const ValueKey('lineup-pick-ann')), findsNothing);
    expect(find.byKey(const ValueKey('lineup-pick-bob')), findsNothing);
    await tester.enterText(find.byKey(const Key('lineup-search')), 'cl');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lineup-pick-cleo')));
    await tester.pumpAndSettle();
    expect(find.text('Substitutes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lineup-save')));
    await tester.pumpAndSettle();

    var set = await stored(tester, app, id);
    expect(set.lineupCustom, isTrue);
    expect(set.lineup, ['ann', 'cleo']);
    expect(
      find.descendant(of: row, matching: find.text('Ann, Cleo (Substitute)')),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-whole-band')));
    await tester.pumpAndSettle();
    set = await stored(tester, app, id);
    expect(set.lineupCustom, isFalse);
    expect(set.lineup, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('checking the whole band again goes back to the whole band', (
    tester,
  ) async {
    final (app, id) = await start(tester, user: _ann, lineup: ['ann']);
    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lineup-bob')));
    await tester.tap(find.byKey(const Key('lineup-save')));
    await tester.pumpAndSettle();
    expect((await stored(tester, app, id)).lineupCustom, isFalse);
    await app.dispose(tester);
  });

  // Regression (#1098): the dialog does not show people without an account
  // yet (#1099); saving it must keep them, and *Whole band* drop them.
  testWidgets('saving the lineup keeps its people without an account', (
    tester,
  ) async {
    final (app, id) = await start(
      tester,
      user: _ann,
      lineup: ['ann', 'bob'],
      contacts: ['c1'],
    );
    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-save')));
    await tester.pumpAndSettle();
    var set = await stored(tester, app, id);
    expect(set.lineupCustom, isTrue);
    expect(set.lineup, ['ann', 'bob']);
    expect(set.lineupContacts, ['c1']);

    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-whole-band')));
    await tester.pumpAndSettle();
    set = await stored(tester, app, id);
    expect(set.lineupCustom, isFalse);
    expect(set.lineupContacts, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('a leader adds a person without an account from the '
      'organization and creates a new one (ADR-0064)', (tester) async {
    final (app, id) = await start(tester, user: _ann, withContacts: true);
    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-add-people')));
    await tester.pumpAndSettle();
    // People of the organization and contacts, contacts marked.
    expect(find.byKey(const ValueKey('lineup-pick-cleo')), findsOneWidget);
    final guest = find.byKey(const ValueKey('lineup-pick-contact-c1'));
    expect(
      find.descendant(of: guest, matching: find.text('No account')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('lineup-search')), 'drum');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lineup-pick-cleo')), findsNothing);
    expect(find.byKey(const ValueKey('lineup-pick-contact-c2')), findsNothing);
    await tester.tap(guest);
    await tester.pumpAndSettle();
    expect(find.text('People without an account'), findsOneWidget);

    // A new person: the first name is required, the mail address checked.
    await tester.tap(find.byKey(const Key('lineup-add-people')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-new-contact')));
    await tester.pumpAndSettle();
    expect(find.text('New person without an account'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-email')), 'nope');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.text('Required.'), findsOneWidget);
    expect(find.text('The email address is not valid.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Hans');
    await tester.enterText(
      find.byKey(const Key('contact-email')),
      'hans@example.test',
    );
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-save')));
    await tester.pumpAndSettle();

    final set = await stored(tester, app, id);
    expect(set.lineupCustom, isTrue);
    expect(set.lineup, ['ann', 'bob']);
    expect(set.lineupContacts, hasLength(2));
    expect(set.lineupContacts.first, 'c1');
    final hans = (await tester.runAsync(
      () => (app.db.select(
        app.db.contacts,
      )..where((c) => c.id.equals(set.lineupContacts.last))).getSingle(),
    ))!;
    expect(hans.firstName, 'Hans');
    expect(hans.email, 'hans@example.test');
    expect(hans.revision, 0); // pushed with the next sync
    expect(
      find.descendant(
        of: find.byKey(const Key('set-lineup')),
        matching: find.text(
          'Ann, Bob, Guest Drummer (No account), Hans (No account)',
        ),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('unchecking a person without an account takes them out; a '
      'deleted one keeps the name but is not offered', (tester) async {
    final (app, id) = await start(
      tester,
      user: _ann,
      lineup: ['ann'],
      contacts: ['c1', 'c2'],
      withContacts: true,
    );
    await tester.runAsync(() => ContactRepository(app.db).deleteContact('c2'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('set-lineup')),
        matching: find.text(
          'Ann, Guest Drummer (No account), Zoe (No account)',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lineup-contact-c1')));
    await tester.tap(find.byKey(const Key('lineup-add-people')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lineup-pick-contact-c2')), findsNothing);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lineup-save')));
    await tester.pumpAndSettle();
    expect((await stored(tester, app, id)).lineupContacts, ['c2']);
    await app.dispose(tester);
  });

  test('the printed set list does not mark people without an account', () {
    final l10n = AppLocalizationsEn();
    const lineup = SetLineup(
      people: [LineupPerson(userId: 'cleo', name: 'Cleo', substitute: true)],
      contacts: [LineupContact(contactId: 'c1', name: 'Guest')],
      custom: true,
      plannedForMe: true,
    );
    expect(lineupNames(l10n, lineup), 'Cleo (Substitute), Guest (No account)');
    expect(
      lineupNames(l10n, lineup, markContacts: false),
      'Cleo (Substitute), Guest',
    );
    expect(
      lineupNames(
        l10n,
        const SetLineup(people: [], custom: true, plannedForMe: false),
      ),
      'Nobody planned',
    );
  });

  testWidgets('a member sees the lineup and that they are not planned, '
      'without choosing it', (tester) async {
    final (app, _) = await start(tester, user: _bob, lineup: ['ann']);
    expect(find.byKey(const Key('set-not-planned')), findsOneWidget);
    expect(find.text('Not planned for you'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set-lineup')));
    await tester.pumpAndSettle();
    expect(find.text('Band members'), findsNothing);
    expect(find.byKey(const Key('edit-set')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the set card shows a lineup of its own and not planned', (
    tester,
  ) async {
    final (app, _) = await start(
      tester,
      user: _bob,
      lineup: ['ann', 'cleo'],
      openSet: false,
    );
    await openTab(tester, HomeTab.sets);
    final card = find.byKey(const ValueKey('set-card-lineup'));
    expect(tester.widget<Text>(card).data, 'Lineup: Ann, Cleo (Substitute)');
    expect(find.byKey(const ValueKey('set-card-not-planned')), findsWidgets);
    await app.dispose(tester);
  });

  test('resolveLineup: band members first, unknown people left out', () {
    SetlistEntry set({List<String>? lineup}) => SetlistEntry(
      id: 's',
      bandId: 'b1',
      name: 'Gig',
      revision: 0,
      updatedAt: DateTime(2026),
      deleted: false,
      purged: false,
      lineup: lineup ?? const [],
      lineupContacts: const [],
      lineupCustom: lineup != null,
    );
    MembershipEntry member(String id, String name) => MembershipEntry(
      id: 'm-$id',
      bandId: 'b1',
      userId: id,
      userName: name,
      userFirstName: '',
      userLastName: '',
      userNickname: '',
      role: BandRole.member,
      revision: 0,
    );
    OrgMembershipEntry org(String id, String name) => OrgMembershipEntry(
      id: 'o-$id',
      organizationId: 'o1',
      userId: id,
      userName: name,
      userFirstName: '',
      userLastName: '',
      userNickname: '',
      role: OrgRole.member,
      revision: 0,
    );
    final members = [member('bob', 'Bob'), member('ann', 'Ann')];
    final orgs = [org('cleo', 'Cleo'), org('ann', 'Ann'), org('bob', 'Bob')];

    final whole = resolveLineup(
      set(),
      members: members,
      orgMembers: orgs,
      userId: 'bob',
    );
    expect(whole.userIds, ['ann', 'bob']);
    expect(whole.plannedForMe, isTrue);

    final custom = resolveLineup(
      set(lineup: ['cleo', 'gone', 'bob']),
      members: members,
      orgMembers: orgs,
      userId: 'ann',
    );
    expect(custom.userIds, ['bob', 'cleo']);
    expect(custom.people.last.substitute, isTrue);
    expect(custom.plannedForMe, isFalse);

    // An organization admin outside the band does not play a whole-band set.
    expect(
      resolveLineup(
        set(),
        members: members,
        orgMembers: orgs,
        userId: 'cleo',
      ).plannedForMe,
      isFalse,
    );
  });
}
