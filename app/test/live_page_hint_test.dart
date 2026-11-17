import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:realchord/data/database.dart' show SetItemType;
import 'package:realchord/data/demo_song.dart';
import 'package:realchord/settings/settings.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/settings_screen.dart';

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

/// [verses] verses of short chord lines: the height limits the font.
String _versesSong(int verses) =>
    '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

final _more = find.byKey(const Key('live-more-pages'));
final _end = find.byKey(const Key('live-song-end'));

/// The corner of the live page shows at a glance whether more of the song
/// follows (ADR-0007, issue #305).
void main() {
  Future<List<LiveItem>> createSongs(
    WidgetTester tester,
    TestApp app,
    List<String> sources, {
    Uint8List? pdfOnFirst,
  }) async => (await tester.runAsync(() async {
    final items = <LiveItem>[];
    for (final (i, source) in sources.indexed) {
      final id = await app.songs.createSong(source: source);
      if (pdfOnFirst != null && i == 0) {
        await app.songs.addAttachment(id, name: 'sheet.pdf', bytes: pdfOnFirst);
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

  void usePdfCache() {
    final cache = Directory.systemTemp.createTempSync('realchord_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
  }

  Future<void> tapRight(WidgetTester tester, {bool pdf = false}) async {
    final page = tester.getRect(find.byType(PageView));
    // In the corner, under the mark: it never takes the tap.
    await tester.tapAt(Offset(page.right - 10, page.bottom - 10));
    pdf ? await settlePdf(tester) : await tester.pumpAndSettle();
  }

  testWidgets('a folded corner shows the next page of a song', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      _versesSong(16),
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    expect(find.text('Page 1/2'), findsOneWidget);
    expect(_more, findsOneWidget);
    expect(_end, findsNothing);
    // In the bottom right corner of the page.
    final page = tester.getRect(find.byType(PageView));
    expect(tester.getBottomRight(_more), page.bottomRight);

    await tapRight(tester);
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(_more, findsNothing);
    expect(_end, findsOneWidget);

    // A song on one page ends on it.
    await tapRight(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(_more, findsNothing);
    expect(_end, findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a song that scrolls shows more until its end', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final items = await createSongs(tester, app, [demoSongSource]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(_more, findsOneWidget);

    for (var i = 0; i < 20 && _more.evaluate().isNotEmpty; i++) {
      await tapRight(tester);
    }
    expect(_more, findsNothing);
    expect(_end, findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('PDF pages show more until the last page', (tester) async {
    // Portrait: one page at a time in the PDF viewer.
    useTabletSize(tester, landscape: false);
    usePdfCache();
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: _pdfWith(2));
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);
    expect(find.byType(PdfViewer), findsOneWidget);
    expect(_more, findsOneWidget);

    await tapRight(tester, pdf: true);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(_more, findsNothing);
    expect(_end, findsOneWidget);
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('PDF spreads show more until the last spread', (tester) async {
    useTabletSize(tester);
    usePdfCache();
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: _pdfWith(3));
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);
    expect(_more, findsOneWidget);

    await tapRight(tester, pdf: true);
    expect(find.byKey(const ValueKey('pdf-spread-page-3')), findsOneWidget);
    expect(_more, findsNothing);
    expect(_end, findsOneWidget);
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('pauses show no mark', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const LiveScreen(
          items: [LiveItem.marker(SetItemType.pause, 'Break')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_more, findsNothing);
    expect(_end, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the mark can be switched off in the settings', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'pageHint': false},
    );
    final items = await createSongs(tester, app, [_versesSong(16)]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.text('Page 1/2'), findsOneWidget);
    expect(_more, findsNothing);
    expect(_end, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the live mode settings switch the mark', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(
      SwitchListTile,
      'Show more pages at a glance',
    );
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(app.prefs.getBool('pageHint'), isFalse);
    expect(AppSettings.load(app.prefs).pageHint, isFalse);
    await app.dispose(tester);
  });
}
