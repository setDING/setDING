import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/live/live_preparation.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/live_stage_pages.dart';

// The page turning of live mode, extracted from live_screen.dart (#1202).
void main() {
  late int index;
  late LivePreparation preparation;
  late LiveStagePages stage;
  late List<bool> slideTurns;
  late List<int> songPageChanges;
  var turnsSlides = false;

  Future<void> pumpStage(WidgetTester tester, int count) async {
    index = 0;
    slideTurns = [];
    songPageChanges = [];
    turnsSlides = false;
    final items = [
      for (var i = 0; i < count; i++) LiveItem.marker(null, 'Item $i'),
    ];
    preparation = LivePreparation(length: count, current: 0);
    stage = LiveStagePages(
      items: items,
      initialIndex: 0,
      current: () => index,
      preparation: preparation,
      step: () => 0.85,
      turnSlide: ({required forward}) {
        slideTurns.add(forward);
        return turnsSlides;
      },
      onSongPage: songPageChanges.add,
    );
    addTearDown(() {
      stage.dispose();
      preparation.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PageView(
          controller: stage.pageView,
          onPageChanged: (i) => index = i,
          children: [for (final i in items) Text(i.label!)],
        ),
      ),
    );
  }

  testWidgets('turns the pages of a song before the next item', (tester) async {
    await pumpStage(tester, 2);
    final pages = stage.songPageFor(0)..attach(2);
    await tester.pump();
    expect(songPageChanges, [0], reason: 'told about the attached pages');

    stage.next();
    expect(pages.page, 1);
    expect(index, 0);
    stage.next();
    await tester.pumpAndSettle();
    expect(index, 1);

    stage.previous();
    await tester.pumpAndSettle();
    expect(index, 0);
    stage.previous();
    expect(pages.page, 0);
    expect(slideTurns, [true, true, false, false]);
  });

  testWidgets('the projection takes a turn first (#1181)', (tester) async {
    await pumpStage(tester, 2);
    turnsSlides = true;
    stage.next();
    await tester.pumpAndSettle();
    expect(index, 0);
  });

  testWidgets('compact turns jump from item to item (ADR-0026)', (
    tester,
  ) async {
    await pumpStage(tester, 3);
    stage
      ..compact = true
      ..songPageFor(0).attach(2);
    stage.next();
    await tester.pump();
    expect(index, 1, reason: 'no page of the song');
    stage.jumpTo(2);
    await tester.pump();
    expect(index, 2);
    stage.next();
    await tester.pump();
    expect(index, 2, reason: 'the last item');
    await tester.pumpAndSettle();
  });

  testWidgets('the progress follows the song pages after the frame', (
    tester,
  ) async {
    await pumpStage(tester, 2);
    stage.songPageFor(0).attach(3);
    await tester.pump();
    stage.next();
    await tester.pump();
    // Markers count as one page.
    expect(stage.progress.value.pages, 1);
    expect(stage.progress.value.index, 0);
  });
}
