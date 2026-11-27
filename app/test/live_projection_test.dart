import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setding/projection/projection_controller.dart';
import 'package:setding/projection/projection_state.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'projection_controller_test.dart' show FakeProjectionHost;
import 'test_app.dart';

/// Starting the lyrics projection from live mode and following it
/// (ADR-0068 §2, §6–8, #1169).
void main() {
  late FakeProjectionHost host;
  late TestApp app;

  /// [verses] verses of four lines each: more than one page on a tablet.
  String versesSong(int verses) =>
      '{title: Long}\n{copyright: 2026 Band}\n${List.generate(verses, (v) => '{start_of_verse}\n${List.generate(4, (l) => '[C]Verse ${v + 1} line ${l + 1} la la [G]la').join('\n')}\n{end_of_verse}').join('\n')}';

  Future<void> start(
    WidgetTester tester, {
    required List<String?> sources,
    bool supported = true,
    Map<String, Object> prefs = const {},
    Future<void> Function(TestApp app, List<String> ids)? prepare,
  }) async {
    useTabletSize(tester);
    host = FakeProjectionHost(
      addresses: [Uri.parse('http://192.168.1.5:8231/p/token')],
    );
    app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      final ids = <String>[];
      for (final source in sources) {
        if (source == null) continue;
        ids.add(await app.songs.createSong(source: source));
      }
      await prepare?.call(app, ids);
      var next = 0;
      for (final source in sources) {
        if (source == null) {
          items.add(const LiveItem.marker(MarkerIcons.breakIcon, 'Break'));
          continue;
        }
        items.add(LiveItem.song((await app.songs.getSong(ids[next++]))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(
      app.build(
        home: LiveScreen(items: items),
        extra: [
          projectionSupportedProvider.overrideWithValue(supported),
          projectionHostProvider.overrideWithValue(() => host),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAt(WidgetTester tester, double x) async {
    final page = tester.getRect(find.byType(PageView));
    // Halfway down: the control bar at the bottom keeps its taps.
    await tester.tapAt(Offset(page.left + page.width * x, page.center.dy));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  Future<void> startProjection(WidgetTester tester) async {
    await tapAt(tester, 0.5); // the controls
    await tester.tap(find.byKey(const Key('live-project')));
    await tester.pumpAndSettle();
  }

  Object? lines() => host.last['lines'];

  testWidgets('starts from the controls, shows the links and follows the '
      'set', (tester) async {
    await start(
      tester,
      sources: [
        '{title: One}\n{copyright: 2026 One}\n{start_of_verse}\n[C]First song\n{end_of_verse}\n{start_of_chorus}\nIts chorus\n{end_of_chorus}',
        null,
        '{title: Two}\n[D]Second song',
      ],
    );
    expect(find.byKey(const Key('projection-bar')), findsNothing);
    await startProjection(tester);

    // The page with the language and its label, then the links.
    expect(host.starts, 1);
    expect(host.page, contains('<html lang="en">'));
    expect(host.page, contains('title="Full screen"'));
    expect(find.byKey(const Key('projection-qr')), findsOneWidget);
    expect(find.text('http://192.168.1.5:8231/p/token'), findsOneWidget);
    expect(
      find.text('http://192.168.1.5:8231/p/token/lower-third'),
      findsOneWidget,
    );
    await closeSheet(tester);

    expect(find.byKey(const Key('projection-bar')), findsOneWidget);
    expect(lines(), ['First song']);
    expect(host.last['copyright'], '2026 One');
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byKey(const Key('projection-no-copyright')), findsNothing);

    // By hand: next slide, then the song is manual.
    expect(find.byKey(const Key('projection-follow')), findsNothing);
    await tester.tap(find.byKey(const Key('projection-next')));
    await tester.pumpAndSettle();
    expect(lines(), ['Its chorus']);
    expect(find.byKey(const Key('projection-follow')), findsOneWidget);

    // Blank wins until switched off.
    await tester.tap(find.byKey(const Key('projection-blank')));
    await tester.pumpAndSettle();
    expect(host.last['blank'], isTrue);
    await tester.tap(find.byKey(const Key('projection-blank')));
    await tester.pumpAndSettle();
    expect(lines(), ['Its chorus']);

    // The break is blank; the next song starts at its first slide and
    // shows the hint about the missing copyright.
    await tapAt(tester, 0.9);
    expect(host.last['blank'], isTrue);
    await tapAt(tester, 0.9);
    expect(lines(), ['Second song']);
    expect(find.byKey(const Key('projection-follow')), findsNothing);
    expect(find.byKey(const Key('projection-no-copyright')), findsOneWidget);

    // Stop: the bar goes, the button comes back.
    await tester.tap(find.byKey(const Key('projection-links')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('projection-stop')));
    await tester.pumpAndSettle();
    expect(host.running, isFalse);
    expect(find.byKey(const Key('projection-bar')), findsNothing);
    expect(find.byKey(const Key('live-project')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a page turn within a song moves the projection to the '
      'section at its top', (tester) async {
    await start(tester, sources: [versesSong(14)]);
    await startProjection(tester);
    await closeSheet(tester);
    expect((lines()! as List).first, 'Verse 1 line 1 la la la');

    // Close the controls, then turn a page of the song.
    await tapAt(tester, 0.5);
    await tapAt(tester, 0.9);
    final first = (lines()! as List).first as String;
    expect(first, isNot('Verse 1 line 1 la la la'));
    expect(first, endsWith('line 1 la la la'));
    expect(find.byKey(const Key('projection-follow')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('settings: the look, and the version of the song in the second '
      'language beside it (#1170)', (tester) async {
    await start(
      tester,
      // Only the first song is played; the second is its English version.
      sources: [
        '{title: Gott}\n{start_of_verse}\nGrosser Gott\n{end_of_verse}',
        '{title: God}\n{start_of_verse}\nHoly God\n{end_of_verse}',
      ],
      prefs: {'projectionTheme': 'light', 'projectionSecondLanguage': 'en'},
      prepare: (app, ids) async {
        await app.songs.setLanguage(ids[0], 'de');
        await app.songs.setLanguage(ids[1], 'en');
        await app.songs.setWorkId(ids[0], 'work-1');
        await app.songs.setWorkId(ids[1], 'work-1');
      },
    );
    await startProjection(tester);
    await closeSheet(tester);
    // The version is looked up in the database after the song is shown.
    for (var i = 0; i < 20 && host.last['second'] == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(lines(), ['Grosser Gott']);
    expect(host.last['second'], ['Holy God']);
    expect((host.last['style']! as Map)['theme'], 'light');

    // A change in the settings reaches the projection at once.
    await tester.runAsync(
      () =>
          ProviderScope.containerOf(tester.element(find.byType(LiveScreen)))
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(projectionAlign: ProjectionAlign.left)),
    );
    await tester.pumpAndSettle();
    expect((host.last['style']! as Map)['align'], 'left');
    await app.dispose(tester);
  });

  testWidgets('no projection where the platform cannot serve it', (
    tester,
  ) async {
    await start(tester, sources: ['{title: One}\nLa'], supported: false);
    await tapAt(tester, 0.5);
    expect(find.byKey(const Key('live-project')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('no network: the sheet says how to connect', (tester) async {
    await start(tester, sources: ['{title: One}\nLa']);
    host = FakeProjectionHost();
    // The host is made when the projection starts.
    await startProjection(tester);
    expect(find.byKey(const Key('projection-no-network')), findsOneWidget);
    expect(find.byKey(const Key('projection-qr')), findsNothing);
    await app.dispose(tester);
  });
}
