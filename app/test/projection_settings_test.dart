import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/projection/projection_controller.dart';
import 'package:setding/projection/projection_state.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// The settings of the lyrics projection (ADR-0068 §11, #1170).
void main() {
  const keys = [
    'projectionTheme',
    'projectionFont',
    'projectionAlign',
    'projectionLines',
    'projectionCopyright',
    'projectionMarkersAsText',
    'projectionSecondLanguage',
    'projectionPreview',
    'projectionTurnsSlides',
    'projectionShowLabel',
  ];

  test('defaults: dark, sans, centred, 8 lines, no extras', () {
    final options = ProjectionOptions.of(const AppSettings());
    expect(options.linesPerSlide, 8);
    expect(options.markersAsText, isFalse);
    expect(options.preview, isFalse);
    expect(options.copyright, ProjectionCopyright.everySlide);
    expect(options.style.toJson(), {
      'theme': 'dark',
      'font': 'sans',
      'align': 'center',
    });
    expect(const AppSettings().projectionSecondLanguage, '');
    expect(options.showLabel, isTrue);
    expect(
      ProjectionOptions.of(AppSettings.fromJson({'projectionShowLabel': false}))
          .showLabel,
      isFalse,
    );
  });

  test('stored and read back; device settings', () {
    const s = AppSettings(
      projectionTheme: ProjectionTheme.light,
      projectionFont: ProjectionFont.serif,
      projectionAlign: ProjectionAlign.left,
      projectionLines: 4,
      projectionCopyright: ProjectionCopyright.firstAndLast,
      projectionMarkersAsText: true,
      projectionSecondLanguage: 'en',
      projectionPreview: true,
    );
    final read = AppSettings.fromJson(s.toJson());
    final options = ProjectionOptions.of(read);
    expect(options.linesPerSlide, 4);
    expect(options.markersAsText, isTrue);
    expect(options.preview, isTrue);
    expect(options.copyright, ProjectionCopyright.firstAndLast);
    expect(options.style.toJson(), {
      'theme': 'light',
      'font': 'serif',
      'align': 'left',
    });
    expect(read.projectionSecondLanguage, 'en');
    for (final key in keys) {
      expect(AppSettings.scopes[key], SettingSyncScope.device, reason: key);
      expect(s.toJson().containsKey(key), isTrue, reason: key);
    }
  });

  test('an unknown number of lines falls back to 8', () {
    for (final lines in [0, 3, 99, -1]) {
      expect(
        AppSettings.fromJson({'projectionLines': lines}).projectionLines,
        8,
        reason: '$lines',
      );
    }
  });

  Future<TestApp> openLive(WidgetTester tester, {bool supported = true}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const SettingsScreen(),
        extra: [projectionSupportedProvider.overrideWithValue(supported)],
      ),
    );
    await tester.pumpAndSettle();
    await tapSettingsCategory(tester, 'live');
    return app;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the projection section in live mode, stored on the device', (
    tester,
  ) async {
    final app = await openLive(tester);
    final markers = find.byKey(const Key('settings-projection-markers'));
    await scrollTo(tester, markers);
    expect(find.text('Projection'), findsOneWidget);
    await tester.tap(markers);
    await tester.pumpAndSettle();
    expect(app.prefs.getBool('projectionMarkersAsText'), isTrue);
    expect(app.personal().containsKey('projectionMarkersAsText'), isFalse);

    final language = find.byKey(
      const Key('settings-projection-second-language'),
    );
    await scrollTo(tester, language);
    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(app.prefs.getString('projectionSecondLanguage'), 'en');
    await app.dispose(tester);
  });

  testWidgets('no projection section where the app cannot project', (
    tester,
  ) async {
    final app = await openLive(tester, supported: false);
    expect(find.byKey(const Key('settings-projection')), findsNothing);
    await app.dispose(tester);
  });
}
