import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';

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

/// Bluetooth page turners and keyboards turn pages exactly like the
/// right/left tap zones (ADR-0007, #261; Arrow Up/Down #286).
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

  /// [verses] verses of short chord lines: the height limits the font, so
  /// 16 verses are split into two pages.
  String versesSong(int verses) =>
      '{title: Long}\n${List.generate(verses, (_) => '{start_of_verse}\n${List.filled(4, '[C]La la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  const nextKeys = [
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.space,
  ];
  const previousKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.pageUp,
  ];

  for (final key in nextKeys) {
    testWidgets('${key.debugName} turns forward: song pages, then the song', (
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
      expect(find.text('Page 1/2'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      await press(tester, key);
      expect(find.text('Page 2/2'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      await press(tester, key);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.byKey(const Key('live-song-page')), findsNothing);

      // At the end of the set nothing happens.
      await press(tester, key);
      expect(find.text('2 / 2'), findsOneWidget);
      await app.dispose(tester);
    });
  }

  for (final key in previousKeys) {
    testWidgets('${key.debugName} turns back: the song, then its pages', (
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
      // Through both pages of the first song to the second song.
      await press(tester, LogicalKeyboardKey.pageDown);
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(find.text('2 / 2'), findsOneWidget);

      // Back to the last page of the previous song, then its first page.
      await press(tester, key);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Page 2/2'), findsOneWidget);
      await press(tester, key);
      expect(find.text('Page 1/2'), findsOneWidget);

      // At the start of the set nothing happens.
      await press(tester, key);
      expect(find.text('Page 1/2'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await app.dispose(tester);
    });
  }

  testWidgets('a held key turns only once', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Second}\n[D]Two',
      '{title: Third}\n[E]Three',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.pageDown);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.pageDown);
    expect(find.text('3 / 3'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('keys turn while a button of the control bar has the focus', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}\n[C]One',
      '{title: Second}\n[D]Two',
      '{title: Third}\n[E]Three',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();

    // The control bar opens with a tap in the middle of the screen.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    final close = Focus.of(tester.element(find.byIcon(Icons.close)));
    close.requestFocus();
    await tester.pump();
    expect(close.hasPrimaryFocus, isTrue);

    // Space turns instead of pressing the focused exit button.
    await press(tester, LogicalKeyboardKey.space);
    expect(find.byType(LiveScreen), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('3 / 3'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('2 / 3'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('keys go to a text field of a dialog opened from live mode', (
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

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    showDialog<void>(
      context: tester.element(find.byType(PageView)),
      builder: (context) => AlertDialog(
        content: TextField(controller: controller, autofocus: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(controller.selection.baseOffset, 3);

    // The arrow keys move the cursor; the song stays.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 2);
    // Up/down in a single-line field: to the start and the end.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selection.baseOffset, 0);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selection.baseOffset, 3);
    for (final key in [...nextKeys, ...previousKeys]) {
      await press(tester, key);
    }
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Escape closes the dialog only; afterwards the keys turn again.
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(LiveScreen), findsOneWidget);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('arrow down/up scroll a song that does not fit, then turn', (
    tester,
  ) async {
    useTabletSize(tester);
    // Without fitting, a long song scrolls instead of being paged.
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false},
    );
    final items = await createSongs(tester, app, [
      versesSong(16),
      '{title: Second}\n[D]Two',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position().maxScrollExtent, greaterThan(0));
    expect(position().pixels, 0);

    // Arrow Down scrolls through the song first, like the right tap zone.
    var offset = 0.0;
    while (position().pixels < position().maxScrollExtent) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(position().pixels, greaterThan(offset));
      offset = position().pixels;
    }
    // Arrow Up scrolls back before turning to a previous song.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(position().pixels, lessThan(offset));
    while (position().pixels > 0) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(find.text('1 / 2'), findsOneWidget);

    // At the end of the song, Arrow Down turns to the next song.
    while (position().pixels < position().maxScrollExtent) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('escape leaves live mode', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, ['{title: First}\n[C]One']);
    await tester.pumpWidget(
      app.build(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => LiveScreen(items: items)),
            ),
            child: const Text('Play'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveScreen), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(LiveScreen), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    // Once live mode is closed, its keys are no longer taken.
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(tester.takeException(), isNull);
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

  void usePdfCache() {
    final cache = Directory.systemTemp.createTempSync('setding_pdfrx');
    addTearDown(() => cache.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = cache.path;
  }

  testWidgets('keys turn a PDF song after tapping the PDF', (tester) async {
    // Portrait: one page at a time in the PDF viewer.
    useTabletSize(tester, landscape: false);
    usePdfCache();
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: _pdfWith(1));
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await settlePdf(tester);
    expect(find.byType(PdfViewer), findsOneWidget);

    // A tap on the PDF (in the middle: the control bar) may give the
    // viewer the focus; the keys still turn.
    await tester.tapAt(tester.getCenter(find.byType(PdfViewer)));
    await settlePdf(tester);
    for (final (next, previous) in [
      (LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowLeft),
      (LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp),
      (LogicalKeyboardKey.pageDown, LogicalKeyboardKey.pageUp),
      (LogicalKeyboardKey.space, LogicalKeyboardKey.pageUp),
    ]) {
      await tester.sendKeyEvent(next);
      await settlePdf(tester);
      expect(find.text('2 / 2'), findsOneWidget, reason: next.debugName);
      await tester.sendKeyEvent(previous);
      await settlePdf(tester);
      expect(find.text('1 / 2'), findsOneWidget, reason: previous.debugName);
    }
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('keys turn the PDF spreads before the song', (tester) async {
    useTabletSize(tester);
    usePdfCache();
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: First}',
      '{title: Second}\n[D]Two',
    ], pdfOnFirst: _pdfWith(3));
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await settlePdf(tester);
    }

    Finder pdfPage(int n) => find.byKey(ValueKey('pdf-spread-page-$n'));

    await settlePdf(tester);
    expect(find.byType(PdfSpreadView), findsOneWidget);
    expect(pdfPage(1), findsOneWidget);
    expect(pdfPage(2), findsOneWidget);

    // The next spread holds the last page alone.
    await press(LogicalKeyboardKey.pageDown);
    expect(pdfPage(3), findsOneWidget);
    expect(pdfPage(1), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // At the end of the PDF the next song follows.
    await press(LogicalKeyboardKey.arrowRight);
    expect(find.text('2 / 2'), findsOneWidget);

    // Back: the last spread first, then the first one.
    await press(LogicalKeyboardKey.pageUp);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(pdfPage(3), findsOneWidget);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(pdfPage(1), findsOneWidget);
    expect(pdfPage(2), findsOneWidget);

    await press(LogicalKeyboardKey.space);
    expect(pdfPage(3), findsOneWidget);
    await press(LogicalKeyboardKey.arrowUp);
    expect(pdfPage(1), findsOneWidget);
    await press(LogicalKeyboardKey.arrowDown);
    expect(pdfPage(3), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await app.dispose(tester);
    await settlePdf(tester);
  });

  testWidgets('a page-turn key in live mode is remembered (#911)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, [
      '{title: One}\n[C]La',
      '{title: Two}\n[D]La',
    ]);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    expect(app.prefs.getString(PageTurnerNotifier.lastUsedKey), isNull);

    await press(tester, LogicalKeyboardKey.pageDown);
    expect(find.text('2 / 2'), findsOneWidget);
    final stored = app.prefs.getString(PageTurnerNotifier.lastUsedKey);
    expect(DateTime.tryParse(stored ?? ''), isNotNull);
    await app.dispose(tester);
  });
}
