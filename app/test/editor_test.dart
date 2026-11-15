import 'package:realchord/ui/render/song_header.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<(TestApp, TextField)> pumpEditor(
    WidgetTester tester,
    String source, {
    int? cursor,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = TextSelection.collapsed(
      offset: cursor ?? source.length,
    );
    await tester.pump();
    return (app, field);
  }

  Future<void> choose(WidgetTester tester, String group, String item) async {
    await tester.tap(find.text(group));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('grouped menus insert snippets on their own line', (
    tester,
  ) async {
    final (app, field) = await pumpEditor(tester, '{title: T}\nla la');
    await choose(tester, 'Sections', 'Pre-chorus');
    expect(
      field.controller!.text,
      '{title: T}\nla la\n{start_of_verse: Pre-chorus}\n\n{end_of_verse}\n',
    );
    // The cursor is inside the new section.
    expect(
      field.controller!.selection.baseOffset,
      '{title: T}\nla la\n{start_of_verse: Pre-chorus}\n'.length,
    );
    await app.dispose(tester);
  });

  testWidgets('a section wraps the selected lines', (tester) async {
    final (app, field) = await pumpEditor(tester, 'one\ntwo\n');
    field.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 8,
    );
    await tester.pump();
    await choose(tester, 'Sections', 'Bridge');
    expect(
      field.controller!.text,
      '{start_of_bridge}\none\ntwo\n{end_of_bridge}\n',
    );
    await app.dispose(tester);
  });

  testWidgets('song info selects an existing directive', (tester) async {
    const source = '{title: T}\n{key: G}\n[G]la';
    final (app, field) = await pumpEditor(tester, source);
    await choose(tester, 'Song info', 'Key');
    expect(field.controller!.text, source);
    final sel = field.controller!.selection;
    expect(source.substring(sel.start, sel.end), 'G');

    await choose(tester, 'Song info', 'Tempo (BPM)');
    // New metadata is added to the header, whatever is selected.
    expect(field.controller!.text, '{title: T}\n{key: G}\n{tempo: }\n[G]la');
    expect(field.controller!.selection.baseOffset, 28);
    await app.dispose(tester);
  });

  testWidgets('song info without a header goes to the top', (tester) async {
    final (app, field) = await pumpEditor(tester, '{start_of_verse}\nla');
    await choose(tester, 'Song info', 'Artist');
    expect(field.controller!.text, '{artist: }\n{start_of_verse}\nla');
    await app.dispose(tester);
  });

  testWidgets('keyboard shortcuts', (tester) async {
    final (app, field) = await pumpEditor(tester, 'la');
    await tester.tap(find.byType(TextField));
    await tester.pump();
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(field.controller!.text, '[]la');

    field.controller!.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(field.controller!.text, '[]<b>la</b>');

    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      field.controller!.text,
      '{start_of_chorus}\n\n{end_of_chorus}\n[]<b>la</b>',
    );
    await app.dispose(tester);
  });

  testWidgets('the preview is aligned to the top', (tester) async {
    final (app, _) = await pumpEditor(tester, '{title: Short}\n[C]la');
    final header = tester.getTopLeft(find.byType(SongHeader));
    expect(header.dy, lessThan(150));
    await app.dispose(tester);
  });

  testWidgets('song sequence is built from the parts of the song', (
    tester,
  ) async {
    const source =
        '{title: T}\n{sov}\na\n{eov}\n{start_of_verse: Pre-Chorus}\nb\n'
        '{eov}\n{soc}\nc\n{eoc}';
    final (app, field) = await pumpEditor(tester, source, cursor: 0);
    await choose(tester, 'Song info', 'Song sequence');
    await tester.tap(find.byKey(const ValueKey('sequence-part-V')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sequence-part-PC')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sequence-part-C')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sequence-part-C')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      field.controller!.text,
      source.replaceFirst(
        '{title: T}\n',
        '{title: T}\n{x_sequence: V, PC, C x2}\n',
      ),
    );

    // Editing again replaces the directive; clearing removes it.
    await choose(tester, 'Song info', 'Song sequence');
    expect(find.byKey(const ValueKey('sequence-entry')), findsNWidgets(3));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(field.controller!.text, source);
    await app.dispose(tester);
  });
}
