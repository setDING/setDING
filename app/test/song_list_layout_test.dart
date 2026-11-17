import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/ui/songs/songs_screen.dart';

import 'test_app.dart';

/// Layout of the song list: sections and columns (#251).
void main() {
  test('rows: a header where a section starts, then songs per row', () {
    List<Object?> rows(List<String?> sections, int columns) => [
      for (final r in songListRows(sections, columns)) r.header ?? r.songs,
    ];
    expect(rows(['A', 'A', 'A', 'B'], 2), [
      'A',
      [0, 1],
      [2],
      'B',
      [3],
    ]);
    expect(rows([null, null, null], 2), [
      [0, 1],
      [2],
    ]);
    expect(rows(['A', 'B'], 1), [
      'A',
      [0],
      'B',
      [1],
    ]);
  });

  Future<TestApp> start(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}');
      await app.songs.createSong(source: '{title: Another}');
    });
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('wide screens show two songs side by side', (tester) async {
    final app = await start(tester, const Size(1280, 800));
    final a = tester.getTopLeft(find.text('Alpha'));
    final b = tester.getTopLeft(find.text('Another'));
    expect(b.dy, a.dy);
    expect(b.dx, greaterThan(a.dx + 400));
    // The header spans the row, above both songs.
    expect(find.text('A'), findsOneWidget);
    expect(tester.getTopLeft(find.text('A')).dy, lessThan(a.dy));
    await app.dispose(tester);
  });

  testWidgets('narrow screens keep one column', (tester) async {
    final app = await start(tester, const Size(600, 900));
    final a = tester.getTopLeft(find.text('Alpha'));
    final b = tester.getTopLeft(find.text('Another'));
    expect(b.dx, a.dx);
    expect(b.dy, greaterThan(a.dy));
    await app.dispose(tester);
  });
}
