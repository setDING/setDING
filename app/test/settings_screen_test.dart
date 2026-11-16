import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/ui/settings_screen.dart';

import 'test_app.dart';

void main() {
  Future<TestApp> pumpSettings(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('wide: categories on the left, the selected one next to them', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await pumpSettings(tester);

    for (final c in SettingsCategory.values) {
      expect(find.byKey(Key('settings-category-${c.name}')), findsOneWidget);
    }
    // The account category is shown first.
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-general')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Not signed in'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    expect(find.text('Fit song to screen'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('narrow: a category opens as its own page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await pumpSettings(tester);

    expect(find.text('Not signed in'), findsNothing);
    expect(find.text('Language and theme'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();
    expect(find.text('Chord notation'), findsOneWidget);
    expect(find.byKey(const Key('settings-category-general')), findsNothing);

    await tester.tap(find.text('Lyrics only'));
    await tester.pumpAndSettle();
    expect(app.prefs.getString('displayMode'), 'lyricsOnly');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-category-general')), findsOneWidget);
    await app.dispose(tester);
  });
}
