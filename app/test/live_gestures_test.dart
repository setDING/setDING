import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:realchord/data/demo_song.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/render/song_view.dart';

import 'test_app.dart';

/// A one-page PDF without content (300 x 400 pt).
final _pdf = utf8.encode('''%PDF-1.1
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj
trailer<</Root 1 0 R>>
%%EOF
''');

/// Gestures in live mode must work on the whole page, not only on the song
/// text (ADR-0007).
void main() {
  Future<List<LiveItem>> createSongs(
    WidgetTester tester,
    TestApp app,
    List<String> sources, {
    bool pdfOnFirst = false,
  }) async => (await tester.runAsync(() async {
    final items = <LiveItem>[];
    for (final (i, source) in sources.indexed) {
      final id = await app.songs.createSong(source: source);
      if (pdfOnFirst && i == 0) {
        await app.songs.addAttachment(id, name: 'sheet.pdf', bytes: _pdf);
      }
      items.add(LiveItem.song((await app.songs.getSong(id))!));
    }
    return items;
  }))!;

  double scrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  testWidgets('dragging on empty areas scrolls the song', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final items = await createSongs(tester, app, [demoSongSource]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    final page = tester.getRect(find.byType(PageView));
    final empty = [
      Offset(page.right - 50, page.center.dy),
      Offset(page.right - 5, page.center.dy),
      Offset(page.left + 5, page.center.dy),
      // On the header, above the scroll view.
      Offset(page.center.dx, page.top + 10),
    ];
    // Beside the text, which is narrower than the page.
    final lines = find.descendant(
      of: find.byType(SongBody),
      matching: find.byType(RichText),
    );
    final textRight = [
      for (var i = 0; i < lines.evaluate().length; i++)
        tester.getRect(lines.at(i)).right,
    ].reduce(math.max);
    expect(textRight, lessThan(page.right - 100));
    var offset = scrollOffset(tester);
    for (final position in empty) {
      await tester.dragFrom(position, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scrollOffset(tester), greaterThan(offset), reason: '$position');
      offset = scrollOffset(tester);
    }
    await tester.dragFrom(empty.first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(scrollOffset(tester), lessThan(offset));
    await app.dispose(tester);
  });

  testWidgets('swiping and tapping on empty areas turns the song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    final page = tester.getRect(find.byType(PageView));
    // Below the short song text.
    final empty = Offset(page.center.dx, page.bottom - 50);
    await tester.flingFrom(empty, const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.flingFrom(empty, const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tapAt(Offset(page.left + 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('tapping and swiping on a PDF turns the song', (tester) async {
    useTabletSize(tester);
    final cache = Directory.systemTemp.createTempSync('realchord_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: true);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    await settle();
    expect(find.byType(PdfViewer), findsOneWidget);
    final page = tester.getRect(find.byType(PageView));
    final viewer = tester.getRect(find.byType(PdfViewer));
    expect(viewer, page);

    // On the PDF page in the middle of the viewer, in the right tap zone.
    await tester.tapAt(Offset(page.width * 0.75, page.center.dy));
    await settle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tapAt(Offset(page.width * 0.25, page.center.dy));
    await settle();
    expect(find.text('1 / 2'), findsOneWidget);

    // Swipe on the PDF page and on the empty area beside it.
    await tester.flingFrom(page.center, const Offset(-400, 0), 1500);
    await settle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.flingFrom(page.center, const Offset(400, 0), 1500);
    await settle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.flingFrom(
      Offset(page.right - 50, page.center.dy),
      const Offset(-400, 0),
      1500,
    );
    await settle();
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
    await settle();
  });
}
