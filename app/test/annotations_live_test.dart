import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/ui/annotations/annotation_layer.dart';
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
}
