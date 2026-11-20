import 'package:chordpro/chordpro.dart' show Subdivision;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/audio/metronome.dart';
import 'package:setding/ui/live/live_beat.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'fake_click_output.dart';
import 'test_app.dart';

/// Beat display, count-in, edge flash and tempo on stage of the drummer
/// mode (ADR-0026, #333).
void main() {
  Future<LiveItem> song(
    WidgetTester tester,
    TestApp app,
    String title, {
    String meta = '{tempo: 120}\n{time: 4/4}\n',
  }) async => (await tester.runAsync(() async {
    final id = await app.songs.createSong(
      source: '{title: $title}\n$meta[G]Line one [C]and two',
    );
    return LiveItem.song((await app.songs.getSong(id))!, setItemId: title);
  }))!;

  Future<(TestApp, List<LiveItem>)> open(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    List<String?>? metas,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final items = [
      for (final (i, meta) in (metas ?? const <String?>[null, null]).indexed)
        meta == null
            ? await song(tester, app, 'Song ${i + 1}')
            : await song(tester, app, 'Song ${i + 1}', meta: meta),
    ];
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    return (app, items);
  }

  /// Opens or closes a menu and lets the database answer.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Moves the audio clock to [ms] after the first beat of the latest bar
  /// played and draws a frame.
  Future<void> at(WidgetTester tester, FakeClickOutput out, int ms) async {
    out.time = out.plays.last.at + Duration(milliseconds: ms);
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('drums: counts in automatically, then the dots follow', (
    tester,
  ) async {
    final (app, _) = await open(tester, prefs: {'instrument': 'drums'});
    final out = app.clickOutput;
    expect(out.plays, hasLength(1));

    await at(tester, out, 0);
    expect(find.text('1'), findsWidgets);
    expect(find.byKey(const Key('count-in-number')), findsOneWidget);
    expect(find.text('Bar 1 of 2'), findsOneWidget);
    await at(tester, out, 500);
    expect(
      tester.widget<Text>(find.byKey(const Key('count-in-number'))).data,
      '2',
    );
    await at(tester, out, 2500);
    expect(find.text('Bar 2 of 2'), findsOneWidget);

    // After two bars of 4/4 at 120 BPM the song starts: no count-in.
    await at(tester, out, 4000);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('count-in-number')), findsNothing);
    expect(find.byKey(const Key('beat-dots')), findsOneWidget);
    await at(tester, out, 4500);
    expect(find.byKey(const Key('beat-dot-lit')), findsOneWidget);
    expect(find.byKey(const Key('edge-flash-on')), findsOneWidget);
    await at(tester, out, 4800);
    expect(find.byKey(const Key('beat-dot-lit')), findsNothing);
    expect(find.byKey(const Key('edge-flash-on')), findsNothing);

    // The next song stops the beat and counts in again (automatic start).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(out.stops.first.handle, 'handle-0');
    expect(out.plays, hasLength(2));
    await app.dispose(tester);
  });

  testWidgets('manual start: a tap on the tempo starts and stops the beat', (
    tester,
  ) async {
    final (app, _) = await open(
      tester,
      prefs: {'instrument': 'guitar', 'beatDisplay': true, 'click': true},
    );
    final out = app.clickOutput;
    expect(out.plays, isEmpty);
    expect(find.byKey(const Key('beat-dots')), findsOneWidget);
    expect(find.byKey(const Key('edge-flash-on')), findsNothing);

    await tester.tap(find.byKey(const Key('stage-tempo-button')));
    await tester.pump();
    await tester.pump();
    expect(out.plays, hasLength(1));
    await at(tester, out, 10);
    expect(find.byKey(const Key('count-in-number')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stage-tempo-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(out.stops, hasLength(1));
    expect(find.byKey(const Key('count-in-number')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('no beat for a song without a tempo or with the beat off', (
    tester,
  ) async {
    final (app, _) = await open(
      tester,
      prefs: {'instrument': 'drums'},
      metas: ['{time: 4/4}\n'],
    );
    expect(app.clickOutput.plays, isEmpty);
    expect(find.byKey(const Key('beat-dots')), findsNothing);
    expect(find.byKey(const Key('stage-tempo-button')), findsNothing);
    await app.dispose(tester);

    final (guitar, _) = await open(tester, prefs: {'instrument': 'guitar'});
    expect(find.byKey(const Key('beat-dots')), findsNothing);
    expect(find.byKey(const Key('stage-tempo-button')), findsNothing);
    expect(find.text('120 BPM'), findsOneWidget);
    await guitar.dispose(tester);
  });

  testWidgets('tempo on stage: faster, slower, back; marked in the header', (
    tester,
  ) async {
    final (app, _) = await open(
      tester,
      prefs: {'instrument': 'drums', 'clickStart': 'manual'},
    );
    // The middle of the screen, also beside the wide song map's panel.
    final center = tester.getCenter(find.byType(LiveScreen));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.byKey(const Key('stage-tempo-controls')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tempo-faster')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tempo-faster')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-tempo')),
        matching: find.text('122 BPM *'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tempo-slower')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('stage-tempo-value'))).data,
      '121 BPM',
    );

    // Started with the changed tempo.
    await tester.tap(find.byKey(const Key('beat-toggle')));
    await tester.pump();
    await tester.pump();
    final metronome = ProviderScope.containerOf(
      tester.element(find.byType(LiveScreen)),
    ).read(metronomeProvider);
    expect(metronome.tempo.value, 121);

    await tester.tap(find.byKey(const Key('tempo-reset')));
    await tester.pump();
    await tester.pump();
    expect(find.text('120 BPM *'), findsNothing);
    expect(metronome.tempo.value, 120);
    await tester.tap(find.byKey(const Key('beat-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await app.dispose(tester);
  });

  testWidgets('grouping and subdivisions of the click per song, stored in '
      'the personal adjustments (#698)', (tester) async {
    final (app, items) = await open(
      tester,
      prefs: {'instrument': 'drums', 'clickStart': 'manual'},
      metas: ['{tempo: 120}\n{time: 7/8}\n{x_time_grouping: 2+2+3}\n'],
    );
    final out = app.clickOutput;
    final center = tester.getCenter(find.byType(LiveScreen));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('2+2+3'), findsWidgets);

    await tester.tap(find.byKey(const Key('click-grouping-button')));
    await settle(tester);
    expect(find.text('As in the song (2+2+3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('click-grouping-3+2+2')));
    await settle(tester);
    final songId = items.single.song!.id;
    final overlay = await tester.runAsync(() => app.songs.getOverlay(songId));
    expect(overlay!.clickGrouping, '3+2+2');

    // Started with the personal grouping.
    await tester.tap(find.byKey(const Key('beat-toggle')));
    await tester.pump();
    await tester.pump();
    final metronome = ProviderScope.containerOf(
      tester.element(find.byType(LiveScreen)),
    ).read(metronomeProvider);
    expect(metronome.timeline!.meter.groups, [3, 2, 2]);
    expect(out.plays, hasLength(1));

    // Sixteenths while it runs: a new bar from the next bar line on.
    out.time = out.plays.first.at + const Duration(milliseconds: 500);
    await tester.tap(find.byKey(const Key('click-subdivision-button')));
    await settle(tester);
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const Key('click-subdivision-eighths')),
          )
          .onPressed,
      isNull,
      reason: 'eighths are the beats of 7/8',
    );
    await tester.tap(find.byKey(const Key('click-subdivision-sixteenths')));
    await settle(tester);
    expect(
      (await tester.runAsync(() => app.songs.getOverlay(songId)))!
          .clickSubdivision,
      Subdivision.sixteenths,
    );
    await tester.pump();
    expect(out.plays, hasLength(2));
    expect(
      out.plays.last.at,
      out.plays.first.at + metronome.timeline!.barLength(120),
    );

    // Back to the song's grouping.
    await tester.tap(find.byKey(const Key('click-grouping-button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('click-grouping-song')));
    await settle(tester);
    await tester.pump();
    expect(metronome.timeline!.meter.groups, [2, 2, 3]);
    await tester.tap(find.byKey(const Key('beat-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await app.dispose(tester);
  });

  test('tap tempo: the mean of the last taps, a pause starts again', () {
    final tap = TapTempo();
    Duration ms(int v) => Duration(milliseconds: v);
    expect(tap.add(ms(0)), isNull);
    expect(tap.add(ms(500)), 120);
    expect(tap.add(ms(1020)), 118);
    // A pause of more than two seconds starts again.
    expect(tap.add(ms(4000)), isNull);
    expect(tap.add(ms(4600)), 100);
    // Only the last five taps count.
    for (var t = 5200; t <= 9000; t += 600) {
      tap.add(ms(t));
    }
    expect(tap.add(ms(9400 + 0)), isNotNull);
  });

  group('in the background (#424)', () {
    Future<void> hide(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
    }

    Future<void> show(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }

    testWidgets('the beat and the click stop by default', (tester) async {
      final (app, _) = await open(tester, prefs: {'instrument': 'drums'});
      final out = app.clickOutput;
      expect(out.plays, hasLength(1));
      expect(out.stops, isEmpty);

      await hide(tester);
      expect(out.stops, hasLength(1));
      await show(tester);
      // Not started again by itself.
      expect(out.plays, hasLength(1));
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
      await app.dispose(tester);
    });

    testWidgets('they keep playing when the settings say so', (tester) async {
      final (app, _) = await open(
        tester,
        prefs: {'instrument': 'drums', 'clickInBackground': 'keepPlaying'},
      );
      final out = app.clickOutput;
      expect(out.plays, hasLength(1));

      await hide(tester);
      expect(out.stops, isEmpty);
      await show(tester);
      expect(out.stops, isEmpty);
      await app.dispose(tester);
    });
  });
}
