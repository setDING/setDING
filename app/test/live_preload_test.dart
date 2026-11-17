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

  testWidgets('a turn neither fits nor builds nor disposes a song', (
    tester,
  ) async {
    // Long frames at the start of the turn animation would be visible
    // (issue #296): the song after next is prepared once the turn is over,
    // the song left behind is kept until then.
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: Uno}\n[C]Un',
      '{title: Dos}\n[D]Deux',
      '{title: Tres}\n[E]Trois',
      '{title: Cuatro}\n[F]Quattro',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(built('Tres'), findsOneWidget);

    final measured = debugMeasureBlocksCalls;
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    // The frames of the turn: the song after next is only a placeholder,
    // the first song is not disposed.
    for (var t = 0; t < 300; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(built('Cuatro'), findsNothing);
      expect(built('Uno'), findsOneWidget);
    }
    expect(
      find.byKey(const Key('live-page-placeholder'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('3 / 4'), findsOneWidget);
    expect(debugMeasureBlocksCalls, measured);
    expect(built('Uno'), findsOneWidget);

    // Then, in idle time: the next song is fitted and built, the first
    // one is taken down.
    await tester.pumpAndSettle();
    expect(debugMeasureBlocksCalls, greaterThan(measured));
    expect(built('Cuatro'), findsOneWidget);
    expect(built('Quattro'), findsOneWidget);
    expect(built('Uno'), findsNothing);
    expect(
      find.byKey(const Key('live-page-placeholder'), skipOffstage: false),
      findsNothing,
    );
    await app.dispose(tester);
  });

  testWidgets('turning and the control bar do not build the songs again', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: Alpha}\n[C]One',
      '{title: Beta}\n[D]Two',
      '{title: Gamma}\n[E]Three',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    SongBody body(String title) => tester
        .widgetList<SongBody>(find.byType(SongBody, skipOffstage: false))
        .singleWhere((b) => b.song.title == title);
    final alpha = body('Alpha');
    final beta = body('Beta');

    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(page.center);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit live mode'), findsOneWidget);
    expect(body('Alpha'), same(alpha));

    await tester.tapAt(page.center);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(body('Alpha'), same(alpha));
    expect(body('Beta'), same(beta));
    await app.dispose(tester);
  });

  testWidgets('all pages of a song are built, turning one builds nothing', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final verses = [
      for (var v = 1; v <= 16; v++)
        '{start_of_verse: Verse $v}\n'
            '${[for (var l = 1; l <= 4; l++) '[G]page${v}x$l and [C]more words'].join('\n')}\n'
            '{end_of_verse}',
    ].join('\n\n');
    final items = await createSongs(tester, app, ['{title: Paged}\n$verses']);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final indicator = find.byKey(const Key('live-song-page'));
    expect(indicator, findsOneWidget);
    final bodies = tester
        .widgetList<SongBody>(find.byType(SongBody, skipOffstage: false))
        .toList();
    expect(bodies.length, greaterThan(1));
    // Only the first page is on stage, the last verse is built behind it.
    expect(find.byType(SongBody), findsOneWidget);
    expect(find.textContaining('page16x4'), findsNothing);
    expect(
      find.textContaining('page16x4', skipOffstage: false),
      findsOneWidget,
    );

    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pump();
    expect(tester.widget<Text>(indicator).data, startsWith('Page 2/'));
    expect(find.byType(SongBody), findsOneWidget);
    expect(
      tester.widgetList<SongBody>(find.byType(SongBody, skipOffstage: false)),
      orderedEquals(bodies),
    );
    await app.dispose(tester);
  });

  testWidgets('the next song is built a few lines per frame', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final verses = [
      for (var v = 1; v <= 6; v++)
        '{start_of_verse: Verse $v}\n'
            '${[for (var l = 1; l <= 4; l++) '[G]verse${v}x$l'].join('\n')}\n'
            '{end_of_verse}',
    ].join('\n\n');
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Long}\n$verses',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    // Frame by frame: the long song grows in steps.
    final shown = <int>[];
    // (With a duration: the steps run between frames, in timers, and not
    // while an animation runs, e.g. the page hint fading in.)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      shown.add(
        [
          for (var v = 1; v <= 6; v++)
            if (find
                .textContaining('verse${v}x1', skipOffstage: false)
                .evaluate()
                .isNotEmpty)
              v,
        ].length,
      );
    }
    expect(shown.first, 0);
    expect(shown.last, 6);
    // Never all at once.
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i] - shown[i - 1], lessThanOrEqualTo(2), reason: '$shown');
    }
    // The same as built at once: all lines, in the fitted size.
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    for (var v = 1; v <= 6; v++) {
      expect(find.textContaining('verse${v}x4'), findsOneWidget);
    }
    await app.dispose(tester);
  });

  testWidgets('turning faster than the preparation shows the whole song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Second}\n[D]Two\n[G]Lines',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    // Not prepared yet.
    expect(built('Second'), findsNothing);
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.bottom - 20));
    await tester.pump();
    // Built at once in the first frame of the turn.
    expect(built('Second'), findsOneWidget);
    expect(built('Lines'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Lines'), findsOneWidget);
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
    // The pages are rendered asynchronously, in real time: under load this
    // can take longer than settlePdf waits. Wait for them, bounded.
    final images = find.byType(RawImage, skipOffstage: false);
    for (var i = 0; i < 30 && images.evaluate().length < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
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
