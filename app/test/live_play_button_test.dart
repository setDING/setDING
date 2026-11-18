import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/live/live_play_button.dart';

/// The live play button stands out at the end of the app bar (#444).
void main() {
  Future<void> pump(WidgetTester tester, VoidCallback? onPressed) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            appBar: AppBar(actions: [LivePlayButton(onPressed: onPressed)]),
          ),
        ),
      );

  testWidgets('is a labelled filled button behind a divider', (tester) async {
    var tapped = 0;
    await pump(tester, () => tapped++);
    expect(find.text('Live'), findsOneWidget);
    expect(find.byTooltip('Play live'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final button = find.byKey(const Key('play-live'));
    expect(tester.widget(button), isA<FilledButton>());
    // The divider comes first.
    expect(
      tester.getCenter(find.byType(VerticalDivider)).dx,
      lessThan(tester.getCenter(button).dx),
    );
    await tester.tap(button);
    expect(tapped, 1);
  });

  testWidgets('narrow screens show only the icon, still filled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var tapped = 0;
    await pump(tester, () => tapped++);
    expect(find.text('Live'), findsNothing);
    expect(find.byTooltip('Play live'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final button = find.byKey(const Key('play-live'));
    expect(tester.widget(button), isA<IconButton>());
    await tester.tap(button);
    expect(tapped, 1);
  });

  testWidgets('is disabled without an action', (tester) async {
    await pump(tester, null);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('play-live')),
    );
    expect(button.onPressed, isNull);
  });
}
