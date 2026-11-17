import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Tapping the preview moves the editor cursor to the source (#372).
void main() {
  const source = '''{title: T}
{start_of_verse: Verse 1}
[C]First line
Second line
{end_of_verse}
{start_of_chorus}
Sing it
{end_of_chorus}''';

  int lineStart(String text, int line) {
    var offset = 0;
    for (var i = 0; i < line; i++) {
      offset = text.indexOf('\n', offset) + 1;
    }
    return offset;
  }

  Future<(TestApp, TextEditingController)> pump(
    WidgetTester tester,
    String text, {
    bool landscape = true,
  }) async {
    useTabletSize(tester, landscape: landscape);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: SongEditorScreen(initialSource: text)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    return (app, controller);
  }

  EditableTextState editor(WidgetTester tester) =>
      tester.state<EditableTextState>(find.byType(EditableText));

  testWidgets('a tapped line or label puts the cursor on its source line', (
    tester,
  ) async {
    final (app, controller) = await pump(tester, source);
    await tester.tap(find.text('Second line'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(source, 3));
    expect(editor(tester).widget.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Sing it'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(source, 6));

    await tester.tap(find.text('VERSE 1'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(source, 1));
    await app.dispose(tester);
  });

  testWidgets('on narrow screens the editor tab opens', (tester) async {
    final (app, controller) = await pump(tester, source, landscape: false);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sing it'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.selection.baseOffset, lineStart(source, 6));
    expect(field.focusNode!.hasFocus, isTrue);
    await app.dispose(tester);
  });

  testWidgets('the editor scrolls to a line far down', (tester) async {
    final long = [
      '{title: Long}',
      for (var i = 1; i <= 80; i++) 'Line $i',
    ].join('\n');
    final (app, controller) = await pump(tester, long);
    final scroll = editor(tester).widget.scrollController!;
    expect(scroll.offset, 0);
    await tester.ensureVisible(find.text('Line 80'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Line 80'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(long, 80));
    expect(scroll.offset, greaterThan(0));
    await app.dispose(tester);
  });
}
