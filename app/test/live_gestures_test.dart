import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/render/song_view.dart';

import 'test_app.dart';

/// A PDF with [pages] pages without content (300 x 400 pt each).
Uint8List _pdfWith(int pages) {
  final kids = [for (var i = 0; i < pages; i++) '${i + 3} 0 R'].join(' ');
  return utf8.encode('''%PDF-1.1
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[$kids]/Count $pages>>endobj
${[for (var i = 0; i < pages; i++) '${i + 3} 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj'].join('\n')}
trailer<</Root 1 0 R>>
%%EOF
''');
}

final _pdf = _pdfWith(1);

/// Gestures in live mode must work on the whole page, not only on the song
/// text (ADR-0007).
void main() {
  Future<List<LiveItem>> createSongs(
    WidgetTester tester,
    TestApp app,
    List<String> sources, {
    bool pdfOnFirst = false,
    Uint8List? pdf,
  }) async => (await tester.runAsync(() async {
    final items = <LiveItem>[];
    for (final (i, source) in sources.indexed) {
      final id = await app.songs.createSong(source: source);
      if (pdfOnFirst && i == 0) {
        await app.songs.addAttachment(
          id,
          name: 'sheet.pdf',
          bytes: pdf ?? _pdf,
        );
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

  testWidgets('fit to page resets the enlarged text', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, ['{title: First}\n[C]One']);
    final id = items.single.song!.id;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    Future<double> scale() async =>
        (await tester.runAsync(() => app.songs.getOverlay(id)))!.fontScale;
    IconButton fit() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.fit_screen),
    );

    // The control bar opens with a tap in the middle of the screen.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(fit().onPressed, isNull, reason: 'already fitted');

    await tester.tap(find.byIcon(Icons.text_increase));
    await tester.pumpAndSettle();
    expect(await scale(), closeTo(1.1, 1e-9));
    expect(fit().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pumpAndSettle();
    expect(await scale(), 1.0);
    expect(fit().onPressed, isNull);
    await app.dispose(tester);
  });

  testWidgets('without fitting, fit to page measures the font scale', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final items = await createSongs(tester, app, [
      '{title: Long}\n${List.filled(20, '[C]One [G]two').join('\n')}',
      '{title: Short}\n[C]One',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final scroll = find.byType(SingleChildScrollView);

    Future<double> fitToPage(int index) async {
      // The control bar opens with a tap in the middle of the screen.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pumpAndSettle();
      final song = find.descendant(of: scroll, matching: find.byType(SongBody));
      expect(
        tester.getRect(song).bottom,
        lessThanOrEqualTo(tester.getRect(scroll).bottom + 1),
        reason: 'the whole song is visible',
      );
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      final id = items[index].song!.id;
      return (await tester.runAsync(() => app.songs.getOverlay(id)))!.fontScale;
    }

    // Longer than the page: smaller.
    expect(await fitToPage(0), lessThan(1.0));

    // Swipes turn like taps: the first one scrolls through the run-out
    // below the song, the second one turns to the next song.
    for (final expected in ['1 / 2', '2 / 2']) {
      await tester.flingFrom(
        Offset(tester.getRect(find.byType(PageView)).center.dx, 700),
        const Offset(-400, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }
    // A short song: larger.
    expect(await fitToPage(1), greaterThan(1.0));
    await app.dispose(tester);
  });

  /// [verses] verses of short chord lines: the height limits the font.
  String versesSong(int verses) =>
      '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

  testWidgets('long songs are split into pages turned by tapping', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      versesSong(16),
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(PageView));
    Future<void> tap(double x) async {
      await tester.tapAt(Offset(x, page.bottom - 20));
      await tester.pumpAndSettle();
    }

    final right = page.right - 20;
    final left = page.left + 20;
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Page 1/2'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tap(right);
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tap(right);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byKey(const Key('live-song-page')), findsNothing);

    // Back to the last page of the song, then its first page.
    await tap(left);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Page 2/2'), findsOneWidget);
    await tap(left);
    expect(find.text('Page 1/2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('swiping turns the pages of a song before the song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      versesSong(16),
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(PageView));
    Future<void> swipe(double dx, {double speed = 1500}) async {
      await tester.flingFrom(page.center, Offset(dx, 0), speed);
      await tester.pumpAndSettle();
    }

    expect(find.text('Page 1/2'), findsOneWidget);
    await swipe(-400);
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await swipe(-400);
    expect(find.text('2 / 2'), findsOneWidget);

    await swipe(400);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Page 2/2'), findsOneWidget);

    // A slow but long swipe turns too; a short one does not.
    await tester.dragFrom(page.center, Offset(page.width * 0.1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Page 2/2'), findsOneWidget);
    await tester.timedDragFrom(
      page.center,
      Offset(page.width * 0.4, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1/2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('enlarged text is split into pages instead of scrolling', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [versesSong(8)]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-song-page')), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.text_increase));
      await tester.pumpAndSettle();
    }
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.textContaining('Page 1/'), findsOneWidget);

    // Fit to page brings back one page.
    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-song-page')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the control bar switches between chords and Nashville', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: X}\n{key: G}\n[G]One [C]two',
      '{title: Y}\n[G]One [C]two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('live-nashville'));
    expect(toggle, findsOneWidget);
    await tester.tap(
      find.descendant(of: toggle, matching: find.text('Nashville')),
    );
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    // Stored as the personal overlay of the song.
    final id = items.first.song!.id;
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(id)))!.nashville,
      isTrue,
    );

    await tester.tap(
      find.descendant(of: toggle, matching: find.text('Chords')),
    );
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    // Back to the device setting.
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(id)))!.nashville,
      isNull,
    );

    // Without a key, Nashville numbers are not available.
    await tester.tapAt(
      tester.getTopRight(find.byType(PageView)) + const Offset(-20, 200),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<SegmentedButton<bool>>(toggle);
    expect(button.onSelectionChanged, isNull);
    await app.dispose(tester);
  });

  testWidgets('on a phone the Nashville toggle gets a row of its own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'de'});
    final items = await createSongs(tester, app, [
      '{title: X}\n{key: G}\n[G]One [C]two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    // No overflow, and the toggle is above the other controls.
    expect(tester.takeException(), isNull);
    final toggle = tester.getRect(find.byKey(const Key('live-nashville')));
    expect(
      toggle.bottom,
      lessThanOrEqualTo(tester.getRect(find.byIcon(Icons.close)).top),
    );
    await tester.tap(find.text('Nashville'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    await app.dispose(tester);
  });

  Future<void> settlePdf(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('tapping and swiping on a PDF turns the song', (tester) async {
    // Portrait: one page at a time in the PDF viewer.
    useTabletSize(tester, landscape: false);
    final cache = Directory.systemTemp.createTempSync('setding_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: true);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    Future<void> settle() => settlePdf(tester);

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

  testWidgets('landscape shows two PDF pages side by side', (tester) async {
    useTabletSize(tester);
    final cache = Directory.systemTemp.createTempSync('setding_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(
      tester,
      app,
      ['{title: First}', '{title: Second}\n[D]Two'],
      pdfOnFirst: true,
      pdf: _pdfWith(3),
    );
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    Future<void> settle() => settlePdf(tester);
    Finder pdfPage(int n) => find.byKey(ValueKey('pdf-spread-page-$n'));

    await settle();
    expect(find.byType(PdfSpreadView), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
    expect(pdfPage(1), findsOneWidget);
    expect(pdfPage(2), findsOneWidget);
    expect(
      tester.getCenter(pdfPage(1)).dx,
      lessThan(tester.getCenter(pdfPage(2)).dx),
    );

    final page = tester.getRect(find.byType(PageView));
    final right = Offset(page.left + page.width * 0.9, page.center.dy);
    final left = Offset(page.left + page.width * 0.1, page.center.dy);

    // The next spread holds the last page alone.
    await tester.tapAt(right);
    await settle();
    expect(pdfPage(3), findsOneWidget);
    expect(pdfPage(1), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // At the end of the PDF the next song follows.
    await tester.tapAt(right);
    await settle();
    expect(find.text('2 / 2'), findsOneWidget);

    // Back: the last spread first, then the first one.
    await tester.tapAt(left);
    await settle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(pdfPage(3), findsOneWidget);
    await tester.tapAt(left);
    await settle();
    expect(pdfPage(1), findsOneWidget);
    expect(pdfPage(2), findsOneWidget);

    // Swipes turn the spreads like taps.
    await tester.flingFrom(page.center, const Offset(-400, 0), 1500);
    await settle();
    expect(pdfPage(3), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.flingFrom(page.center, const Offset(400, 0), 1500);
    await settle();
    expect(pdfPage(1), findsOneWidget);
    await app.dispose(tester);
    await settle();
  });
}
