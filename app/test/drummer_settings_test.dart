import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// Beat and click settings of the drummer mode (ADR-0026, #334).
void main() {
  group('defaults follow the instrument', () {
    test('drums: beat, click, edge flash, song map, automatic start', () {
      const s = AppSettings(instrument: 'drums');
      expect(s.isDrums, isTrue);
      expect(s.showBeat, isTrue);
      expect(s.playClick, isTrue);
      expect(s.showEdgeFlash, isTrue);
      expect(s.showSongMap, isTrue);
      expect(s.beatStart, ClickStart.automatic);
      expect(s.beatEnabled, isTrue);
      expect(AppSettings.instruments, contains('drums'));
    });

    test('other instruments: off, manual start, no drum-only features', () {
      const s = AppSettings(instrument: 'guitar');
      expect(s.showBeat, isFalse);
      expect(s.playClick, isFalse);
      expect(s.beatStart, ClickStart.manual);
      expect(s.beatEnabled, isFalse);
      final on = s.copyWith(
        beatDisplay: true,
        click: true,
        edgeFlash: true,
        songMap: true,
      );
      expect(on.showBeat, isTrue);
      expect(on.playClick, isTrue);
      expect(on.showEdgeFlash, isFalse);
      expect(on.showSongMap, isFalse);
    });

    test('a choice made for drums can switch a default off', () {
      final s = const AppSettings(
        instrument: 'Drums ',
      ).copyWith(click: false, songMap: false, clickStart: ClickStart.manual);
      expect(s.playClick, isFalse);
      expect(s.showSongMap, isFalse);
      expect(s.beatStart, ClickStart.manual);
    });
  });

  test('stored as JSON; unset choices stay unset', () {
    final unset = const AppSettings(instrument: 'drums').toJson();
    expect(unset.containsKey('click'), isFalse);
    expect(unset.containsKey('clickStart'), isFalse);
    expect(
      AppSettings.fromJson(unset).clickInBackground,
      ClickInBackground.stop,
    );

    final json = const AppSettings(instrument: 'drums')
        .copyWith(
          click: false,
          clickStart: ClickStart.manual,
          clickDuration: ClickDuration.countIn,
          clickInBackground: ClickInBackground.keepPlaying,
          countInBars: 1,
          clickVolume: 0.5,
          clickAccent: false,
          clickSound: ClickSound.woodblock,
          clickSubdivision: true,
          audioLatencyMs: 180,
          songMap: false,
        )
        .toJson();
    final loaded = AppSettings.fromJson(json);
    expect(loaded.playClick, isFalse);
    expect(loaded.beatStart, ClickStart.manual);
    expect(loaded.clickDuration, ClickDuration.countIn);
    expect(loaded.clickInBackground, ClickInBackground.keepPlaying);
    expect(loaded.countInBars, 1);
    expect(loaded.clickVolume, 0.5);
    expect(loaded.clickAccent, isFalse);
    expect(loaded.clickSound, ClickSound.woodblock);
    expect(loaded.clickSubdivision, isTrue);
    expect(loaded.audioLatencyMs, 180);
    expect(loaded.showSongMap, isFalse);
    expect(loaded.beatDisplay, isNull);
    expect(loaded.showBeat, isTrue);
  });

  test('personal, except volume and audio delay (ADR-0027)', () {
    expect(AppSettings.scopes['click'], SettingSyncScope.personal);
    expect(AppSettings.scopes['clickStart'], SettingSyncScope.personal);
    expect(AppSettings.scopes['songMap'], SettingSyncScope.personal);
    expect(AppSettings.scopes['clickVolume'], SettingSyncScope.device);
    expect(AppSettings.scopes['audioLatencyMs'], SettingSyncScope.device);
  });

  test('out-of-range or wrong values give the defaults', () {
    final loaded = AppSettings.fromJson({
      'countInBars': 9,
      'clickVolume': 3.0,
      'audioLatencyMs': 5000,
      'clickStart': 'sometimes',
      'click': 'yes',
    });
    expect(loaded.countInBars, 2);
    expect(loaded.clickVolume, 1.0);
    expect(loaded.audioLatencyMs, AppSettings.maxAudioLatencyMs);
    expect(loaded.clickStart, isNull);
    expect(loaded.click, isNull);
  });

  testWidgets('beat and click among the musician settings, volume and '
      'delay on the device', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'guitar'},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();

    Future<void> category(String name) async {
      await tester.tap(find.byKey(Key('settings-category-$name')));
      await tester.pumpAndSettle();
    }

    Future<void> show(String key, {double delta = 200}) async {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        delta,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    await category('musician');
    await show('settings-click');
    expect(find.byKey(const Key('settings-song-map')), findsNothing);
    expect(find.byKey(const Key('settings-edge-flash')), findsNothing);
    await tester.tap(find.byKey(const Key('settings-click')));
    await tester.pumpAndSettle();
    expect(app.personal()['click'], isTrue);

    await category('live');
    await show('settings-audio-latency');
    expect(find.byKey(const Key('settings-click-volume')), findsOneWidget);
    expect(find.text('0 ms'), findsOneWidget);

    await category('musician');
    await tester.tap(find.text('Drums'));
    await tester.pumpAndSettle();
    expect(app.personal()['instrument'], 'drums');
    await show('settings-song-map');
    await show('settings-edge-flash', delta: -200);
    expect(find.byKey(const Key('settings-edge-flash')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the audio delay is measured by tapping along (#332)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'drums'},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    final measure = find.byKey(const Key('settings-audio-latency-measure'));
    await tester.scrollUntilVisible(
      measure,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(measure);
    await tester.pumpAndSettle();

    final out = app.clickOutput;
    final start = out.plays.single.at;
    expect(out.plays.single.until, isNull);
    // 100 BPM: a beat every 600 ms; the taps come 120 ms after the beats.
    for (var i = 1; i <= 10; i++) {
      out.time = start + Duration(milliseconds: i * 600 + 120);
      await tester.tap(find.byKey(const Key('latency-tap')));
      await tester.pump();
    }
    expect(find.text('Measured: 120 ms'), findsOneWidget);
    await tester.tap(find.byKey(const Key('latency-apply')));
    await tester.pumpAndSettle();
    expect(app.prefs.getInt('audioLatencyMs'), 120);
    expect(out.stops, isNotEmpty);
    await app.dispose(tester);
  });
}
