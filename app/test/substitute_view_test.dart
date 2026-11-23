import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _leo = AuthUser(id: 'leo', email: 'leo@example.test', name: 'Leo');

/// What a substitute sees of a band (ADR-0061, #1010).
void main() {
  /// Ann leads band "Jazz" (b2) and helps out in "Rock" (b1, led by Leo)
  /// for the set "Gig" in three days; Rock's set "Other" is not hers.
  Future<TestApp> start(
    WidgetTester tester, {
    String currentBand = 'b1',
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': currentBand},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _leo, organizationId: 'o1');
    app.backend.addBand('b2', 'Jazz', admin: _ann, organizationId: 'o1');
    final now = DateTime.now();
    final gig = DateTime(now.year, now.month, now.day + 3);
    app.backend.putSet(
      RemoteSet(
        id: 'gig',
        bandId: 'b1',
        name: 'Gig',
        gigDate: gig,
        lineup: const ['leo', 'ann'],
        lineupCustom: true,
      ),
      by: 'leo',
    );
    app.backend.putSet(
      RemoteSet(id: 'other', bandId: 'b1', name: 'Other', gigDate: gig),
      by: 'leo',
    );
    await tester.runAsync(() async {
      final bands = BandService(app.db, app.backend);
      await SyncEngine(app.db, app.backend, bands).sync();
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('the band is marked as substitute and shows only their set, '
      'read-only', (tester) async {
    final app = await start(tester);
    await openTab(tester, HomeTab.sets);
    expect(find.text('Gig'), findsWidgets);
    expect(find.text('Other'), findsNothing);
    expect(find.byKey(const Key('sets-repertoire')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('edit-set')), findsNothing);
    expect(find.byType(SetScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-switcher')).first);
    await tester.pumpAndSettle();
    final rock = find.ancestor(
      of: find.text('Rock'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: rock, matching: find.text('Substitute')),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the band screen says why, without members', (tester) async {
    final app = await start(tester);
    await tester.pumpWidget(app.build(home: const BandScreen(bandId: 'b1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('band-substitute-hint')), findsOneWidget);
    expect(find.text('Members'), findsNothing);
    expect(find.byKey(const Key('band-leave')), findsNothing);
    expect(find.byKey(const Key('band-add-member')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the overview of another band lists the gig as a substitute '
      'and opens it in its band', (tester) async {
    final app = await start(tester, currentBand: 'b2');
    final card = find.byKey(const Key('overview-substitute-gigs'));
    expect(card, findsOneWidget);
    expect(find.text('As a substitute'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-substitute-gig')));
    await tester.pumpAndSettle();
    expect(app.prefs.getString('currentBandId'), 'b1');
    expect(find.byType(SetScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the overview of the substitute band shows no such card', (
    tester,
  ) async {
    final app = await start(tester);
    expect(find.byKey(const Key('overview-substitute-gigs')), findsNothing);
    await app.dispose(tester);
  });
}
