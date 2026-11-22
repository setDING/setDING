import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/home_tab.dart';

import 'test_app.dart';

/// The main navigation on tablets and desktops (#937): the content tabs at
/// the top, *Settings* pinned to the bottom of the rail.
void main() {
  final rail = find.byKey(const Key('nav-rail'));
  final bottom = find.byKey(const Key('nav-rail-bottom'));

  Future<TestApp> pumpApp(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  HomeTab currentTab(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(rail)).read(homeTabProvider);

  int? selected(WidgetTester tester, Finder finder) =>
      tester.widget<NavigationRail>(finder).selectedIndex;

  testWidgets('settings sit at the bottom, apart from the content tabs', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await pumpApp(tester);

    final top = tester.widget<NavigationRail>(rail);
    expect(top.trailingAtBottom, isTrue);
    expect(top.destinations, hasLength(3));
    expect(
      find.descendant(
        of: bottom,
        matching: find.byKey(const Key('nav-settings')),
      ),
      findsOneWidget,
    );

    final songs = tester.getBottomLeft(find.byKey(const Key('nav-songs'))).dy;
    final settings = tester.getTopLeft(find.byKey(const Key('nav-settings')));
    final screen = tester.view.physicalSize.height;
    // In the lower part of the screen, far below the last content tab.
    expect(settings.dy, greaterThan(screen - 120));
    expect(settings.dy - songs, greaterThan(300));
    // No dividers between the destinations.
    expect(
      find.descendant(of: rail, matching: find.byType(Divider)),
      findsNothing,
    );
    await app.dispose(tester);
  });

  testWidgets('one destination is selected across both groups', (tester) async {
    useTabletSize(tester);
    final app = await pumpApp(tester);
    expect(selected(tester, rail), 0);
    expect(selected(tester, bottom), isNull);

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    expect(currentTab(tester), HomeTab.settings);
    expect(selected(tester, rail), isNull);
    expect(selected(tester, bottom), 0);

    await tester.tap(find.byKey(const Key('nav-songs')));
    await tester.pumpAndSettle();
    expect(currentTab(tester), HomeTab.songs);
    expect(selected(tester, rail), 2);
    expect(selected(tester, bottom), isNull);
    await app.dispose(tester);
  });

  testWidgets('a short landscape screen does not overflow', (tester) async {
    tester.view.physicalSize = const Size(900, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('nav-settings')), findsOneWidget);
    await app.dispose(tester);
  });
}
