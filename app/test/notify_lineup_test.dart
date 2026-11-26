import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/lineup.dart';
import 'package:setding/l10n/generated/app_localizations_en.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:setding/ui/sets/notify_lineup.dart';
import 'package:setding/ui/sets/set_list.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');
const _cleo = AuthUser(id: 'cleo', email: 'cleo@example.test', name: 'Cleo');

/// Notifying the lineup, the lineup on the set list and *You are planned*
/// (ADR-0061, #1011).
void main() {
  final l10n = AppLocalizationsEn();

  SetlistEntry entry({DateTime? gig, String? venue}) => SetlistEntry(
    id: 's',
    bandId: 'b1',
    name: 'Spring Gig',
    gigDate: gig,
    venue: venue,
    revision: 0,
    updatedAt: DateTime(2026),
    deleted: false,
    purged: false,
    lineup: const ['ann', 'cleo'],
    lineupContacts: const [],
    lineupCustom: true,
  );
  const lineup = SetLineup(
    people: [
      LineupPerson(userId: 'ann', name: 'Ann', substitute: false),
      LineupPerson(userId: 'cleo', name: 'Cleo', substitute: true),
    ],
    custom: true,
    plannedForMe: true,
  );

  test('the message names the set, date, venue and lineup', () {
    final m = lineupMessage(
      l10n,
      entry(gig: DateTime(2027, 6, 21), venue: 'Bern'),
      lineup,
      formatDate: (d) => '${d.day}.${d.month}.${d.year}',
    );
    expect(m.subject, 'Lineup: Spring Gig');
    expect(
      m.body,
      'You are planned for “Spring Gig”.\n'
      '21.6.2027 · Bern\n'
      'Lineup: Ann, Cleo (Substitute)\n'
      '\n'
      'You find the songs in setDING.',
    );
    // Without date and venue, no empty line for them.
    expect(
      lineupMessage(l10n, entry(), lineup, formatDate: (_) => '').body,
      startsWith('You are planned for “Spring Gig”.\nLineup: '),
    );
  });

  test('the mail link keeps spaces and line breaks', () {
    final uri = lineupMailUri(
      ['ann@example.test', 'cleo@example.test'],
      'Lineup: Gig',
      'a b\nc',
    );
    expect(
      uri.toString(),
      'mailto:ann%40example.test,cleo%40example.test'
      '?subject=Lineup%3A%20Gig&body=a%20b%0Ac',
    );
  });

  test('the set list carries the lineup line', () {
    final list = buildSetList(
      entry(),
      const [],
      notation: cp.ChordNotation.international,
      formatDate: (_) => '',
      untitled: 'Untitled',
      songMissing: 'Missing',
      markerName: (_) => '',
      lineup: 'Lineup: Ann, Cleo',
    );
    expect(list.lineup, 'Lineup: Ann, Cleo');
  });

  /// Band b1 led by Ann with Bob; Cleo in the organization. A set "Gig" in
  /// three days with the lineup [lineupIds], synced to the device of [user].
  Future<TestApp> start(
    WidgetTester tester, {
    required AuthUser user,
    List<String> lineupIds = const ['ann', 'cleo'],
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
    final now = DateTime.now();
    app.backend.putSet(
      RemoteSet(
        id: 'gig',
        bandId: 'b1',
        name: 'Gig',
        gigDate: DateTime(now.year, now.month, now.day + 3),
        lineup: lineupIds,
        lineupCustom: true,
      ),
      by: 'ann',
    );
    await tester.runAsync(
      () => SyncEngine(
        app.db,
        app.backend,
        BandService(app.db, app.backend),
      ).sync(),
    );
    await tester.pumpWidget(
      app.build(home: openSet ? const SetScreen(setId: 'gig') : null),
    );
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> openNotify(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-notify-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('a leader copies the message for the lineup', (tester) async {
    final app = await start(tester, user: _ann);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await openNotify(tester);
    expect(
      find.textContaining('Lineup: Ann, Cleo (Substitute)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lineup-no-addresses')), findsNothing);
    await tester.tap(find.byKey(const Key('lineup-copy')));
    await tester.pumpAndSettle();
    expect(copied, contains('You are planned for “Gig”.'));
    expect(find.text('Text copied'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('without the server the mail has no recipients', (tester) async {
    final app = await start(tester, user: _ann);
    app.backend.lineupEmailsFail = true;
    await openNotify(tester);
    expect(find.byKey(const Key('lineup-no-addresses')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members cannot notify the lineup', (tester) async {
    final app = await start(tester, user: _bob);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('set-notify-menu')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the overview tells a person planned by name once', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _bob,
      lineupIds: const ['ann', 'bob'],
      openSet: false,
    );
    expect(find.byKey(const Key('overview-planned')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-planned-gig')), findsOneWidget);
    await tester.tap(find.byKey(const Key('overview-planned-seen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview-planned')), findsNothing);
    expect(app.prefs.getStringList('lineupPlannedSeen'), ['gig']);
    await app.dispose(tester);
  });

  testWidgets('no hint for a set without the person', (tester) async {
    final app = await start(tester, user: _bob, openSet: false);
    expect(find.byKey(const Key('overview-planned')), findsNothing);
    await app.dispose(tester);
  });
}
