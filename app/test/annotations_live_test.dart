import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/ui/annotations/annotation_layer.dart';
import 'package:setding/ui/annotations/annotation_toolbar.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// Freehand annotations in live mode and on the song screen (ADR-0032).
void main() {
  Future<List<LiveItem>> createSongs(
    WidgetTester tester,
    TestApp app,
    List<String> sources,
  ) async => (await tester.runAsync(() async {
    final items = <LiveItem>[];
    for (final source in sources) {
      final id = await app.songs.createSong(source: source);
      items.add(LiveItem.song((await app.songs.getSong(id))!));
    }
    return items;
  }))!;

  Future<List<AnnotationRow>> rows(WidgetTester tester, TestApp app) async =>
      (await tester.runAsync(() => app.db.select(app.db.annotations).get()))!;

  Future<void> startDrawing(WidgetTester tester) async {
    final page = tester.getRect(find.byType(PageView));
    // A tap in the middle shows the controls.
    await tester.tapAt(page.center);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live-annotations-draw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('annotation-toolbar')), findsOneWidget);
  }

  Future<void> stylusLine(
    WidgetTester tester,
    Offset from,
    Offset by, {
    PointerDeviceKind kind = PointerDeviceKind.stylus,
  }) async {
    final g = await tester.startGesture(from, kind: kind);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(from + by * (i / 10));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  const sources = [
    '{title: First}\n[C]Amazing [G]grace\n[F]how sweet',
    '{title: Second}\n[D]Two',
  ];

  testWidgets('a stylus draws; fingers and pedals still turn', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);

    final page = tester.getRect(find.byType(PageView));
    // A stroke across the page, also through the tap zones.
    await stylusLine(
      tester,
      Offset(page.left + 30, page.center.dy),
      Offset(page.width - 60, 40),
    );
    final drawn = await rows(tester, app);
    expect(drawn, hasLength(1));
    final stroke = AnnotationStroke.fromJson(
      drawn.single.id,
      jsonDecode(drawn.single.stroke!),
    )!;
    expect(stroke.tool, AnnotationTool.pen);
    expect(stroke.layout?.mode, 'page');
    expect(stroke.anchor, isNotNull);
    expect(find.text('First'), findsWidgets, reason: 'the stylus did not turn');

    // A finger swipe turns the song while drawing (above the toolbar).
    await tester.flingFrom(
      Offset(page.center.dx, page.top + 100),
      const Offset(-400, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsWidgets);

    // So does the page turner.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsWidgets);

    // Escape leaves drawing mode first.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('annotation-toolbar')), findsNothing);
    expect(find.byType(LiveScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the toolbar buttons are large enough for a tablet', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);

    for (final key in [
      'annotation-tool-pen',
      'annotation-tool-eraser',
      'annotation-tool-stamp',
      'annotation-color-0',
      'annotation-size',
      'annotation-undo',
      'annotation-more',
      'annotation-done',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(
        size.height,
        greaterThanOrEqualTo(annotationToolbarButtonSize),
        reason: key,
      );
      expect(
        size.width,
        greaterThanOrEqualTo(annotationToolbarButtonSize),
        reason: key,
      );
    }
    await app.dispose(tester);
  });

  testWidgets('both erasers show an eraser icon, not a brush or scissors', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);

    EraserIcon iconOf(String key) => tester.widget<EraserIcon>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EraserIcon),
      ),
    );
    expect(iconOf('annotation-tool-eraser').partial, isFalse);
    expect(iconOf('annotation-tool-partialEraser').partial, isTrue);
    expect(find.byIcon(Icons.cleaning_services_outlined), findsNothing);
    expect(find.byIcon(Icons.content_cut), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('erase, undo, stamp, lasso and delete', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);
    final page = tester.getRect(find.byType(PageView));
    final y = page.top + page.height * 0.6;

    await stylusLine(tester, Offset(page.left + 100, y), const Offset(300, 0));
    expect(await rows(tester, app), hasLength(1));

    // The eraser removes the whole stroke it touches.
    await tester.tap(find.byKey(const Key('annotation-tool-eraser')));
    await tester.pumpAndSettle();
    await stylusLine(
      tester,
      Offset(page.left + 250, y - 40),
      const Offset(0, 80),
    );
    expect(await rows(tester, app), isEmpty);

    // Undo brings it back, redo erases it again.
    await tester.tap(find.byKey(const Key('annotation-undo')));
    await tester.pumpAndSettle();
    expect(await rows(tester, app), hasLength(1));
    await tester.tap(find.byKey(const Key('annotation-redo')));
    await tester.pumpAndSettle();
    expect(await rows(tester, app), isEmpty);
    await tester.tap(find.byKey(const Key('annotation-undo')));
    await tester.pumpAndSettle();

    // The partial eraser cuts the stroke in two.
    await tester.tap(find.byKey(const Key('annotation-tool-partialEraser')));
    await tester.pumpAndSettle();
    await stylusLine(
      tester,
      Offset(page.left + 250, y - 40),
      const Offset(0, 80),
    );
    expect(await rows(tester, app), hasLength(2));

    // A stamp with a tap of the stylus.
    await tester.tap(find.byKey(const Key('annotation-tool-stamp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('annotation-stamp-fermata')).last);
    await tester.pumpAndSettle();
    final stampAt = Offset(page.left + 600, page.top + 150);
    final g = await tester.startGesture(
      stampAt,
      kind: PointerDeviceKind.stylus,
    );
    await g.up();
    await tester.pumpAndSettle();
    final all = await rows(tester, app);
    expect(all, hasLength(3));
    expect(all.map((r) => (jsonDecode(r.stroke!) as Map)['stamp']).nonNulls, [
      'fermata',
    ]);

    // The lasso selects the stamp; delete removes it.
    await tester.tap(find.byKey(const Key('annotation-tool-lasso')));
    await tester.pumpAndSettle();
    final g2 = await tester.startGesture(
      stampAt + const Offset(-50, -50),
      kind: PointerDeviceKind.stylus,
    );
    for (final corner in const [
      Offset(50, -50),
      Offset(50, 50),
      Offset(-50, 50),
      Offset(-50, -50),
    ]) {
      await g2.moveTo(stampAt + corner);
      await tester.pump();
    }
    await g2.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('annotation-selection-delete')));
    await tester.pumpAndSettle();
    expect(
      (await rows(
        tester,
        app,
      )).map((r) => (jsonDecode(r.stroke!) as Map)['stamp']),
      everyElement(isNull),
    );
    await app.dispose(tester);
  });

  testWidgets('the text tool types, edits and erases text (#570)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);
    final page = tester.getRect(find.byType(PageView));
    await tester.tap(find.byKey(const Key('annotation-tool-text')));
    await tester.pumpAndSettle();

    Future<void> stylusTap(Offset at) async {
      final g = await tester.startGesture(at, kind: PointerDeviceKind.stylus);
      await g.up();
      await tester.pumpAndSettle();
    }

    Future<List<AnnotationStroke>> texts() async => [
      for (final r in await rows(tester, app))
        if (r.stroke != null)
          ?AnnotationStroke.fromJson(r.id, jsonDecode(r.stroke!)),
    ];

    // A tap opens the field; Shift+Enter starts a new line, Enter stores.
    final at = Offset(page.left + 300, page.top + 200);
    await stylusTap(at);
    final field = find.descendant(
      of: find.byType(AnnotationLayer),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'leise');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(await texts(), isEmpty, reason: 'Shift+Enter does not store');
    await tester.enterText(field, 'leise\n2× Intro');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    var stored = await texts();
    expect(stored.single.tool, AnnotationTool.text);
    expect(stored.single.text, 'leise\n2× Intro');
    expect(stored.single.anchor, isNotNull);
    expect(find.text('First'), findsWidgets, reason: 'Enter did not turn');

    // A tap on the text edits it; the done button stores the change.
    await stylusTap(at);
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, contains('leise'));
    await tester.enterText(field, 'laut');
    await tester.tap(find.byKey(const Key('annotation-text-done')));
    await tester.pumpAndSettle();
    stored = await texts();
    expect(stored.single.text, 'laut');

    // Escape drops what was typed.
    await stylusTap(at);
    await tester.enterText(field, 'nope');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect((await texts()).single.text, 'laut');
    expect(
      find.byKey(const Key('annotation-toolbar')),
      findsOneWidget,
      reason: 'Escape in the field does not leave drawing mode',
    );

    // A tap beside an open field stores it and opens no new one.
    await stylusTap(Offset(page.left + 300, page.top + 400));
    await tester.enterText(field, 'Solo');
    await stylusTap(Offset(page.left + 600, page.top + 500));
    expect(field, findsNothing);
    expect(
      (await texts()).map((s) => s.text),
      unorderedEquals(['laut', 'Solo']),
    );

    // Emptying a text erases it; undo brings it back.
    await stylusTap(at);
    await tester.enterText(field, '');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect((await texts()).map((s) => s.text), ['Solo']);
    await tester.tap(find.byKey(const Key('annotation-undo')));
    await tester.pumpAndSettle();
    expect(
      (await texts()).map((s) => s.text),
      unorderedEquals(['laut', 'Solo']),
    );

    // The lasso selects a text by its middle; larger scales its font.
    final solo = (await texts()).firstWhere((s) => s.text == 'Solo');
    await tester.tap(find.byKey(const Key('annotation-tool-lasso')));
    await tester.pumpAndSettle();
    final c = Offset(page.left + 330, page.top + 400);
    final lasso = await tester.startGesture(
      c + const Offset(-80, -60),
      kind: PointerDeviceKind.stylus,
    );
    for (final corner in const [
      Offset(80, -60),
      Offset(80, 60),
      Offset(-80, 60),
      Offset(-80, -60),
    ]) {
      await lasso.moveTo(c + corner);
      await tester.pump();
    }
    await lasso.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('annotation-selection-larger')));
    await tester.pumpAndSettle();
    final larger = (await texts()).firstWhere((s) => s.text == 'Solo');
    expect(larger.width, closeTo(solo.width * 1.25, 0.001));

    // The eraser removes a text it touches.
    await tester.tap(find.byKey(const Key('annotation-tool-eraser')));
    await tester.pumpAndSettle();
    await stylusTap(at + const Offset(10, 0));
    expect((await texts()).map((s) => s.text), ['Solo']);
    await app.dispose(tester);
  });

  testWidgets('a page turned away while typing keeps its text (#570)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);
    final page = tester.getRect(find.byType(PageView));
    await tester.tap(find.byKey(const Key('annotation-tool-text')));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(
      Offset(page.left + 300, page.top + 200),
      kind: PointerDeviceKind.stylus,
    );
    await g.up();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Capo 2');
    // A finger swipe turns to the next song.
    await tester.flingFrom(
      Offset(page.center.dx, page.top + 400),
      const Offset(-400, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsWidgets);
    expect(tester.takeException(), isNull);
    final stored = [
      for (final r in await rows(tester, app))
        ?AnnotationStroke.fromJson(r.id, jsonDecode(r.stroke!)),
    ];
    expect(stored.single.text, 'Capo 2');
    await app.dispose(tester);
  });

  testWidgets('fingers draw only when the setting allows it', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'annotationFinger': true},
    );
    final items = await createSongs(tester, app, sources);
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);
    final page = tester.getRect(find.byType(PageView));
    await stylusLine(
      tester,
      Offset(page.left + 100, page.center.dy),
      const Offset(-80, 0),
      kind: PointerDeviceKind.touch,
    );
    expect(await rows(tester, app), hasLength(1));
    expect(find.text('First'), findsWidgets, reason: 'the swipe drew');
    await app.dispose(tester);
  });

  testWidgets('the song screen shows them; the panel hides them', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: sources.first);
      await AnnotationRepository(app.db).apply(
        id,
        put: [
          const AnnotationStroke(
            id: 'x',
            tool: AnnotationTool.pen,
            width: 0.004,
            points: [0.1, 0.1, 0.2, 0.2],
          ),
        ],
      );
      return id;
    }))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationLayer), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-personal-adjustments')));
    await tester.pumpAndSettle();
    expect(find.text('1 annotation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('annotations-show')));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationLayer), findsNothing);
    await tester.tap(find.byKey(const Key('annotations-show')));
    await tester.pumpAndSettle();

    // Delete all, with undo.
    await tester.tap(find.byKey(const Key('annotations-delete-all')));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationLayer), findsNothing);
    // The panel closed, the message is free.
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationLayer), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('nearly full warns; full refuses new strokes', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = await createSongs(tester, app, sources);
    final songId = items.first.song!.id;
    // About 0.8 MB on a page not shown.
    final big = AnnotationStroke(
      id: 'big',
      tool: AnnotationTool.pen,
      width: 0.004,
      page: 99,
      points: [for (var i = 0; i < 50000; i++) (i % 9973) / 10000],
    );
    await tester.runAsync(
      () => AnnotationRepository(app.db).apply(
        songId,
        put: [
          for (final id in ['a', 'b', 'c'])
            AnnotationStroke.fromJson(id, big.toJson())!,
        ],
      ),
    );
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    await startDrawing(tester);
    expect(find.byKey(const Key('annotations-nearly-full')), findsOneWidget);
    expect(find.textContaining('% full'), findsOneWidget);

    // Beyond the limit (e.g. synced from another device): drawing is refused.
    final owner = (await rows(tester, app)).first.ownerId;
    await tester.runAsync(
      () => app.db
          .into(app.db.annotations)
          .insert(
            AnnotationsCompanion.insert(
              id: 'synced',
              ownerId: owner,
              songId: songId,
              stroke: Value(jsonEncode(big.toJson())),
              updatedAt: 0,
            ),
          ),
    );
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(PageView));
    await stylusLine(
      tester,
      Offset(page.left + 100, page.center.dy),
      const Offset(200, 0),
    );
    expect(await rows(tester, app), hasLength(4));
    expect(find.byKey(const Key('annotations-full')), findsOneWidget);
    expect(find.byKey(const Key('annotations-nearly-full')), findsNothing);
    await app.dispose(tester);
  });
}
