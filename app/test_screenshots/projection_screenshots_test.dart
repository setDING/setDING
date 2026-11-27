import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/projection/projection_controller.dart';
import 'package:setding/projection/projection_state.dart';
import 'package:setding/ui/live/live_screen.dart';

import '../test/test_app.dart';
import 'screenshot_support.dart';

/// A projection host that only says where it would be reached.
class _Host implements ProjectionHost {
  @override
  bool running = false;

  @override
  Future<void> start(String page) async => running = true;

  @override
  Future<void> stop() async => running = false;

  @override
  void update(ProjectionState state) {}

  @override
  Future<List<Uri>> urls() async => [
    Uri.parse('http://192.168.1.23:8231/p/Xq3vT0kLm9aB2cD4eF6gHw'),
  ];
}

/// The lyrics projection (ADR-0068): the bar in live mode, the links with
/// their QR code and the projection settings (website page, #1171). The
/// projected page itself is rendered by tool/projection-screenshots.sh.
void main() {
  setUpScreenshots();

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('projection live $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final items = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: demoSongSource);
        return [LiveItem.song((await app.songs.getSong(id))!)];
      });
      final host = _Host();
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: LiveScreen(items: items!),
            extra: [
              projectionSupportedProvider.overrideWithValue(true),
              projectionHostProvider.overrideWithValue(() => host),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The controls with the button that starts the projection.
      await tester.tapAt(tester.getRect(find.byType(PageView)).center);
      await shot(tester, '${lang}_63_live_projection_start');
      await tester.tap(find.byKey(const Key('live-project')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_63b_projection_sheet');
      // The sheet closed, the controls hidden: the projection bar on stage.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getRect(find.byType(PageView)).center);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('projection-next')));
      await shot(tester, '${lang}_63c_projection_bar');
      await app.dispose(tester);
    });
  }

  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('projection settings $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'projectionSecondLanguage': lang == 'de' ? 'en' : 'de',
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            extra: [projectionSupportedProvider.overrideWithValue(true)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-live')));
      await tester.pumpAndSettle();
      final section = find.byKey(const Key('settings-projection'));
      await tester.scrollUntilVisible(section, 200);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Scrollable.ensureVisible(tester.element(section)),
      );
      await shot(tester, '${lang}_63d_settings_projection');
      // Turning pages moves the slides (#1181), switched on.
      final turns = find.byKey(const Key('settings-projection-turns-slides'));
      await tester.scrollUntilVisible(turns, 200);
      await tester.pumpAndSettle();
      await tester.tap(turns);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Scrollable.ensureVisible(tester.element(turns), alignment: 0.5),
      );
      await shot(tester, '${lang}_63e_settings_projection_turns');
      await app.dispose(tester);
    });
  }
}
