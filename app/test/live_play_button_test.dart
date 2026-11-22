import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/live/live_play_button.dart';
import 'package:setding/ui/theme.dart';

/// The live play button stands out at the end of the app bar (#444).
void main() {
  Future<void> pump(
    WidgetTester tester,
    VoidCallback? onPressed, {
    ThemeData? theme,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
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

  // AppBarActions keeps room for it (#838).
  for (final width in [360.0, 900.0]) {
    testWidgets('takes no more than widthOn, width $width', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, () {});
      expect(
        tester.getSize(find.byType(LivePlayButton)).width,
        lessThanOrEqualTo(LivePlayButton.widthOn(width)),
      );
    });
  }

  testWidgets('is disabled without an action', (tester) async {
    await pump(tester, null);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('play-live')),
    );
    expect(button.onPressed, isNull);
  });

  // The icon is drawn in onPrimary on the primary colour in both layouts, in
  // light and dark: the app bar's icon theme must not leak into the
  // icon-only button (#450).
  for (final brightness in Brightness.values) {
    for (final width in [360.0, 900.0]) {
      testWidgets('icon is readable, ${brightness.name}, width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = appTheme(brightness);
        await pump(tester, () {}, theme: theme);
        final button = find.byKey(const Key('play-live'));
        final background = tester
            .widget<Material>(
              find.descendant(of: button, matching: find.byType(Material)),
            )
            .color;
        final icon = tester.widget<RichText>(
          find.descendant(
            of: find.byIcon(Icons.play_arrow),
            matching: find.byType(RichText),
          ),
        );
        expect(background, theme.colorScheme.primary);
        expect(icon.text.style?.color, theme.colorScheme.onPrimary);
      });
    }
  }

  testWidgets('narrow disabled button keeps the disabled colours', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final theme = appTheme(Brightness.light);
    await pump(tester, null, theme: theme);
    final icon = tester.widget<RichText>(
      find.descendant(
        of: find.byIcon(Icons.play_arrow),
        matching: find.byType(RichText),
      ),
    );
    expect(
      icon.text.style?.color,
      theme.colorScheme.onSurface.withValues(alpha: 0.38),
    );
  });
}
