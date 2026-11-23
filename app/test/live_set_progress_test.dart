import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/set_progress_bar.dart';
import 'package:setding/ui/settings_screen.dart';

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

final _bar = find.byKey(const Key('live-set-progress'));

/// The progress bar of the set shows where the set stands and whether more
/// of the current song follows (ADR-0007, issue #311).
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
    final cache = Directory.systemTemp.createTempSync('setding_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
  }

  Future<void> tapRight(WidgetTester tester, {bool pdf = false}) async {
    final page = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(page.right - 20, page.center.dy));
    pdf ? await settlePdf(tester) : await tester.pumpAndSettle();
  }

  StageProgress progress(WidgetTester tester) =>
      tester.widget<SetProgressBar>(_bar).progress;

  Color colorOf(WidgetTester tester, String key) =>
      tester.widget<ColoredBox>(find.byKey(ValueKey(key))).color;

  ColorScheme scheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SetProgressBar))).colorScheme;

  testWidgets('shows the items of the set and the pages of the song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      _versesSong(16),
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(
      app.build(
        home: LiveScreen(
          items: [...items, const LiveItem.marker(MarkerIcons.breakIcon, null)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Across the whole width, between the page and the bottom bar.
    final page = tester.getRect(find.byType(PageView));
    final bar = tester.getRect(_bar);
    expect(bar.width, page.width);
    expect(bar.top, page.bottom);
    expect(tester.widget<SetProgressBar>(find.byType(SetProgressBar)).markers, [
      false,
      false,
      true,
    ]);

    expect(find.text('Page 1/2'), findsOneWidget);
    expect(progress(tester), (index: 0, pages: 2, page: 0, scroll: null));
    final primary = scheme(tester).primary;
    // Every segment fills the height of the bar.
    for (final key in ['progress-page-0', 'progress-page-1']) {
      expect(tester.getSize(find.byKey(ValueKey(key))).height, bar.height);
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-item-1'))).height,
      bar.height,
    );
    expect(colorOf(tester, 'progress-page-0'), primary);
    // The next page is still to come: a light accent tone.
    expect(colorOf(tester, 'progress-page-1'), primary.withValues(alpha: 0.35));

    await tapRight(tester);
    expect(progress(tester), (index: 0, pages: 2, page: 1, scroll: null));
    expect(colorOf(tester, 'progress-page-1'), primary);
    expect(colorOf(tester, 'progress-page-0'), isNot(primary));

    await tapRight(tester);
    expect(progress(tester), (index: 1, pages: 1, page: 0, scroll: null));
    expect(colorOf(tester, 'progress-page-0'), primary);
    await app.dispose(tester);
  });

  testWidgets('a pause is dashed, in the accent colour when current', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: const LiveScreen(
          items: [
            LiveItem.marker(MarkerIcons.breakIcon, 'Break'),
            LiveItem.marker(MarkerIcons.announcement, 'Hello'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color dashColor(int item) =>
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byKey(ValueKey('progress-item-$item')),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as DashedLinePainter)
            .color;
    // Never filled: no page boxes for a pause.
    expect(find.byKey(const ValueKey('progress-page-0')), findsNothing);
    expect(dashColor(0), scheme(tester).primary);
    expect(dashColor(1), isNot(scheme(tester).primary));

    await tapRight(tester);
    expect(dashColor(1), scheme(tester).primary);
    expect(dashColor(0), isNot(scheme(tester).primary));
    await app.dispose(tester);
  });

  testWidgets('a song that scrolls fills its segment', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final items = await createSongs(tester, app, [demoSongSource]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final start = progress(tester).scroll!;
    expect(start, inExclusiveRange(0, 1));

    await tapRight(tester);
    expect(progress(tester).scroll, greaterThan(start));
    for (var i = 0; i < 20 && progress(tester).scroll! < 1; i++) {
      await tapRight(tester);
    }
    expect(progress(tester).scroll, 1.0);
    await app.dispose(tester);
  });

  testWidgets('PDF pages are the pages of the song', (tester) async {
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
    expect(progress(tester), (index: 0, pages: 2, page: 0, scroll: null));

    await tapRight(tester, pdf: true);
    expect(progress(tester), (index: 0, pages: 2, page: 1, scroll: null));
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('PDF spreads are the pages of the song', (tester) async {
    useTabletSize(tester);
    usePdfCache();
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: _pdfWith(3));
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);
    expect(progress(tester), (index: 0, pages: 2, page: 0, scroll: null));

    await tapRight(tester, pdf: true);
    expect(find.byKey(const ValueKey('pdf-spread-page-3')), findsOneWidget);
    expect(progress(tester), (index: 0, pages: 2, page: 1, scroll: null));
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('the bar can be switched off', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'setProgress': false},
    );
    final items = await createSongs(tester, app, [_versesSong(16)]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(find.text('Page 1/2'), findsOneWidget);
    expect(_bar, findsNothing);
    // Without the bar no scrubbing either (#979).
    expect(find.byKey(const Key('live-set-progress-touch')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the display settings switch the bar', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(SwitchListTile, 'Progress bar of the set');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // A personal setting (ADR-0027).
    expect(app.personal()['setProgress'], isFalse);
    await app.dispose(tester);
  });

  group('hold and drag on the bar jumps (#979)', () {
    final four = [
      for (final (i, key) in ['C', 'D', 'E', 'G'].indexed)
        '{title: Song ${i + 1}}\n{key: $key}\n[$key]La la',
    ];
    final label = find.byKey(const Key('live-set-progress-label'));
    final scrub = find.byKey(const Key('live-set-progress-scrub'));

    /// The centre of item [i] of the bar below the page.
    Offset itemCenter(WidgetTester tester, int i) => tester
        .getRect(
          find.descendant(
            of: _bar,
            matching: find.byKey(ValueKey('progress-item-$i')),
          ),
        )
        .center;

    Future<TestApp> openLive(WidgetTester tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final items = await createSongs(tester, app, four);
      await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
      await tester.pumpAndSettle();
      return app;
    }

    Future<TestGesture> hold(WidgetTester tester, Offset at) async {
      final gesture = await tester.startGesture(at);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      return gesture;
    }

    testWidgets('a tap on the bar does nothing, the page still turns', (
      tester,
    ) async {
      final app = await openLive(tester);
      await tester.tapAt(itemCenter(tester, 2));
      await tester.pumpAndSettle();
      expect(progress(tester).index, 0);
      expect(scrub, findsNothing);

      // The touch zone reaches into the page, but taps go through to it.
      final page = tester.getRect(find.byType(PageView));
      await tester.tapAt(Offset(page.right - 20, page.bottom - 12));
      await tester.pumpAndSettle();
      expect(progress(tester).index, 1);
      await app.dispose(tester);
    });

    testWidgets('holding shows the item under the finger, release jumps', (
      tester,
    ) async {
      final app = await openLive(tester);
      final bar = tester.getRect(_bar);
      // The mapping matches the bar as laid out.
      for (var i = 0; i < 4; i++) {
        expect(
          SetProgressBar.itemAt(
            itemCenter(tester, i).dx - bar.left,
            bar.width,
            4,
            progress(tester),
          ),
          i,
        );
        expect(
          SetProgressBar.centerOf(i, bar.width, 4, progress(tester)),
          moreOrLessEquals(itemCenter(tester, i).dx - bar.left),
        );
      }

      // Held a little above the bar, inside the touch zone.
      final gesture = await hold(
        tester,
        itemCenter(tester, 1).translate(0, -16),
      );
      expect(scrub, findsOneWidget);
      expect(tester.getSize(scrub).height, greaterThan(bar.height * 4));
      expect(
        find.descendant(of: label, matching: find.text('Song 2 (D)')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progress-selected')), findsOneWidget);
      // Still the first song until released.
      expect(progress(tester).index, 0);

      await gesture.moveTo(itemCenter(tester, 3));
      await tester.pump();
      expect(
        find.descendant(of: label, matching: find.text('Song 4 (G)')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scrub, findsNothing);
      expect(progress(tester).index, 3);
      expect(find.text('Song 4'), findsWidgets);
      await app.dispose(tester);
    });

    testWidgets('released on the current item or far above, nothing happens', (
      tester,
    ) async {
      final app = await openLive(tester);
      var gesture = await hold(tester, itemCenter(tester, 2));
      await gesture.moveTo(itemCenter(tester, 0));
      await tester.pump();
      expect(
        find.descendant(of: label, matching: find.text('Song 1 (C)')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(progress(tester).index, 0);

      gesture = await hold(tester, itemCenter(tester, 2));
      await gesture.moveTo(itemCenter(tester, 2).translate(0, -150));
      await tester.pump();
      expect(label, findsNothing);
      expect(scrub, findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scrub, findsNothing);
      expect(progress(tester).index, 0);
      await app.dispose(tester);
    });

    testWidgets('no scrubbing while the control bar is shown', (tester) async {
      final app = await openLive(tester);
      final touch = find.byKey(const Key('live-set-progress-touch'));
      expect(touch, findsOneWidget);
      final page = tester.getRect(find.byType(PageView));
      await tester.tapAt(page.center);
      await tester.pumpAndSettle();
      expect(touch, findsNothing);
      await app.dispose(tester);
    });
  });
}
