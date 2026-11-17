import 'package:setding/ui/render/song_header.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('the preview follows the text shortly after typing', (
    tester,
  ) async {
    final (app, field) = await pumpEditor(tester, '{title: Before}\n[C]la');
    String previewTitle() =>
        tester.widget<SongHeader>(find.byType(SongHeader)).title;
    expect(previewTitle(), 'Before');

    field.controller!.text = '{title: After}\n[C]la';
    await tester.pump();
    expect(previewTitle(), 'Before');
    await tester.pump(editorPreviewDelay);
    expect(previewTitle(), 'After');

    // Moving the cursor keeps the preview.
    field.controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    expect(previewTitle(), 'After');
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

  testWidgets('song sequence entries are moved by drag and drop', (
    tester,
  ) async {
    const source =
        '{title: T}\n{x_sequence: V, PC, C}\n{sov}\na\n{eov}\n'
        '{start_of_verse: Pre-Chorus}\nb\n{eov}\n{soc}\nc\n{eoc}\n'
        '{sob}\nd\n{eob}';
    final (app, field) = await pumpEditor(tester, source, cursor: 0);
    await choose(tester, 'Song info', 'Song sequence');
    final entries = find.byKey(const ValueKey('sequence-entry'));
    expect(entries, findsNWidgets(3));
    expect(
      find.text('Long-press a part to move it to another position.'),
      findsOneWidget,
    );

    // Long-presses [from] and drops it on [to].
    Future<void> drag(Finder from, Finder to) async {
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(5, 5));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(to));
      await tester.pump();
      expect(find.byKey(const ValueKey('sequence-drop-marker')), findsWidgets);
      await gesture.up();
      await tester.pump();
    }

    // Move C in front of V: C, V, PC.
    await drag(entries.at(2), entries.at(0));
    // Insert the bridge from the parts in front of PC: C, V, B, PC.
    await drag(find.byKey(const ValueKey('sequence-part-B')), entries.at(2));
    // Move C onto PC, i.e. to the end: V, B, PC, C.
    await drag(entries.at(0), entries.at(3));
    // A tap still appends.
    await tester.tap(find.byKey(const ValueKey('sequence-part-V')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      field.controller!.text,
      source.replaceFirst('V, PC, C', 'V, B, PC, C, V'),
    );
    await app.dispose(tester);
  });

  testWidgets('parts dropped on the free space of the sequence are appended', (
    tester,
  ) async {
    const source = '{title: T}\n{sov}\na\n{eov}\n{soc}\nc\n{eoc}';
    final (app, field) = await pumpEditor(tester, source, cursor: 0);
    await choose(tester, 'Song info', 'Song sequence');
    final area = find.byKey(const ValueKey('sequence-drop-area'));
    for (final code in ['C', 'V']) {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey('sequence-part-$code'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getBottomRight(area) - const Offset(8, 8));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('sequence-entry')), findsNWidgets(2));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      field.controller!.text,
      source.replaceFirst('{title: T}\n', '{title: T}\n{x_sequence: C, V}\n'),
    );
    await app.dispose(tester);
  });

  Future<void> pick(WidgetTester tester, String field, String item) async {
    await tester.tap(find.byKey(ValueKey('songDetail-$field')));
    await tester.pumpAndSettle();
    // The menu scrolls when it has more items than fit.
    await tester.scrollUntilVisible(
      find.text(item),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('song details edit the metadata in a form', (tester) async {
    const source = '{t: Old}\n{key: G}\n{capo: 2}\n\n[G]la';
    final (app, field) = await pumpEditor(tester, source);
    await tester.tap(find.text('Song details'));
    await tester.pumpAndSettle();

    Finder input(String name) => find.byKey(ValueKey('songDetail-$name'));
    expect(
      tester.widget<TextFormField>(input('title')).controller!.text,
      'Old',
    );
    // Key and capo are dropdowns showing the current values.
    expect(
      find.descendant(of: input('key'), matching: find.text('G')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: input('capo'), matching: find.text('Capo: 2 (A)')),
      findsOneWidget,
    );

    await tester.enterText(input('title'), 'New');
    await pick(tester, 'key', 'Bb');
    await pick(tester, 'capo', 'No capo');
    await tester.enterText(input('tempo'), '9a0');
    await tester.enterText(input('time'), '6/8');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      field.controller!.text,
      '{t: New}\n{key: Bb}\n{tempo: 90}\n{time: 6/8}\n\n[G]la',
    );
    // The preview follows.
    await tester.pump(editorPreviewDelay);
    expect(find.text('New'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('song details add key and capo, cancel changes nothing', (
    tester,
  ) async {
    const source = '{title: T}\nla';
    final (app, field) = await pumpEditor(tester, source);
    await tester.tap(find.text('Song details'));
    await tester.pumpAndSettle();
    await pick(tester, 'key', 'F#m');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(field.controller!.text, source);

    await tester.tap(find.text('Song details'));
    await tester.pumpAndSettle();
    await pick(tester, 'key', 'F#m');
    await pick(tester, 'capo', 'Capo: 3 (Am)');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(field.controller!.text, '{title: T}\n{key: F#m}\n{capo: 3}\nla');
    await app.dispose(tester);
  });

  testWidgets('song details edit the sequence in the dialog of the sets', (
    tester,
  ) async {
    const source = '{title: T}\n{sov}\na\n{eov}\n{soc}\nc\n{eoc}';
    final (app, field) = await pumpEditor(tester, source);
    await tester.tap(find.text('Song details'));
    await tester.pumpAndSettle();
    final sequence = find.byKey(const ValueKey('songDetail-x_sequence'));
    expect(
      find.descendant(of: sequence, matching: find.text('No sequence')),
      findsOneWidget,
    );

    await tester.tap(sequence);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-part-V')));
    await tester.tap(find.byKey(const ValueKey('sequence-part-C')));
    await tester.tap(find.byKey(const ValueKey('sequence-part-C')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The form shows the new sequence; the source changes only on OK.
    expect(
      find.descendant(of: sequence, matching: find.byType(SongSequenceView)),
      findsOneWidget,
    );
    expect(field.controller!.text, source);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      field.controller!.text,
      source.replaceFirst(
        '{title: T}\n',
        '{title: T}\n{x_sequence: V, C x2}\n',
      ),
    );

    // Clearing the sequence removes the directive.
    await tester.tap(find.text('Song details'));
    await tester.pumpAndSettle();
    await tester.tap(sequence);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sequence-entry')), findsNWidgets(2));
    await tester.tap(find.text('Clear'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(field.controller!.text, source);
    await app.dispose(tester);
  });
}
