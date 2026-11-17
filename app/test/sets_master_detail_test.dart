import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/sets/set_screen.dart';
import 'package:realchord/ui/sets/sets_screen.dart';

import 'test_app.dart';

/// Wide screens show the list of sets and the selected set side by side
/// (#266); narrow screens open a set as its own page.
void main() {
  /// Sets "Next gig" (in 3 days, one song), "Later gig" (in 20 days, one
  /// song) and "Undated" (empty).
  Future<TestApp> withSets(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: '{title: Opener}\n[C]One');
      final b = await app.songs.createSong(source: '{title: Ballad}\n[G]Two');
      final next = await app.sets.createSet(
        name: 'Next gig',
        gigDate: today.add(const Duration(days: 3)),
      );
      await app.sets.addSongs(next, [a]);
      final later = await app.sets.createSet(
        name: 'Later gig',
        gigDate: today.add(const Duration(days: 20)),
      );
      await app.sets.addSongs(later, [b]);
      await app.sets.createSet(name: 'Undated');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  /// The set shown next to the list, or null.
  SetScreen? shown(WidgetTester tester) {
    final screens = tester.widgetList<SetScreen>(find.byType(SetScreen));
    return screens.isEmpty ? null : screens.single;
  }

  String shownName(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(AppBar).last,
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('wide: the next gig is shown next to the list', (tester) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    expect(shown(tester)?.embedded, isTrue);
    expect(shownName(tester), 'Next gig');
    expect(find.text('Opener'), findsOneWidget);
    // Side by side, without a back button.
    expect(
      tester.getCenter(find.byType(SetScreen)).dx,
      greaterThan(tester.getCenter(find.text('Undated')).dx),
    );
    expect(find.byType(BackButton), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('set-${shown(tester)!.setId}')))
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Later gig'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'Later gig');
    expect(find.text('Ballad'), findsOneWidget);
    expect(find.text('Opener'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    // The list stays.
    expect(find.text('Undated'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('narrow: a set opens as its own page', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await withSets(tester);

    expect(shown(tester), isNull);
    await tester.tap(find.text('Later gig'));
    await tester.pumpAndSettle();
    expect(shown(tester)?.embedded, isFalse);
    expect(find.text('Ballad'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Undated'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(shown(tester), isNull);
    expect(find.text('Undated'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the selection survives rotating the tablet', (tester) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    await tester.tap(find.text('Later gig'));
    await tester.pumpAndSettle();
    expect(shownName(tester), 'Later gig');

    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();
    expect(shown(tester), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(shownName(tester), 'Later gig');
    await app.dispose(tester);
  });

  testWidgets('wide: live mode still opens full screen', (tester) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    await tester.tap(find.byTooltip('Play live'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveScreen), findsOneWidget);
    expect(tester.getSize(find.byType(LiveScreen)), const Size(1280, 800));
    expect(find.byType(SetsScreen), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('wide: deleting the shown set shows the next one', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(SetScreen),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Still on the sets tab, now with the following gig.
    expect(find.byType(SetsScreen), findsOneWidget);
    expect(find.text('Next gig'), findsNothing);
    expect(shownName(tester), 'Later gig');
    await app.dispose(tester);
  });

  testWidgets('wide: a new set is selected next to the list', (tester) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    await tester.tap(find.text('New set'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fresh');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(shownName(tester), 'Fresh');
    expect(find.byType(BackButton), findsNothing);
    await app.dispose(tester);
  });
}
