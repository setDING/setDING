import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

void main() {
  Future<(TestApp, String, TextEditingController)> pumpEditor(
    WidgetTester tester,
    String source,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(
      () => app.songs.createSong(source: '{title: T}\n'),
    ))!;
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<String>(
                  builder: (_) => SongEditorScreen(
                    songId: id,
                    initialSource: '{title: T}\n',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.text = source;
    await tester.pumpAndSettle();
    return (app, id, controller);
  }

  Future<String?> stored(WidgetTester tester, TestApp app, String id) =>
      tester.runAsync<String?>(
        () async => (await app.songs.getSong(id))?.chordproSource,
      );

  testWidgets('an invalid song asks before saving', (tester) async {
    const source = '{title: T}\n[G]la [Am li\n{start_of_abc}\nX:1\n';
    final (app, id, controller) = await pumpEditor(tester, source);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Check the ChordPro?'), findsOneWidget);
    expect(
      find.text('• Line 2: a square bracket (chord) is not closed.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Line 3: the block is never ended'),
      findsOneWidget,
    );
    expect(find.text('Fix automatically'), findsNothing);

    // Keep editing: nothing is saved, the first problem is selected.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(await stored(tester, app, id), '{title: T}\n');
    expect(controller.selection.textInside(controller.text), '[Am li');
    expect(find.byType(SongEditorScreen), findsOneWidget);

    // Save anyway.
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(await stored(tester, app, id), source);
    expect(find.byType(SongEditorScreen), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('text after a directive can be fixed (#309)', (tester) async {
    const source =
        '{title: T}\n{comment: Chorus} (first time a cappella)\n[G]la\n';
    final (app, id, controller) = await pumpEditor(tester, source);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '• Line 2: text after a directive; the whole line is shown as lyrics.',
      ),
      findsOneWidget,
    );

    // Fix: the source is corrected, nothing is saved yet.
    await tester.tap(find.text('Fix automatically'));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      '{title: T}\n{comment_italic: (first time a cappella)}\n'
      '{comment: Chorus}\n[G]la\n',
    );
    expect(controller.selection.baseOffset, '{title: T}\n'.length);
    expect(await stored(tester, app, id), '{title: T}\n');
    expect(find.byType(SongEditorScreen), findsOneWidget);

    // Now it saves without asking.
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Check the ChordPro?'), findsNothing);
    expect(await stored(tester, app, id), controller.text);
    await app.dispose(tester);
  });

  testWidgets('an empty or invalid key asks before saving (#933)', (
    tester,
  ) async {
    const source = '{title: T}\n{key}\n[G]la\n{key: Xyz}';
    final (app, id, controller) = await pumpEditor(tester, source);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Check the ChordPro?'), findsOneWidget);
    expect(
      find.text(
        '• Line 2: the key directive names no key; the song has no key for '
        'transposing and the chord views.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Line 4: the key directive'), findsOneWidget);
    expect(find.text('Fix automatically'), findsNothing);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(controller.selection.textInside(controller.text), '{key}');
    await app.dispose(tester);
  });

  testWidgets('a valid song is saved without asking', (tester) async {
    const source = '{title: T}\n[G]la [Am]li\n';
    final (app, id, _) = await pumpEditor(tester, source);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Check the ChordPro?'), findsNothing);
    expect(await stored(tester, app, id), source);
    await app.dispose(tester);
  });
}
