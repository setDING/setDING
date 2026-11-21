import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// The song editor's save button (#748): a labelled button on wide screens,
/// a round icon button on narrow ones; tonal until there are unsaved changes.
void main() {
  Future<TextEditingController> pumpEditor(
    WidgetTester tester, {
    required bool landscape,
  }) async {
    useTabletSize(tester, landscape: landscape);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: '{title: T}\n')),
    );
    await tester.pumpAndSettle();
    return tester.widget<TextField>(find.byType(TextField)).controller!;
  }

  final save = find.byKey(const Key('editor-save'));

  testWidgets('wide: a labelled button, filled once the song changes', (
    tester,
  ) async {
    final controller = await pumpEditor(tester, landscape: true);

    expect(save, findsOneWidget);
    expect(find.descendant(of: save, matching: find.text('Save')), findsOne);
    expect(find.byTooltip('Save'), findsOneWidget);
    final scheme = Theme.of(tester.element(save)).colorScheme;
    expect(_background(tester), scheme.secondaryContainer);

    controller.text = '{title: T}\nla\n';
    await tester.pump();
    expect(_background(tester), scheme.primary);

    controller.text = '{title: T}\n';
    await tester.pump();
    expect(_background(tester), scheme.secondaryContainer);
  });

  testWidgets('narrow: an icon button without a label, filled once dirty', (
    tester,
  ) async {
    final controller = await pumpEditor(tester, landscape: false);

    expect(save, findsOneWidget);
    expect(
      find.descendant(of: save, matching: find.text('Save')),
      findsNothing,
    );
    expect(
      find.descendant(of: save, matching: find.byIcon(Icons.check)),
      findsOne,
    );
    expect(find.byTooltip('Save'), findsOneWidget);
    final scheme = Theme.of(tester.element(save)).colorScheme;
    expect(_background(tester), scheme.secondaryContainer);

    controller.text = '{title: T}\nla\n';
    await tester.pump();
    expect(_background(tester), scheme.primary);
  });
}

/// The rendered background colour of the save button.
Color? _background(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byKey(const Key('editor-save')),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}
