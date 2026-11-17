import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/live_theme.dart';
import 'package:setding/ui/render/song_style.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/theme.dart';

import 'test_app.dart';

/// WCAG contrast ratio of two colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (([la, lb]..sort()).last + 0.05) / (([la, lb]..sort()).first + 0.05);
}

/// Live mode has a stage appearance independent of the app theme
/// (issue #263, ADR-0007).
void main() {
  Future<TestApp> pumpLive(
    WidgetTester tester, {
    String themeMode = 'light',
    String? appearance,
    String? accent,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        'themeMode': themeMode,
        'liveAppearance': ?appearance,
        'accent': ?accent,
      },
    );
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final source in [
        '{title: First}\n{key: G}\n[G]One [C]two',
        '{title: Second}\n[D]Three',
      ]) {
        final id = await app.songs.createSong(source: source);
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    return app;
  }

  Color chordColor(WidgetTester tester) =>
      tester.widget<ChordText>(find.byType(ChordText).first).style.color!;

  Color pageColor(WidgetTester tester) => tester
      .widget<Material>(
        find
            .ancestor(
              of: find.byType(PageView),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  /// The bar at the bottom with the next song.
  Color bottomBarColor(WidgetTester tester) => tester
      .widget<Container>(
        find
            .ancestor(
              of: find.textContaining('Next:'),
              matching: find.byType(Container),
            )
            .first,
      )
      .color!;

  testWidgets('the live appearance is chosen in the live mode settings', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    expect(find.text('Appearance on stage'), findsOneWidget);
    final choice = find.byType(SegmentedButton<LiveAppearance>);
    expect(tester.widget<SegmentedButton<LiveAppearance>>(choice).selected, {
      LiveAppearance.app,
    });
    await tester.ensureVisible(find.text('Black'));
    // Lay out the scrolled list before tapping.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Black'));
    await tester.pumpAndSettle();
    expect(app.prefs.getString('liveAppearance'), 'black');
    expect(AppSettings.load(app.prefs).liveAppearance, LiveAppearance.black);
    await app.dispose(tester);
  });

  testWidgets('following the app theme keeps it, with stronger chords', (
    tester,
  ) async {
    final app = await pumpLive(tester);
    final light = appTheme(Brightness.light).colorScheme;
    expect(pageColor(tester), light.surface);
    expect(chordColor(tester), StageColors.light.chord);
    expect(chordColor(tester), isNot(light.primary));
    await app.dispose(tester);
  });

  testWidgets('the stage follows the accent colour (#300)', (tester) async {
    var app = await pumpLive(tester, accent: 'blue');
    final light = appTheme(Brightness.light, AccentColor.blue).colorScheme;
    expect(pageColor(tester), light.surface);
    expect(chordColor(tester), AccentColor.blue.stageChord);
    await app.dispose(tester);

    app = await pumpLive(tester, appearance: 'black', accent: 'green');
    final dark = appTheme(Brightness.dark, AccentColor.green).colorScheme;
    expect(bottomBarColor(tester), const Color(0xFF121212));
    // Amber chords on dark for every accent; the controls use the accent.
    expect(chordColor(tester), StageColors.dark.chord);
    final theme = Theme.of(tester.element(find.byType(PageView)));
    expect(theme.colorScheme.primary, dark.primary);
    await app.dispose(tester);
  });

  testWidgets('dark on stage although the app is light', (tester) async {
    final app = await pumpLive(tester, appearance: 'dark');
    final dark = appTheme(Brightness.dark).colorScheme;
    expect(pageColor(tester), dark.surface);
    expect(bottomBarColor(tester), dark.surfaceContainer);
    expect(chordColor(tester), StageColors.dark.chord);
    // The lyrics are light on the dark page.
    final lyrics = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.style?.color)
        .whereType<Color>();
    expect(lyrics, contains(dark.onSurface));
    await app.dispose(tester);
  });

  testWidgets('black: true black page, controls and overview follow', (
    tester,
  ) async {
    final app = await pumpLive(tester, appearance: 'black');
    expect(pageColor(tester), Colors.black);
    expect(bottomBarColor(tester), const Color(0xFF121212));
    expect(chordColor(tester), StageColors.dark.chord);

    // The control bar and the set overview are dark too.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    // The first opaque material around the buttons.
    final bar = tester
        .widgetList<Material>(
          find.ancestor(
            of: find.byTooltip('Exit live mode'),
            matching: find.byType(Material),
          ),
        )
        .firstWhere((m) => (m.color?.a ?? 0) > 0);
    expect(bar.color, const Color(0xFF1B1B1B));
    await tester.tap(find.byTooltip('Set overview'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(BottomSheet))).brightness,
      Brightness.dark,
    );
    final sheet = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(sheet.color, const Color(0xFF0B0B0B));
    await app.dispose(tester);
  });

  test('chords have high contrast in every appearance', () {
    for (final (base, accent) in [
      for (final accent in AccentColor.values) ...[
        (appTheme(Brightness.light, accent), accent),
        (appTheme(Brightness.dark, accent), accent),
      ],
    ]) {
      for (final appearance in LiveAppearance.values) {
        final theme = liveTheme(base, appearance, accent);
        final chord = theme.extension<StageColors>()!.chord;
        final scheme = theme.colorScheme;
        final reason = '${base.brightness} $appearance $accent';
        // WCAG AAA for normal text.
        expect(
          _contrast(chord, scheme.surface),
          greaterThan(7),
          reason: reason,
        );
        // Stronger than the theme's primary colour used elsewhere.
        expect(
          _contrast(chord, scheme.surface),
          greaterThan(_contrast(scheme.primary, scheme.surface)),
          reason: reason,
        );
      }
    }
    expect(
      liveTheme(
        appTheme(Brightness.light),
        LiveAppearance.black,
      ).colorScheme.surface,
      Colors.black,
    );
  });
}
