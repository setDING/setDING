import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Line and chord commands of the ChordPro editor (#361); the text
/// operations themselves are tested in the chordpro package.
void main() {
  convertTests();

  Future<(TestApp, TextEditingController)> pumpEditor(
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

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey? modifier,
    bool shift = false,
  }) async {
    if (modifier != null) await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (modifier != null) await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets('Alt+arrows move lines and chords', (tester) async {
    final (app, controller) = await pumpEditor(
      tester,
      'one\nt[C]wo\nthree',
      const TextSelection.collapsed(offset: 6),
    );
    await press(
      tester,
      LogicalKeyboardKey.arrowDown,
      modifier: LogicalKeyboardKey.altLeft,
    );
    expect(controller.text, 'one\nthree\nt[C]wo');
    await press(
      tester,
      LogicalKeyboardKey.arrowUp,
      modifier: LogicalKeyboardKey.altLeft,
    );
    await press(
      tester,
      LogicalKeyboardKey.arrowUp,
      modifier: LogicalKeyboardKey.altLeft,
    );
    expect(controller.text, 't[C]wo\none\nthree');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));

    await press(
      tester,
      LogicalKeyboardKey.arrowRight,
      modifier: LogicalKeyboardKey.altLeft,
    );
    expect(controller.text, 'tw[C]o\none\nthree');
    await press(
      tester,
      LogicalKeyboardKey.arrowLeft,
      modifier: LogicalKeyboardKey.altLeft,
    );
    await press(
      tester,
      LogicalKeyboardKey.arrowLeft,
      modifier: LogicalKeyboardKey.altLeft,
    );
    expect(controller.text, '[C]two\none\nthree');
    await app.dispose(tester);
  });

  testWidgets('shortcuts duplicate, delete and comment out lines', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(
      tester,
      'a\nb',
      const TextSelection.collapsed(offset: 0),
    );
    await press(
      tester,
      LogicalKeyboardKey.keyD,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    expect(controller.text, 'a\na\nb');
    await press(
      tester,
      LogicalKeyboardKey.slash,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    expect(controller.text, 'a\n# a\nb');
    await press(
      tester,
      LogicalKeyboardKey.keyK,
      modifier: LogicalKeyboardKey.controlLeft,
      shift: true,
    );
    expect(controller.text, 'a\nb');
    await app.dispose(tester);
  });

  testWidgets('toolbar buttons move lines and chords, undo and redo', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(
      tester,
      'one\n[G]two',
      const TextSelection.collapsed(offset: 5),
    );
    IconButton undo() =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undo().onPressed, isNull);
    // The undo history records the text after a short pause.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Move line up (Alt+↑)'));
    await tester.pump();
    expect(controller.text, '[G]two\none');
    await tester.tap(find.byTooltip('Move chord right (Alt+→)'));
    await tester.pump();
    expect(controller.text, 't[G]wo\none');

    // The undo history records the commands.
    await tester.pump(const Duration(seconds: 1));
    expect(undo().onPressed, isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pump();
    expect(controller.text, 'one\n[G]two');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.redo));
    await tester.pump();
    expect(controller.text, 't[G]wo\none');
    await app.dispose(tester);
  });

  testWidgets('the Lines menu lists all commands', (tester) async {
    final (app, controller) = await pumpEditor(
      tester,
      'a\nb',
      const TextSelection.collapsed(offset: 3),
    );
    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();
    for (final label in [
      'Move line up',
      'Move line down',
      'Move chord left',
      'Move chord right',
      'Duplicate line',
      'Delete line',
      'Comment out line (#)',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Duplicate line'));
    await tester.pumpAndSettle();
    expect(controller.text, 'a\nb\nb');
    await app.dispose(tester);
  });
}

void convertTests() {
  testWidgets('the Lines menu converts chords above lyrics', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: 'C    G\nla   la')),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convert chords above lyrics'));
    await tester.pumpAndSettle();
    expect(controller.text, '[C]la   [G]la');
    await app.dispose(tester);
  });

  testWidgets('pasting chords above lyrics offers the conversion', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: '{title: T}\n')),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.value = const TextEditingValue(
      text: '{title: T}\nAm      F\nHello there\n',
      selection: TextSelection.collapsed(offset: 31),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The pasted text has chords above the lyrics.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle();
    expect(controller.text, '{title: T}\n[Am]Hello th[F]ere\n');

    // Typing does not show the hint.
    controller.text = '${controller.text}x';
    await tester.pumpAndSettle();
    expect(find.text('Convert'), findsNothing);
    await app.dispose(tester);
  });

  group('CCLI bar lines (#481)', () {
    const source = '{comment: Turnaround}\n[|][G] [.] [C] [.][|][D][|]\n';
    const converted =
        '{start_of_grid shape="2x4" label="Turnaround"}\n'
        '| G . C . | D . . . |\n{end_of_grid}\n';

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

    testWidgets('a hint offers the conversion', (tester) async {
      final (app, controller) = await pump(tester);
      expect(
        find.text('A block of bar lines can be shown as a chord grid.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Convert'));
      await tester.pumpAndSettle();
      expect(controller.text, converted);
      expect(find.byType(CcliGridHint), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('the hint can be hidden', (tester) async {
      final (app, controller) = await pump(tester);
      await tester.tap(find.byTooltip('Hide hint'));
      await tester.pumpAndSettle();
      expect(find.byType(CcliGridHint), findsNothing);
      expect(controller.text, source);
      await app.dispose(tester);
    });

    testWidgets('the Lines menu converts them', (tester) async {
      final (app, controller) = await pump(tester);
      await tester.tap(find.text('Lines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convert bar lines to chord grids'));
      await tester.pumpAndSettle();
      expect(controller.text, converted);
      await app.dispose(tester);
    });
  });

  testWidgets('the Lines menu translates German section labels', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const SongEditorScreen(
          initialSource:
              '{start_of_verse: label="Vers 1"}\nla\n{end_of_verse}\n'
              '{c: Refrain}\nja\n',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translate section labels to English'));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      '{start_of_verse: label="Verse 1"}\nla\n{end_of_verse}\n'
      '{c: Chorus}\nja\n',
    );
    await app.dispose(tester);
  });
}
