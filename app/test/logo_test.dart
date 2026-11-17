import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/widgets/logo.dart';

import 'test_app.dart';

void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    required Brightness brightness,
    bool busy = false,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(SplashScreen(busy: busy));
  }

  Color background(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(SplashScreen),
              matching: find.byType(ColoredBox),
            )
            .first,
      )
      .color;

  testWidgets('the splash works without MaterialApp and shows the logo', (
    tester,
  ) async {
    await pumpSplash(tester, brightness: Brightness.light);
    expect(tester.takeException(), isNull);
    expect(find.byType(SetdingMark), findsOneWidget);
    expect(find.byType(SetdingWordmark), findsOneWidget);
    expect(find.bySemanticsLabel('setDING'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the splash follows the system brightness like the native one', (
    tester,
  ) async {
    await pumpSplash(tester, brightness: Brightness.light);
    expect(background(tester), BrandColors.splashLight);
    await pumpSplash(tester, brightness: Brightness.dark);
    await tester.pump();
    expect(background(tester), BrandColors.splashDark);
  });

  testWidgets('a busy splash shows a progress indicator', (tester) async {
    await pumpSplash(tester, brightness: Brightness.light, busy: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the logo has a mark, the wordmark and a label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: SetdingLogo())),
    );
    expect(find.byType(SetdingMark), findsOneWidget);
    expect(find.text('set'), findsOneWidget);
    expect(find.text('DING'), findsOneWidget);
    expect(find.bySemanticsLabel('setDING'), findsOneWidget);
  });

  test('the splash stays at least one second, counted from the start', () {
    expect(SplashScreen.minimumDuration, const Duration(seconds: 1));
    // Starting runs meanwhile: only the rest is waited for.
    expect(
      SplashScreen.remaining(const Duration(milliseconds: 300)),
      const Duration(milliseconds: 700),
    );
    expect(SplashScreen.remaining(Duration.zero), const Duration(seconds: 1));
  });

  test('a slow start does not wait any longer', () {
    expect(SplashScreen.remaining(const Duration(seconds: 1)), Duration.zero);
    expect(SplashScreen.remaining(const Duration(seconds: 3)), Duration.zero);
  });

  testWidgets('the navigation rail shows the logo mark at the top', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    final logo = find.byKey(const Key('nav-logo'));
    expect(
      find.descendant(of: find.byType(NavigationRail), matching: logo),
      findsOneWidget,
    );
    // Above the first destination, in the top left corner.
    final rect = tester.getRect(logo);
    expect(
      rect.top,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(NavigationRail),
                matching: find.text('Sets'),
              ),
            )
            .dy,
      ),
    );
    expect(rect.left, lessThan(80));
    expect(find.bySemanticsLabel('setDING'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the phone layout has no rail and no logo', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await TestApp.create();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('nav-logo')), findsNothing);
    await app.dispose(tester);
  });
}
