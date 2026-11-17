import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/line_number_gutter.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Selecting lines on the line numbers (#383).
void main() {
  const source = 'one\ntwo\nthree\nfour';

  Future<(TestApp, TextEditingController)> pump(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    return (app, controller);
  }

  /// Position of the number of the source line starting at [offset].
  Offset number(WidgetTester tester, int offset) {
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final y = editable.localToGlobal(caret.center).dy;
    return Offset(tester.getCenter(find.byType(LineNumberGutter)).dx, y);
  }

  testWidgets('a tap on a number selects its line', (tester) async {
    final (app, controller) = await pump(tester);
    await tester.tapAt(number(tester, 4));
    await tester.pump();
    expect(controller.selection.textInside(source), 'two\n');

    // The last line has no line break.
    await tester.tapAt(number(tester, 14));
    await tester.pump();
    expect(controller.selection.textInside(source), 'four');

    // The selected line moves with the toolbar button.
    await tester.tapAt(number(tester, 4));
    await tester.pump();
    await tester.tap(find.byTooltip('Move line down (Alt+↓)'));
    await tester.pump();
    expect(controller.text, 'one\nthree\ntwo\nfour');
    await app.dispose(tester);
  });

  testWidgets('dragging over the numbers selects several lines', (
    tester,
  ) async {
    final (app, controller) = await pump(tester);
    final gesture = await tester.startGesture(number(tester, 8));
    await gesture.moveTo(number(tester, 8) + const Offset(0, 4));
    await gesture.moveTo(number(tester, 0));
    await gesture.up();
    await tester.pump();
    expect(controller.selection.textInside(source), 'one\ntwo\nthree\n');
    await app.dispose(tester);
  });
}
