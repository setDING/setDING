import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

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

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('a directive suggestion is accepted with Tab', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await type(tester, '{ti');
    expect(find.text('title'), findsOneWidget);
    expect(find.text('time'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(controller.text, '{title: }');
    expect(controller.selection.baseOffset, 8);
    expect(find.text('title'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('arrow keys choose, Enter accepts', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await type(tester, '{ti');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, '{time: }');
    await app.dispose(tester);
  });

  testWidgets('a chord suggestion is accepted with a tap', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await type(tester, '{key: G}\n[Em]la [E');
    // The song's chord comes first.
    final suggestion = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Em'),
    );
    await tester.tap(suggestion.first);
    await tester.pumpAndSettle();
    expect(controller.text, '{key: G}\n[Em]la [Em]');
    expect(controller.selection.baseOffset, controller.text.length);
    await app.dispose(tester);
  });

  testWidgets('Esc dismisses until the next change', (tester) async {
    final (app, controller) = await pumpEditor(tester);
    await type(tester, '{ti');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('title'), findsNothing);
    // Tab is not taken by the list any more.
    expect(controller.text, '{ti');

    await type(tester, '{tit');
    expect(find.text('title'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('no suggestions while typing lyrics', (tester) async {
    final (app, _) = await pumpEditor(tester);
    await type(tester, 'la la');
    expect(find.byIcon(Icons.data_object), findsNothing);
    expect(find.byType(ListView), findsNothing);
    await app.dispose(tester);
  });
}
