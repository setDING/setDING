import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/settings/settings_layout.dart';
import 'package:setding/ui/settings/song_display_settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// The settings content uses the width of its pane and, wide enough, flows
/// its sections into two columns (#774, ADR-0050).
void main() {
  group('twoColumnSplit', () {
    test('balances the heights of the columns', () {
      expect(twoColumnSplit([100, 100], 0), 1);
      expect(twoColumnSplit([300, 100, 100], 0), 1);
      expect(twoColumnSplit([100, 100, 300], 0), 2);
      expect(twoColumnSplit([100, 100, 100, 100], 24), 2);
    });

    test('puts more on the left on a tie', () {
      expect(twoColumnSplit([100, 100, 100], 0), 2);
    });
  });

  /// Three sections of [heights], each with a button to focus.
  Widget sections(List<double> heights) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SettingsSections([
          for (final (i, h) in heights.indexed)
            SizedBox(
              key: Key('section-$i'),
              height: h,
              child: Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  key: Key('button-$i'),
                  onPressed: () {},
                  child: Text('$i'),
                ),
              ),
            ),
        ]),
      ),
    ),
  );

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a wide pane shows two columns, in order', (tester) async {
    setWidth(tester, 1200);
    await tester.pumpWidget(sections([300, 100, 100]));

    final first = tester.getRect(find.byKey(const Key('section-0')));
    final second = tester.getRect(find.byKey(const Key('section-1')));
    final third = tester.getRect(find.byKey(const Key('section-2')));
    // The tall first section alone on the left, the others on the right.
    expect(first.left, 0);
    expect(first.width, (1200 - 16) / 2);
    expect(second.left, first.right + 16);
    expect(second.top, 0);
    expect(third.top, second.bottom + 24);
  });

  testWidgets('the keyboard moves through the columns one by one', (
    tester,
  ) async {
    setWidth(tester, 1200);
    // Left: sections 0 and 1, right: section 2, next to section 0.
    await tester.pumpWidget(sections([100, 100, 300]));
    expect(
      tester.getRect(find.byKey(const Key('section-2'))).top,
      tester.getRect(find.byKey(const Key('section-0'))).top,
    );

    final order = <String>[];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      final button = focused.findAncestorWidgetOfExactType<TextButton>()!;
      order.add((button.key! as ValueKey<String>).value);
    }
    expect(order, ['button-0', 'button-1', 'button-2']);
  });

  testWidgets('a narrower pane shows one column at its full width', (
    tester,
  ) async {
    setWidth(tester, settingsTwoColumnWidth - 1);
    await tester.pumpWidget(sections([100, 100, 100]));

    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(find.byKey(Key('section-$i')));
      expect(rect.left, 0);
      expect(rect.width, settingsTwoColumnWidth - 1);
    }
    expect(tester.getRect(find.byKey(const Key('section-1'))).top, 100 + 24);
  });

  testWidgets('the settings use the width of a wide screen', (tester) async {
    setWidth(tester, 1680);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();

    // General: its sections in two columns, right of the category list.
    final language = tester.getRect(
      find.widgetWithText(SettingsSection, 'Language & theme'),
    );
    final advanced = tester.getRect(
      find.widgetWithText(SettingsSection, 'Advanced'),
    );
    expect(advanced.left, greaterThan(language.right));
    expect(advanced.right, greaterThan(1600));

    // Song display: one column, the preview as wide as the pane.
    await openSettingsCategory(tester, SettingsCategory.songDisplay);
    final preview = tester.getRect(find.byType(SongDisplayPreview));
    expect(preview.width, greaterThan(1300));
  });
}
