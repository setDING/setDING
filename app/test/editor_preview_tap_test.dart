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

  /// Taps just inside the left edge of [finder].
  Future<void> tapStart(WidgetTester tester, Finder finder) async {
    final rect = tester.getRect(finder);
    await tester.tapAt(Offset(rect.left + 2, rect.center.dy));
    await tester.pumpAndSettle();
  }

  testWidgets('a tap puts the cursor at the tapped character', (tester) async {
    final (app, controller) = await pump(tester, source);
    await tapStart(tester, find.text('Second line'));
    expect(controller.selection.baseOffset, lineStart(source, 3));
    expect(editor(tester).widget.focusNode.hasFocus, isTrue);

    // "line" in "[C]First line": after the chord and "First ".
    await tapStart(tester, find.text('line'));
    expect(controller.selection.baseOffset, lineStart(source, 2) + 9);

    // A chord: before its bracket.
    await tapStart(tester, find.text('C', findRichText: true).first);
    expect(controller.selection.baseOffset, lineStart(source, 2));

    // The end of a word, and a label goes to the start of its directive.
    final rect = tester.getRect(find.text('Sing it'));
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(source, 6) + 7);

    await tester.tap(find.text('VERSE 1'));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, lineStart(source, 1));
    await app.dispose(tester);
  });

  testWidgets('on narrow screens the editor tab opens', (tester) async {
    final (app, controller) = await pump(tester, source, landscape: false);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tapStart(tester, find.text('Sing it'));
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
    await tapStart(tester, find.text('Line 80'));
    expect(controller.selection.baseOffset, lineStart(long, 80));
    expect(scroll.offset, greaterThan(0));
    await app.dispose(tester);
  });
}
