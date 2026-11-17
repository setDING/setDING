import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/songs/section_backgrounds.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

/// Section backgrounds in the ChordPro editor (#371).
void main() {
  SectionBackgroundPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find
                    .descendant(
                      of: find.byType(SectionBackgrounds),
                      matching: find.byType(CustomPaint),
                    )
                    .first,
              )
              .painter!
          as SectionBackgroundPainter;

  testWidgets('every section gets a full-width background by its type', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const SongEditorScreen(
          initialSource: '{title: T}\n{sov}\na\nb\n{eov}\n\n{start_of_chorus}\nc\n{end_of_chorus}\nafter',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final painted = painter(tester).lastPainted;
    expect(painted.map((p) => p.$2), ['verse', 'chorus']);
    final (verse, _) = painted[0];
    final (chorus, _) = painted[1];
    // Four lines for the verse, three for the chorus, an empty line between.
    expect(verse.height, closeTo(chorus.height * 4 / 3, 1));
    expect(chorus.top, greaterThan(verse.bottom));
    expect(verse.left, 0);
    final size = tester.getSize(find.byType(SectionBackgrounds));
    expect(verse.width, size.width);
    expect(
      sectionColour('verse', ThemeData().colorScheme),
      isNot(sectionColour('chorus', ThemeData().colorScheme)),
    );

    // The backgrounds follow the text.
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.text = '{sob}\nx';
    await tester.pump();
    expect(painter(tester).lastPainted.map((p) => p.$2), ['bridge']);
    await app.dispose(tester);
  });
}
