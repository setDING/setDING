import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/live/pdf_spread_view.dart';
import 'package:realchord/ui/render/song_view.dart';

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

/// Live mode prepares the next song before the page turn (issue #262):
/// the direct neighbours are built and fitted ahead, nothing further away.
void main() {
  Future<List<LiveItem>> createSongs(
    WidgetTester tester,
    TestApp app,
    List<String> sources, {
    int? pdfAt,
  }) async => (await tester.runAsync(() async {
    final items = <LiveItem>[];
    for (final (i, source) in sources.indexed) {
      final id = await app.songs.createSong(source: source);
      if (i == pdfAt) {
        await app.songs.addAttachment(
          id,
          name: 'sheet.pdf',
          bytes: _pdfWith(3),
        );
      }
      items.add(LiveItem.song((await app.songs.getSong(id))!));
    }
    return items;
  }))!;

  Future<void> settlePdf(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Titles of the songs that are built, shown or not.
  Finder built(String title) => find.text(title, skipOffstage: false);

  testWidgets('the next song is built and fitted before the turn', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Second}\n[D]Two\n[G]Lines',
      '{title: Third}\n[E]Three',
      '{title: Fourth}\n[F]Four',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    // Only the first song is on stage, the second is ready behind it.
    expect(find.byType(SongBody), findsOneWidget);
    expect(find.byType(SongBody, skipOffstage: false), findsNWidgets(2));
    expect(find.text('Second'), findsNothing);
    expect(built('Second'), findsOneWidget);
    // Memory stays bounded: songs further away are not built.
    expect(built('Third'), findsNothing);
    expect(built('Fourth'), findsNothing);

    // The prepared page is the one shown after the turn: same fit, no
    // new layout.
    SongBody body(String title) => tester
        .widgetList<SongBody>(find.byType(SongBody, skipOffstage: false))
        .singleWhere((b) => b.song.title == title);
    final prepared = body('Second');
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(body('Second').options.fontSize, prepared.options.fontSize);
    expect(body('Second').options.columns, prepared.options.columns);

    // Both neighbours are kept, nothing else.
    expect(built('First'), findsOneWidget);
    expect(built('Third'), findsOneWidget);
    expect(built('Fourth'), findsNothing);

    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('3 / 4'), findsOneWidget);
    expect(built('First'), findsNothing);
    expect(built('Fourth'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the PDF of the next song is rendered before the turn', (
    tester,
  ) async {
    // Landscape: two pages side by side, rendered at layout.
    useTabletSize(tester);
    final cache = Directory.systemTemp.createTempSync('realchord_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Scanned}',
    ], pdfAt: 1);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);

    Finder pdfPage(int n, {bool skipOffstage = true}) =>
        find.byKey(ValueKey('pdf-spread-page-$n'), skipOffstage: skipOffstage);
    // Not on stage yet, but the document is open and its pages rendered.
    expect(find.byType(PdfSpreadView), findsNothing);
    expect(find.byType(PdfSpreadView, skipOffstage: false), findsOneWidget);
    expect(pdfPage(1), findsNothing);
    for (final n in [1, 2]) {
      expect(
        find.descendant(
          of: pdfPage(n, skipOffstage: false),
          matching: find.byType(RawImage, skipOffstage: false),
        ),
        findsOneWidget,
        reason: 'page $n',
      );
    }

    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Right after the turn, without waiting for the PDF.
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      find.descendant(of: pdfPage(1), matching: find.byType(RawImage)),
      findsOneWidget,
    );
    await app.dispose(tester);
    await settlePdf(tester);
  });
  testWidgets('portrait: the PDF viewer of the next song is opened ahead', (
    tester,
  ) async {
    useTabletSize(tester, landscape: false);
    final cache = Directory.systemTemp.createTempSync('realchord_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Scanned}',
    ], pdfAt: 1);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);

    expect(find.byType(PdfViewer), findsNothing);
    expect(find.byType(PdfViewer, skipOffstage: false), findsOneWidget);
    final viewer = tester.state(find.byType(PdfViewer, skipOffstage: false));

    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.center.dy));
    await settlePdf(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    // The viewer opened ahead is the one on stage.
    expect(tester.state(find.byType(PdfViewer)), same(viewer));
    await app.dispose(tester);
    await settlePdf(tester);
  });
}
