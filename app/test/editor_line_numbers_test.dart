import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/ui/songs/line_number_gutter.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

void main() {
  Future<TestApp> pumpEditor(WidgetTester tester, String source) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(home: SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    return app;
  }

  /// (line number, vertical centre) in gutter coordinates.
  List<(int, double)> centres(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField));
    final editable = findRenderEditable(field.key! as GlobalKey)!;
    final gutter = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(LineNumberGutter),
        matching: find.byType(CustomPaint),
      ),
    );
    return lineNumberCentres(editable, gutter);
  }

  RenderEditable editable(WidgetTester tester) => findRenderEditable(
    tester.widget<TextField>(find.byType(TextField)).key! as GlobalKey,
  )!;

  testWidgets('numbers sit on the first row of wrapped lines', (tester) async {
    final long = List.filled(40, 'wrapping').join(' ');
    final app = await pumpEditor(tester, 'one\n$long\nthree');
    final lineHeight = editable(tester).preferredLineHeight;
    final c = centres(tester);

    expect(c.map((e) => e.$1), [1, 2, 3]);
    // The first line starts at the top padding of the text field.
    expect(c[0].$2, closeTo(16 + lineHeight / 2, 1));
    expect(c[1].$2 - c[0].$2, closeTo(lineHeight, 0.5));
    // Line 2 wraps onto several rows; line 3 follows after all of them.
    final rows = ((c[2].$2 - c[1].$2) / lineHeight).round();
    expect(rows, greaterThan(1));
    expect(c[2].$2 - c[1].$2, closeTo(rows * lineHeight, 0.5));
    await app.dispose(tester);
  });

  testWidgets('numbers follow typing and scrolling', (tester) async {
    final source = List.generate(80, (i) => 'line ${i + 1}').join('\n');
    final app = await pumpEditor(tester, source);
    expect(centres(tester), hasLength(80));

    await tester.enterText(find.byType(TextField), 'new\n$source');
    await tester.pump();
    expect(centres(tester), hasLength(81));

    final before = centres(tester)[10].$2;
    final scroll = tester.widget<TextField>(find.byType(TextField));
    scroll.scrollController!.jumpTo(100);
    await tester.pump();
    expect(centres(tester)[10].$2, closeTo(before - 100, 0.5));
    await app.dispose(tester);
  });
}
