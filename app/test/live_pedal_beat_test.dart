import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'test_app.dart';

/// The beat is started and stopped with a long press of the forward pedal
/// or with Enter (ADR-0026, #335), and with Space when chosen (#969).
void main() {
  Future<TestApp> open(
    WidgetTester tester, {
    Map<String, Object> prefs = const {
      'instrument': 'drums',
      'clickStart': 'manual',
    },
    String meta = '{tempo: 100}\n{time: 4/4}\n',
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final title in ['One', 'Two']) {
        final id = await app.songs.createSong(
          source: '{title: $title}\n$meta[G]Line',
        );
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    return app;
  }

  Future<void> hold(
    WidgetTester tester,
    LogicalKeyboardKey key,
    Duration duration,
  ) async {
    await tester.sendKeyDownEvent(key);
    await tester.pump(duration);
    await tester.sendKeyUpEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a long press of the forward pedal starts and stops the beat', (
    tester,
  ) async {
    final app = await open(tester);
    final out = app.clickOutput;
    expect(find.text('1 / 2'), findsOneWidget);

    await hold(tester, LogicalKeyboardKey.pageDown, const Duration(seconds: 1));
    expect(out.plays, hasLength(1));
    expect(find.text('1 / 2'), findsOneWidget, reason: 'it does not turn');

    await hold(tester, LogicalKeyboardKey.pageDown, const Duration(seconds: 1));
    expect(out.stops, hasLength(1));
    expect(find.text('1 / 2'), findsOneWidget);

    // A short press turns when released.
    await hold(
      tester,
      LogicalKeyboardKey.pageDown,
      const Duration(milliseconds: 100),
    );
    expect(find.text('2 / 2'), findsOneWidget);
    expect(out.plays, hasLength(1));
    await app.dispose(tester);
  });

  testWidgets('Enter starts and stops the beat', (tester) async {
    final app = await open(tester);
    final out = app.clickOutput;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(out.plays, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(out.stops, hasLength(1));
    expect(find.text('1 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Space turns forward unless it is chosen for the beat', (
    tester,
  ) async {
    final app = await open(tester);
    await hold(
      tester,
      LogicalKeyboardKey.space,
      const Duration(milliseconds: 100),
    );
    expect(find.text('2 / 2'), findsOneWidget);
    expect(app.clickOutput.plays, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('Space starts and stops the beat when chosen (#969)', (
    tester,
  ) async {
    final app = await open(
      tester,
      prefs: const {
        'instrument': 'drums',
        'clickStart': 'manual',
        'spaceStartsBeat': true,
      },
    );
    final out = app.clickOutput;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump();
    expect(out.plays, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 400));
    expect(out.stops, hasLength(1));
    expect(find.text('1 / 2'), findsOneWidget, reason: 'it does not turn');
    // The other forward keys still turn.
    await hold(
      tester,
      LogicalKeyboardKey.pageDown,
      const Duration(milliseconds: 100),
    );
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('without a beat the pedal turns at once, as before', (
    tester,
  ) async {
    final app = await open(tester, prefs: const {'instrument': 'guitar'});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(app.clickOutput.plays, isEmpty);
    await app.dispose(tester);
  });
}
