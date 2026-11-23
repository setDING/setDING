import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'test_app.dart';

/// Song map for drummers in live mode (ADR-0026, #336).
void main() {
  const first = '''
{title: One}
{tempo: 96}
{time: 6/8}
{x_sequence: I, V, C x2, V, C}
{start_of_verse: Intro}
{comment-drums: Toms, four bars}
{end_of_verse}
{start_of_verse}
[G]Amazing grace
{end_of_verse}
{start_of_chorus}
{comment-drums: Crash on 1}
[C]Through many dangers
{end_of_chorus}
{start_of_verse}
[G]Twas grace that taught
{end_of_verse}
''';
  const second = '{title: Two}\n{tempo: 100}\n{time: 4/4}\n[D]Two';

  Future<TestApp> open(
    WidgetTester tester,
    Map<String, Object> prefs, {
    bool landscape = true,
    bool phone = false,
  }) async {
    if (phone) {
      tester.view.physicalSize = landscape
          ? const Size(844, 390)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    } else {
      useTabletSize(tester, landscape: landscape);
    }
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final source in [first, second]) {
        final id = await app.songs.createSong(source: source);
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    return app;
  }

  testWidgets('drums: the parts with cues and drum notes, no chords', (
    tester,
  ) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    });
    expect(find.byKey(const Key('song-map')), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Toms, four bars'), findsOneWidget);
    expect(find.text('Chorus ×2'), findsOneWidget);
    expect(find.text('„Amazing grace“'), findsOneWidget);
    expect(find.text('„Twas grace that taught“'), findsOneWidget);
    expect(find.text('Crash on 1'), findsNWidgets(2));
    // No chord sheet.
    expect(find.text('G'), findsNothing);
    // The next song with tempo and time signature.
    expect(find.textContaining('Two · 100 BPM · 4/4'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('not for other instruments, and switchable for drums', (
    tester,
  ) async {
    final guitar = await open(tester, {'instrument': 'guitar'});
    expect(find.byKey(const Key('song-map')), findsNothing);
    expect(find.textContaining('100 BPM'), findsNothing);
    await guitar.dispose(tester);

    final drums = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
      'songMap': false,
    });
    expect(find.byKey(const Key('song-map')), findsNothing);
    await drums.dispose(tester);
  });

  testWidgets('wide: beat large and the set on the left, a tap turns (#357)', (
    tester,
  ) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    });
    await tester.pump();
    expect(find.byKey(const Key('drum-panel')), findsOneWidget);
    expect(find.byKey(const Key('large-beat')), findsOneWidget);
    // The beat takes a third of the panel's height, the set two (#968).
    final panel = tester.getRect(find.byKey(const Key('drum-panel')));
    final setTop = tester.getRect(find.byKey(const Key('drum-set-list'))).top;
    expect((setTop - 1 - panel.top) / panel.height, closeTo(1 / 3, 0.01));
    // The dots are in the panel, not beside the title.
    expect(
      find.descendant(
        of: find.byKey(const Key('large-beat')),
        matching: find.byKey(const Key('beat-dots')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-info')),
        matching: find.byKey(const Key('beat-dots')),
      ),
      findsNothing,
    );
    // The set with tempo and time signature; 6/8 at 96 BPM first.
    expect(
      find.descendant(
        of: find.byKey(const Key('drum-set-0')),
        matching: find.text('96 BPM · 6/8'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('drum-set-1')),
        matching: find.text('100 BPM · 4/4'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drum-set-1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('drum-set-1'))).selected,
      isTrue,
    );

    // The large start button starts the beat of the current song.
    await tester.tap(find.byKey(const Key('large-beat-toggle')));
    await tester.pump();
    await tester.pump();
    expect(app.clickOutput.plays, hasLength(1));
    await tester.tap(find.byKey(const Key('large-beat-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await app.dispose(tester);
  });

  testWidgets('tablet in portrait: the drum panel with the switch, the dots '
      'only in the large beat (#974)', (tester) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    }, landscape: false);
    await tester.pump();
    expect(find.byKey(const Key('drum-panel')), findsOneWidget);
    expect(find.byKey(const Key('drum-panel-view')), findsOneWidget);
    expect(find.byKey(const Key('drum-set-list')), findsOneWidget);
    expect(find.byKey(const Key('beat-dots')), findsOneWidget);
    // The beat a third of the height, the set two.
    final panel = tester.getRect(find.byKey(const Key('drum-panel')));
    final switchTop = tester
        .getRect(find.byKey(const Key('drum-panel-view')))
        .top;
    expect((switchTop - 8 - panel.top) / panel.height, closeTo(1 / 3, 0.01));
    // Beside the set the pedal turns songs.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    // The second song has no parts: the song map says so.
    await tester.tap(find.text('Song map'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('song-map-empty')), findsOneWidget);
    expect(find.byKey(const Key('drum-set-list')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('tablet in portrait: the pedal scrolls a long song map, then '
      'turns (#974)', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        'instrument': 'drums',
        'clickStart': 'manual',
        'drumPanelView': 'songMap',
      },
    );
    const long = """{title: Long}
{tempo: 100}
{x_sequence: V, C, V, C, V, C, V, C, V, C, V, C, V, C}
{start_of_verse}
{comment-drums: Hi-hat}
[G]Verse line
{end_of_verse}
{start_of_chorus}
{comment-drums: Ride}
[C]Chorus line
{end_of_chorus}
""";
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final source in [long, second]) {
        final id = await app.songs.createSong(source: source);
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    final map = find.byKey(const Key('song-map'));
    expect(map, findsOneWidget);
    final scrollable = find.descendant(
      of: map,
      matching: find.byType(Scrollable),
    );
    double offset() =>
        tester.state<ScrollableState>(scrollable.first).position.pixels;
    expect(offset(), 0);

    // The first press scrolls the song map, the song stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));
    expect(find.text('1 / 2'), findsOneWidget);

    // At its end the pedal turns to the next song.
    for (var i = 0; i < 20 && find.text('1 / 2').evaluate().isNotEmpty; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
    }
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('wide: the tap zones are thirds of the whole screen (#363)', (
    tester,
  ) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    });
    await tester.pump();
    final screen = tester.getRect(find.byType(LiveScreen));
    final panel = tester.getRect(find.byKey(const Key('drum-panel')));
    expect(panel.right, greaterThan(screen.width * 0.3));

    // The middle of the screen shows the control bar.
    await tester.tapAt(screen.center);
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tapAt(screen.center);
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNothing);

    // The right third turns forward: the song map scrolls first if it
    // does not fit (as a song does, ADR-0007), then the next song.
    for (var i = 0; i < 5 && find.text('2 / 2').evaluate().isEmpty; i++) {
      await tester.tapAt(Offset(screen.width * 0.85, screen.center.dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('2 / 2'), findsOneWidget);

    // An empty area of the panel in the left third turns back.
    await tester.tapAt(Offset(screen.left + 12, panel.top + 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 / 2'), findsOneWidget);

    // The set list keeps its taps.
    await tester.tap(find.byKey(const Key('drum-set-1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('phone portrait: beat above, the set below, no song map (#421)', (
    tester,
  ) async {
    final app = await open(
      tester,
      {'instrument': 'drums', 'clickStart': 'manual'},
      landscape: false,
      phone: true,
    );
    await tester.pump();
    expect(find.byKey(const Key('drum-panel')), findsOneWidget);
    expect(find.byKey(const Key('song-map')), findsNothing);
    final beat = tester.getRect(find.byKey(const Key('large-beat')));
    final set = tester.getRect(find.byKey(const Key('drum-set-list')));
    expect(beat.bottom, lessThanOrEqualTo(set.top));
    // The beat takes a third of the height, the set two (#965).
    final panel = tester.getRect(find.byKey(const Key('drum-panel')));
    final switchTop = tester
        .getRect(find.byKey(const Key('drum-panel-view')))
        .top;
    expect((switchTop - 8 - panel.top) / panel.height, closeTo(1 / 3, 0.01));
    // The panel is the whole stage.
    final screen = tester.getRect(find.byType(LiveScreen));
    expect(
      tester.getRect(find.byKey(const Key('drum-panel'))).width,
      screen.width,
    );
    // The dots only in the large beat.
    expect(find.byKey(const Key('beat-dots')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // A tap on a song of the set turns to it.
    await tester.tap(find.byKey(const Key('drum-set-1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    // The page turner turns songs, there is no song map to scroll.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    // The middle of an empty area shows the control bar, to leave.
    await tester.tapAt(Offset(screen.center.dx, beat.top + 4));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('phone landscape: beat left, the set right, no next line '
      '(#421)', (tester) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    }, phone: true);
    await tester.pump();
    expect(find.byKey(const Key('drum-panel')), findsOneWidget);
    expect(find.byKey(const Key('song-map')), findsNothing);
    final beat = tester.getRect(find.byKey(const Key('large-beat')));
    final set = tester.getRect(find.byKey(const Key('drum-set-list')));
    expect(beat.right, lessThanOrEqualTo(set.left));
    // The set shows what comes next: no line below.
    expect(find.byKey(const Key('live-info')), findsNothing);
    expect(find.textContaining('Next'), findsNothing);

    await tester.tap(find.byKey(const Key('drum-set-1')));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.byKey(const Key('drum-set-1'))).selected,
      isTrue,
    );
    await app.dispose(tester);
  });
  testWidgets('phone portrait: the segmented button switches the set for the '
      'song map, the beat stays (#952)', (tester) async {
    final app = await open(
      tester,
      {'instrument': 'drums', 'clickStart': 'manual'},
      landscape: false,
      phone: true,
    );
    await tester.pump();
    // The set by default.
    expect(find.byKey(const Key('drum-panel-view')), findsOneWidget);
    expect(find.byKey(const Key('drum-set-list')), findsOneWidget);
    expect(find.byKey(const Key('song-map')), findsNothing);

    await tester.tap(find.text('Song map'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('drum-set-list')), findsNothing);
    expect(find.byKey(const Key('song-map')), findsOneWidget);
    expect(find.text('„Amazing grace“'), findsOneWidget);
    expect(find.text('Toms, four bars'), findsOneWidget);
    // The beat stays above, its dots only there.
    final beat = tester.getRect(find.byKey(const Key('large-beat')));
    final map = tester.getRect(find.byKey(const Key('song-map')));
    expect(beat.bottom, lessThanOrEqualTo(map.top));
    expect(find.byKey(const Key('beat-dots')), findsOneWidget);
    // The beat takes a third of the height, the song map two (#961).
    final panel = tester.getRect(find.byKey(const Key('drum-panel')));
    final switchTop = tester
        .getRect(find.byKey(const Key('drum-panel-view')))
        .top;
    expect((switchTop - 8 - panel.top) / panel.height, closeTo(1 / 3, 0.01));
    // Remembered on the device.
    expect(app.prefs.getString('drumPanelView'), 'songMap');

    // The page turner still turns songs: the next song's map.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('„Amazing grace“'), findsNothing);

    // A tap in the middle of the song map shows the control bar.
    final screen = tester.getRect(find.byType(LiveScreen));
    await tester.tapAt(Offset(screen.center.dx, map.center.dy));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a small phone: the beat fits in its third (#961)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        'instrument': 'drums',
        'clickStart': 'manual',
        'drumPanelView': 'songMap',
      },
    );
    final items = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: first);
      return [LiveItem.song((await app.songs.getSong(id))!)];
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    // No overflow (the test fails on one); the beat stays above the map.
    expect(find.byKey(const Key('large-beat-toggle')), findsOneWidget);
    final toggle = tester.getRect(find.byKey(const Key('large-beat-toggle')));
    final view = tester.getRect(find.byKey(const Key('drum-panel-view')));
    expect(toggle.bottom, lessThanOrEqualTo(view.top));
    await app.dispose(tester);
  });

  testWidgets('phone landscape: the song map right of the beat, its tap zones '
      'are thirds of the stage (#952)', (tester) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
      'drumPanelView': 'songMap',
    }, phone: true);
    await tester.pump();
    final beat = tester.getRect(find.byKey(const Key('large-beat')));
    final map = tester.getRect(find.byKey(const Key('song-map')));
    expect(beat.right, lessThanOrEqualTo(map.left));
    expect(find.byKey(const Key('drum-set-list')), findsNothing);
    // The right third of the stage turns forward, also on the song map.
    final screen = tester.getRect(find.byType(LiveScreen));
    await tester.tapAt(Offset(screen.width * 0.9, map.center.dy));
    await tester.pump();
    await tester.pump();
    expect(find.text('„Amazing grace“'), findsNothing);
    // The left part of the song map is in the middle third: the controls.
    await tester.tapAt(Offset(map.left + 20, map.center.dy));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
    // Back to the set.
    await tester.tap(find.text('Set'));
    await tester.pump();
    expect(find.byKey(const Key('drum-set-list')), findsOneWidget);
    expect(find.byKey(const Key('song-map')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('wide screens keep the song map beside the panel, without the '
      'switch (#952)', (tester) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    });
    expect(find.byKey(const Key('song-map')), findsOneWidget);
    expect(find.byKey(const Key('drum-panel-view')), findsNothing);
    await app.dispose(tester);
  });
}
