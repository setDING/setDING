import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Drag and drop of the selection with the mouse (#377).
void main() {
  Future<(TestApp, TextEditingController)> pump(
    WidgetTester tester,
    String source,
    TextSelection selection,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.selection = selection;
    await tester.pump();
    return (app, controller);
  }

  RenderEditable editable(WidgetTester tester) =>
      tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

  /// Global position in the middle of the character at [offset].
  Offset at(WidgetTester tester, int offset) {
    final e = editable(tester);
    final rect = e.getLocalRectForCaret(TextPosition(offset: offset));
    return e.localToGlobal(rect.centerLeft + const Offset(3, 0));
  }

  Future<void> mouseDrag(
    WidgetTester tester,
    Offset from,
    Offset to, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    final gesture = await tester.createGesture(kind: kind);
    if (kind == PointerDeviceKind.mouse) {
      await gesture.addPointer(location: from - const Offset(0, 40));
      await gesture.moveTo(from);
      await tester.pump();
    }
    await gesture.down(from);
    await tester.pump();
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    if (kind == PointerDeviceKind.mouse) await gesture.removePointer();
  }

  testWidgets('a selected word is moved within the text', (tester) async {
    final (app, controller) = await pump(
      tester,
      'one two three',
      const TextSelection(baseOffset: 4, extentOffset: 8),
    );
    await mouseDrag(tester, at(tester, 5), at(tester, 13));
    expect(controller.text, 'one threetwo ');
    expect(controller.selection.textInside(controller.text), 'two ');
    await app.dispose(tester);
  });

  testWidgets('selected lines are dropped between lines', (tester) async {
    const source = 'first\nsecond\nthird\n';
    final (app, controller) = await pump(
      tester,
      source,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );
    // Dropped in the middle of "third": goes before it.
    await mouseDrag(tester, at(tester, 2), at(tester, 15));
    expect(controller.text, 'second\nfirst\nthird\n');
    await app.dispose(tester);
  });

  testWidgets('a click on the selection places the cursor', (tester) async {
    final (app, controller) = await pump(
      tester,
      'one two three',
      const TextSelection(baseOffset: 4, extentOffset: 13),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: at(tester, 0));
    await gesture.moveTo(at(tester, 9));
    await tester.pump();
    await gesture.down(at(tester, 9));
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, inInclusiveRange(9, 10));
    expect(controller.text, 'one two three');
    await gesture.removePointer();
    await app.dispose(tester);
  });

  testWidgets('touch keeps the text field behaviour', (tester) async {
    final (app, controller) = await pump(
      tester,
      'one two three',
      const TextSelection(baseOffset: 4, extentOffset: 8),
    );
    await mouseDrag(
      tester,
      at(tester, 5),
      at(tester, 13),
      kind: PointerDeviceKind.touch,
    );
    expect(controller.text, 'one two three');
    await app.dispose(tester);
  });

  testWidgets('the editing buttons have a row of their own', (tester) async {
    final (app, _) = await pump(
      tester,
      'x',
      const TextSelection.collapsed(offset: 0),
    );
    final menus = tester.getRect(find.text('More'));
    final undo = tester.getRect(find.byIcon(Icons.undo));
    final search = tester.getRect(find.byIcon(Icons.search));
    expect(undo.top, greaterThan(menus.bottom));
    expect(search.center.dy, closeTo(undo.center.dy, 1));
    await app.dispose(tester);
  });
}
