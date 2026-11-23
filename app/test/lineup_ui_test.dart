import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/lineup.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/sets/set_screen.dart';

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
      final sets = SetRepository(app.db, app.storage, bandId: 'b1');
      final id = await sets.createSet(name: 'Gig');
      if (lineup != null) await sets.setLineup(id, lineup);
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
      lineupCustom: lineup != null,
    );
    MembershipEntry member(String id, String name) => MembershipEntry(
      id: 'm-$id',
      bandId: 'b1',
      userId: id,
      userName: name,
      role: BandRole.member,
      revision: 0,
    );
    OrgMembershipEntry org(String id, String name) => OrgMembershipEntry(
      id: 'o-$id',
      organizationId: 'o1',
      userId: id,
      userName: name,
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
