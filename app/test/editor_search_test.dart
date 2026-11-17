import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/chordpro_editing_controller.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Search in the ChordPro editor (#368).
void main() {
  final searchField = find.byKey(const ValueKey('editor-search'));

  Future<(TestApp, ChordProEditingController)> pumpEditor(
    WidgetTester tester,
    String source,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final controller =
        tester.widget<TextField>(find.byType(TextField)).controller!
            as ChordProEditingController;
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    return (app, controller);
  }

  /// Background colours of the rendered editor text, as (text, colour).
  List<(String, Color?)> highlighted(WidgetTester tester) {
    final state = tester
        .stateList<EditableTextState>(find.byType(EditableText))
        .firstWhere((s) => s.widget.controller is ChordProEditingController);
    final result = <(String, Color?)>[];
    state.renderEditable.text!.visitChildren((child) {
      if (child is TextSpan &&
          child.text != null &&
          child.style?.backgroundColor != null) {
        result.add((child.text!, child.style!.backgroundColor));
      }
      return true;
    });
    return result;
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+F searches, highlights and steps through matches', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(tester, 'la [Am]la\nLA la');
    await ctrl(tester, LogicalKeyboardKey.keyF);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'la');
    await tester.pump();

    expect(find.text('1 of 4'), findsOneWidget);
    expect(controller.searchMatches, [(0, 2), (7, 9), (10, 12), (13, 15)]);
    final spans = highlighted(tester);
    expect(spans.map((s) => s.$1), ['la', 'la', 'LA', 'la']);
    // The current match stands out from the others.
    expect(spans.first.$2, isNot(spans[1].$2));
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('2 of 4'), findsOneWidget);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 7, extentOffset: 9),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pump();
    expect(find.text('4 of 4'), findsOneWidget);

    // Esc closes the bar, keeps the match selected and drops the highlights.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(searchField, findsNothing);
    expect(controller.searchMatches, isEmpty);
    expect(highlighted(tester), isEmpty);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 13, extentOffset: 15),
    );
    await app.dispose(tester);
  });

  testWidgets('the toolbar button searches for the selected text', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(tester, 'one [C]two\n[C]x');
    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
    await tester.pump();
    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(searchField).controller!.text, '[C]');
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.enterText(searchField, 'nothing');
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    // Matches follow changes of the text.
    await tester.enterText(searchField, 'x');
    await tester.pump();
    expect(find.text('1 of 1'), findsOneWidget);
    controller.text = 'x x x';
    await tester.pump();
    expect(controller.searchMatches, hasLength(3));

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(searchField, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('replaces the current match, then all of them', (tester) async {
    final (app, controller) = await pumpEditor(tester, 'Am x Am y am');
    await ctrl(tester, LogicalKeyboardKey.keyH);
    expect(find.byKey(const ValueKey('editor-replace')), findsOneWidget);
    await tester.enterText(searchField, 'am');
    await tester.enterText(find.byKey(const ValueKey('editor-replace')), 'Em7');
    await tester.pump();
    expect(find.text('1 of 3'), findsOneWidget);

    // Enter in the replace field replaces and selects the next match.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, 'Em7 x Am y am');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 8),
    );
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Em7 x Em7 y Em7');
    expect(find.text('2 replaced'), findsOneWidget);
    expect(find.text('No matches'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the toggle shows the replace row', (tester) async {
    final (app, controller) = await pumpEditor(tester, 'a b a');
    await ctrl(tester, LogicalKeyboardKey.keyF);
    expect(find.byKey(const ValueKey('editor-replace')), findsNothing);
    await tester.tap(find.byTooltip('Replace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-replace')), findsOneWidget);
    await tester.enterText(searchField, 'a');
    await tester.enterText(find.byKey(const ValueKey('editor-replace')), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Replace'));
    await tester.pump();
    expect(controller.text, ' b a');
    await app.dispose(tester);
  });
}
