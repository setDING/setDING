import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Typing aids of the editor (#747); the rules themselves are tested in
/// the chordpro package (auto_close_test.dart).
void main() {
  Future<(TestApp, TextEditingController)> pumpEditor(
    WidgetTester tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: '')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    return (app, tester.widget<TextField>(find.byType(TextField)).controller!);
  }

  /// Types [char] at the cursor, as the keyboard does.
  Future<void> typeChar(
    WidgetTester tester,
    TextEditingController controller,
    String char,
  ) async {
    final at = controller.selection.baseOffset;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: controller.text.replaceRange(at, at, char),
        selection: TextSelection.collapsed(offset: at + char.length),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('[ and { are closed after the cursor', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await tester.enterText(find.byType(TextField), 'Hello ');
    await typeChar(tester, controller, '[');
    expect(controller.text, 'Hello []');
    expect(controller.selection.baseOffset, 7);

    await typeChar(tester, controller, 'G');
    await typeChar(tester, controller, ']');
    expect(controller.text, 'Hello [G]');
    expect(controller.selection.baseOffset, 9);
    await app.dispose(tester);
  });

  testWidgets('Enter after a section start adds its end', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await tester.enterText(find.byType(TextField), '{start_of_verse}');
    await tester.pumpAndSettle();
    await typeChar(tester, controller, '\n');
    expect(controller.text, '{start_of_verse}\n\n{end_of_verse}');
    expect(controller.selection.baseOffset, 17);
    await app.dispose(tester);
  });

  testWidgets('renaming a section start renames its end', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await tester.enterText(
      find.byType(TextField),
      '{start_of_vers}\nla\n{end_of_vers}',
    );
    controller.selection = const TextSelection.collapsed(offset: 14);
    await tester.pumpAndSettle();
    await typeChar(tester, controller, 'e');
    expect(controller.text, '{start_of_verse}\nla\n{end_of_verse}');
    expect(controller.selection.baseOffset, 15);
    await app.dispose(tester);
  });

  testWidgets('a section start chosen in the suggestions renames its end', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(tester);
    await tester.enterText(
      find.byType(TextField),
      '{start_of_ch}\nla\n{end_of_ch}',
    );
    controller.selection = const TextSelection.collapsed(offset: 12);
    await tester.pumpAndSettle();
    await typeChar(tester, controller, 'o');
    expect(controller.text, '{start_of_cho}\nla\n{end_of_cho}');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, '{start_of_chorus}\nla\n{end_of_chorus}');
    expect(controller.selection.baseOffset, 17);
    await app.dispose(tester);
  });

  testWidgets('accepting a section start adds its end', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await tester.enterText(find.byType(TextField), '{start_of_cho');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, '{start_of_chorus}\n\n{end_of_chorus}');
    expect(controller.selection.baseOffset, 18);
    await app.dispose(tester);
  });
}
