import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/sets/sets_screen.dart';

import 'test_app.dart';

/// The sets tab groups the sets by gig date (#265).
void main() {
  Future<TestApp> withSets(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      for (final (name, days) in [
        ('Old gig', -30),
        ('Next week', 7),
        ('Last night', -1),
        ('Tonight', 0),
        ('Rehearsal', null),
        ('Next month', 30),
      ]) {
        await app.sets.createSet(
          name: name,
          gigDate: days == null ? null : today.add(Duration(days: days)),
        );
      }
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('sections in order, next gig first and highlighted', (
    tester,
  ) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester, prefs: {'pastSetsCollapsed': false});

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final order = [
      'Upcoming',
      'Tonight',
      'Next week',
      'Next month',
      'Without date',
      'Rehearsal',
      'Past (2)',
      'Last night',
      'Old gig',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        top(order[i]),
        greaterThan(top(order[i - 1])),
        reason: '${order[i]} below ${order[i - 1]}',
      );
    }
    // Only the next gig is highlighted, with its day.
    final next = find.byKey(const ValueKey('next-gig'));
    expect(next, findsOneWidget);
    expect(
      find.descendant(of: next, matching: find.text('Tonight')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: next, matching: find.text('Next gig · Today')),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('past sets start collapsed without a stored choice', (
    tester,
  ) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester);

    expect(app.prefs.getBool('pastSetsCollapsed'), isNull);
    expect(find.text('Past (2)'), findsOneWidget);
    expect(find.text('Old gig'), findsNothing);
    expect(find.text('Last night'), findsNothing);
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Rehearsal'), findsOneWidget);
    expect(find.byTooltip('Show past sets'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-section-past')));
    await tester.pumpAndSettle();
    expect(find.text('Old gig'), findsOneWidget);
    expect(find.text('Last night'), findsOneWidget);
    expect(app.prefs.getBool('pastSetsCollapsed'), isFalse);
    await app.dispose(tester);
  });

  testWidgets('past sets collapse, remembered per device', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester, prefs: {'pastSetsCollapsed': false});

    expect(find.text('Old gig'), findsOneWidget);
    expect(find.byTooltip('Hide past sets'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('set-section-past')));
    await tester.pumpAndSettle();
    expect(find.text('Old gig'), findsNothing);
    expect(find.text('Last night'), findsNothing);
    expect(find.text('Past (2)'), findsOneWidget);
    expect(find.byTooltip('Show past sets'), findsOneWidget);
    expect(app.prefs.getBool('pastSetsCollapsed'), isTrue);
    await app.dispose(tester);
  });

  testWidgets('starts with past sets collapsed when stored so', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester, prefs: {'pastSetsCollapsed': true});

    expect(find.text('Old gig'), findsNothing);
    expect(find.text('Tonight'), findsOneWidget);
    await tester.tap(find.byTooltip('Show past sets'));
    await tester.pumpAndSettle();
    expect(find.text('Old gig'), findsOneWidget);
    expect(app.prefs.getBool('pastSetsCollapsed'), isFalse);
    await app.dispose(tester);
  });

  testWidgets('German section headers and next gig label', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester, prefs: {'language': 'de'});

    expect(find.text('Bevorstehend'), findsOneWidget);
    expect(find.text('Ohne Datum'), findsOneWidget);
    expect(find.text('Vergangen (2)'), findsOneWidget);
    expect(find.text('Nächster Auftritt · Heute'), findsOneWidget);
    await app.dispose(tester);
  });

  test('days between calendar days ignore the time and DST', () {
    expect(daysBetween(DateTime(2027, 6, 10, 23), DateTime(2027, 6, 10)), 0);
    expect(daysBetween(DateTime(2027, 6, 10, 23), DateTime(2027, 6, 11)), 1);
    // Across the change to summer time in Switzerland.
    expect(daysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 2);
  });
}
