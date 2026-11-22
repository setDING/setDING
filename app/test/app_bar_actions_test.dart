import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/widgets/app_bar_actions.dart';
import 'package:setding/ui/widgets/menu_action.dart';

/// App bar actions move into the overflow menu on narrow screens (#838).
void main() {
  final pressed = <String>[];

  List<AppBarAction> actions({bool active = false, int? count}) => [
    for (final (id, icon) in [
      ('band', Icons.groups_outlined),
      ('personal', Icons.tune),
      ('links', Icons.headphones_outlined),
    ])
      AppBarAction(
        id: id,
        icon: icon,
        label: 'Open $id',
        active: id == 'links' && active,
        count: id == 'links' ? count : null,
        onPressed: () => pressed.add(id),
      ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    List<AppBarAction>? items,
    bool ownItems = true,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pressed.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Song'),
            actions: [
              AppBarActions<String>(
                actions: items ?? actions(),
                onSelected: pressed.add,
                itemBuilder: ownItems
                    ? (_) => [
                        MenuAction(
                          value: 'delete',
                          icon: Icons.delete_outline,
                          label: 'Delete',
                        ),
                      ]
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('app-bar-menu')));
    await tester.pumpAndSettle();
  }

  test('fits as many buttons as the width leaves room for', () {
    const reserved = AppBarActions.reservedWidth;
    expect(AppBarActions.visibleCount(reserved - 10, 3), 0);
    expect(AppBarActions.visibleCount(reserved + 48, 3), 1);
    expect(AppBarActions.visibleCount(reserved + 2 * 48 + 47, 3), 2);
    expect(AppBarActions.visibleCount(2000, 3), 3);
    expect(AppBarActions.visibleCount(reserved + 48, 3, otherWidth: 48), 0);
  });

  testWidgets('a wide screen shows every action as a button', (tester) async {
    await pump(tester, width: 1000);
    for (final id in ['band', 'personal', 'links']) {
      expect(find.byKey(Key(id)), findsOneWidget);
    }
    expect(find.byTooltip('Open band'), findsOneWidget);
    await tester.tap(find.byKey(const Key('personal')));
    expect(pressed, ['personal']);

    await openMenu(tester);
    expect(find.byKey(const Key('band-menu')), findsNothing);
    expect(find.byType(PopupMenuDivider), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a narrow screen moves the last actions into the menu, '
      'above a divider', (tester) async {
    // Room for one button.
    await pump(tester, width: AppBarActions.reservedWidth + 50);
    expect(find.byKey(const Key('band')), findsOneWidget);
    expect(find.byKey(const Key('personal')), findsNothing);
    expect(find.byKey(const Key('links')), findsNothing);

    await openMenu(tester);
    final personal = find.byKey(const Key('personal-menu'));
    final links = find.byKey(const Key('links-menu'));
    expect(personal, findsOneWidget);
    expect(links, findsOneWidget);
    expect(find.byKey(const Key('band-menu')), findsNothing);
    expect(
      find.descendant(of: personal, matching: find.byIcon(Icons.tune)),
      findsOneWidget,
    );
    // The hidden actions come first, then the divider and the own items.
    final divider = find.byType(PopupMenuDivider);
    expect(divider, findsOneWidget);
    expect(
      tester.getTopLeft(personal).dy,
      lessThan(tester.getTopLeft(links).dy),
    );
    expect(
      tester.getTopLeft(links).dy,
      lessThan(tester.getTopLeft(divider).dy),
    );
    expect(
      tester.getTopLeft(divider).dy,
      lessThan(tester.getTopLeft(find.text('Delete')).dy),
    );

    await tester.tap(find.text('Open links'));
    await tester.pumpAndSettle();
    expect(pressed, ['links']);
    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(pressed, ['links', 'delete']);
  });

  testWidgets('the badge of a hidden action shows in the menu and on the ⋮ '
      'button', (tester) async {
    await pump(tester, width: 300, items: actions(count: 2));
    Badge menuBadge() =>
        tester.widget(find.byKey(const Key('app-bar-menu-badge')));
    expect(menuBadge().isLabelVisible, isTrue);

    await openMenu(tester);
    final badge = find.descendant(
      of: find.byKey(const Key('links-menu')),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('no dot on the ⋮ button without a badge of a hidden action', (
    tester,
  ) async {
    await pump(tester, width: 300);
    final badge = tester.widget<Badge>(
      find.byKey(const Key('app-bar-menu-badge')),
    );
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('there is no menu without own items and hidden actions', (
    tester,
  ) async {
    await pump(tester, width: 1000, ownItems: false);
    expect(find.byKey(const Key('app-bar-menu')), findsNothing);

    await pump(tester, width: 300, ownItems: false);
    await openMenu(tester);
    expect(find.byKey(const Key('band-menu')), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsNothing);
  });
}
