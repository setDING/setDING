import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/ui/widgets/logo.dart';

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
    expect(find.byType(RealChordMark), findsOneWidget);
    expect(find.byType(RealChordWordmark), findsOneWidget);
    expect(find.bySemanticsLabel('RealChord'), findsOneWidget);
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
      const MaterialApp(home: Center(child: RealChordLogo())),
    );
    expect(find.byType(RealChordMark), findsOneWidget);
    expect(find.text('Real'), findsOneWidget);
    expect(find.text('Chord'), findsOneWidget);
    expect(find.bySemanticsLabel('RealChord'), findsOneWidget);
  });
}
