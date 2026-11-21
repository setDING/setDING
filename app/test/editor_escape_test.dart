import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Esc closes the song editor when nothing changed (#749).
void main() {
  Future<void> pumpEditor(WidgetTester tester, {bool focus = true}) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SongEditorScreen(
                    initialSource: '{title: Song}\nla',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (focus) {
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
    }
    expect(find.byType(SongEditorScreen), findsOneWidget);
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  testWidgets('Esc in the unchanged editor closes it', (tester) async {
    await pumpEditor(tester);
    await escape(tester);
    expect(find.byType(SongEditorScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Esc closes the unchanged editor without focus in the text', (
    tester,
  ) async {
    await pumpEditor(tester, focus: false);
    await escape(tester);
    expect(find.byType(SongEditorScreen), findsNothing);
  });

  testWidgets('Esc with changes asks before discarding them', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField), '{title: Song}\nlala');
    await tester.pumpAndSettle();
    await escape(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SongEditorScreen), findsOneWidget);
  });

  testWidgets('Esc in the search bar closes only the search', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('editor-search'));
    expect(search, findsOneWidget);
    await escape(tester);
    expect(search, findsNothing);
    expect(find.byType(SongEditorScreen), findsOneWidget);
  });
}
