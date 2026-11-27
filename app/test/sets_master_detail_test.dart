import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/live/live_play_button.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/sets/sets_tab_providers.dart';

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
    await openTab(tester, HomeTab.sets);
    return app;
  }

  /// The set shown next to the list, or null.
  SetScreen? shown(WidgetTester tester) {
    final screens = tester.widgetList<SetScreen>(find.byType(SetScreen));
    return screens.isEmpty ? null : screens.single;
  }

  String shownName(WidgetTester tester) =>
      (tester.widget<AppBar>(find.byType(AppBar).last).title! as Text).data!;

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

    // The live button is the last action of the app bar (#444).
    final bar = tester.widget<AppBar>(
      find.descendant(
        of: find.byType(SetScreen),
        matching: find.byType(AppBar),
      ),
    );
    expect(bar.actions!.last, isA<LivePlayButton>());
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

  group('collapsed past sets (#282)', () {
    /// Sets "Next gig" (in 3 days) and "Old gig" (10 days ago, with the
    /// song "Encore"); the past sets start collapsed.
    Future<(TestApp, String)> withPastSet(WidgetTester tester) async {
      final app = await TestApp.create(prefs: {'language': 'en'});
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final old = await tester.runAsync(() async {
        final song = await app.songs.createSong(
          source: '{title: Encore}\n[D]Three',
        );
        await app.sets.createSet(
          name: 'Next gig',
          gigDate: today.add(const Duration(days: 3)),
        );
        final old = await app.sets.createSet(
          name: 'Old gig',
          gigDate: today.subtract(const Duration(days: 10)),
        );
        await app.sets.addSongs(old, [song]);
        return old;
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.sets);
      return (app, old!);
    }

    testWidgets('a selected past set stays shown when collapsing', (
      tester,
    ) async {
      useTabletSize(tester);
      final (app, _) = await withPastSet(tester);
      expect(find.text('Old gig'), findsNothing);

      await tester.tap(find.byTooltip('Show past sets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old gig'));
      await tester.pumpAndSettle();
      expect(shownName(tester), 'Old gig');

      await tester.tap(find.byTooltip('Hide past sets'));
      await tester.pumpAndSettle();
      // Only the card in the list is hidden; the set stays next to it.
      expect(find.byKey(const ValueKey('set-section-past')), findsOneWidget);
      expect(shownName(tester), 'Old gig');
      expect(find.text('Encore'), findsOneWidget);
      expect(find.text('Next gig'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('selecting a past set from elsewhere keeps it collapsed', (
      tester,
    ) async {
      useTabletSize(tester);
      final (app, old) = await withPastSet(tester);
      expect(shownName(tester), 'Next gig');

      // As after creating a set with a past date: the set is selected
      // without a tap in the list.
      ProviderScope.containerOf(tester.element(find.byType(SetsScreen)))
          .read(selectedSetProvider.notifier)
          .select(old);
      await tester.pumpAndSettle();
      expect(shownName(tester), 'Old gig');
      expect(find.text('Encore'), findsOneWidget);
      expect(find.byTooltip('Show past sets'), findsOneWidget);
      expect(find.byKey(ValueKey('set-$old')), findsNothing);
      expect(app.prefs.getBool('pastSetsCollapsed'), isNull);
      await app.dispose(tester);
    });

    testWidgets('only past sets: the latest is shown, the list collapsed', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        for (final (name, days) in [('Older gig', 40), ('Last gig', 5)]) {
          await app.sets.createSet(
            name: name,
            gigDate: today.subtract(Duration(days: days)),
          );
        }
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await openTab(tester, HomeTab.sets);

      expect(find.text('Past (2)'), findsOneWidget);
      expect(find.text('Older gig'), findsNothing);
      expect(shownName(tester), 'Last gig');
      await app.dispose(tester);
    });
  });

  // In the real app bar of a set on a phone, the icon of the icon-only live
  // button is onPrimary on primary, also in the dark theme (#450).
  testWidgets('narrow, dark: the live button icon is readable', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'themeMode': 'dark'},
    );
    await tester.runAsync(() async {
      final song = await app.songs.createSong(
        source: '{title: Opener}\n[C]One',
      );
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [song]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openTab(tester, HomeTab.sets);
    await tester.tap(find.text('Gig'));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('play-live'));
    expect(tester.widget(button), isA<IconButton>());
    final scheme = Theme.of(tester.element(button)).colorScheme;
    expect(scheme.brightness, Brightness.dark);
    final background = tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)).first,
        )
        .color;
    final icon = tester.widget<RichText>(
      find.descendant(
        of: find.byIcon(Icons.play_arrow),
        matching: find.byType(RichText),
      ),
    );
    expect(background, scheme.primary);
    expect(icon.text.style?.color, scheme.onPrimary);
    await app.dispose(tester);
  });

  // Regression test for #882: next to the open set's ⋮ menu, the list had a
  // ⋮ menu of its own, which was mistaken for the set's (e.g. to delete it).
  testWidgets('wide: only the open set has a ⋮ menu in its app bar', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await withSets(tester);

    Finder menusIn(Finder appBar) => find.descendant(
      of: appBar,
      matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
    );
    expect(menusIn(find.byType(AppBar).first), findsNothing);
    expect(menusIn(find.byType(AppBar).last), findsOneWidget);
    // Its actions moved: Repertoire into the app bar, the trash to the end
    // of the list (only with deleted sets, #888), importing into the
    // "New set" dialog.
    expect(find.byTooltip('Repertoire'), findsOneWidget);
    expect(find.byKey(const Key('sets-trash')), findsNothing);
    await tester.tap(find.text('New set'));
    await tester.pumpAndSettle();
    expect(find.text('Import from file …'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Editing a set does not offer it.
    await tester.tap(find.byTooltip('Edit set'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('set-dialog-import')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await app.dispose(tester);
  });
}
