import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordpro/chordpro.dart' show ChordStyle;
import 'package:setding/settings/settings.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/render_cache.dart';
import 'package:setding/ui/render/song_view.dart';

import 'test_app.dart';

void main() {
  test('LRU cache keeps the most recently used entries', () {
    final cache = LruCache<int, String>(2);
    var created = 0;
    String get(int key) => cache.get(key, () => '${created++}:$key');
    expect(get(1), '0:1');
    expect(get(2), '1:2');
    expect(get(1), '0:1'); // hit, now the most recent
    expect(get(3), '2:3'); // evicts 2
    expect(get(1), '0:1');
    expect(get(2), '3:2');
  });

  test('LRU cache lookup does not create, but counts as a use', () {
    final cache = LruCache<int, String>(2);
    expect(cache.lookup(1), isNull);
    cache.get(1, () => 'one');
    cache.get(2, () => 'two');
    expect(cache.lookup(1), 'one'); // now the most recent
    cache.get(3, () => 'three'); // evicts 2
    expect(cache.lookup(2), isNull);
    expect(cache.lookup(1), 'one');
    expect(cache.lookup(3), 'three');
  });

  test('cached parsing returns the same song for the same input', () {
    const source = '{title: Cached}\n[C]la';
    final a = parseChordProCached(source);
    expect(identical(parseChordProCached(source), a), isTrue);
    expect(identical(parseChordProCached('$source\n'), a), isFalse);
  });

  testWidgets('live mode does not measure a song again on rebuilds', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final source in [demoSongSource, '{title: Second}\n[G]la la']) {
        final id = await app.songs.createSong(source: source);
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final first = debugMeasureBlocksCalls;
    expect(first, greaterThan(0));

    // Showing and hiding the controls neither changes the page size nor
    // measures again.
    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit live mode'), findsOneWidget);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(debugMeasureBlocksCalls, first);

    // The next song is measured once, ahead of the turn (issue #262):
    // turning to it and going back use the cached fits.
    final size = tester.getSize(find.byType(PageView));
    final topLeft = tester.getTopLeft(find.byType(PageView));
    // The demo song may be split into pages: those are turned first.
    Future<void> turnTo(String position, double x) async {
      for (var i = 0; i < 5 && find.text(position).evaluate().isEmpty; i++) {
        await tester.tapAt(topLeft + Offset(size.width * x, size.height / 2));
        await tester.pumpAndSettle();
      }
      expect(find.text(position), findsOneWidget);
    }

    await turnTo('2 / 2', 0.9);
    expect(debugMeasureBlocksCalls, first);
    await turnTo('1 / 2', 0.1);
    expect(debugMeasureBlocksCalls, first);
    await app.dispose(tester);
  });

  testWidgets('live mode measures again when the chord style changes', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source: '{title: Style}\n[Ami7]la la [Cmaj7]la',
      );
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();
    final before = debugMeasureBlocksCalls;
    expect(find.text('Ami7'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiveScreen)),
    );
    await tester.runAsync(
      () => container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(chordStyle: ChordStyle.standard)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Am7'), findsOneWidget);
    expect(debugMeasureBlocksCalls, greaterThan(before));
    await app.dispose(tester);
  });

  testWidgets('scrolling with two columns measures a song once', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'autoFit': false, 'columns': 'two'},
    );
    final items = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: demoSongSource);
      return [LiveItem.song((await app.songs.getSong(id))!)];
    }))!;
    final before = debugMeasureBlocksCalls;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pumpAndSettle();
    final measured = debugMeasureBlocksCalls;
    expect(measured, before + 1);

    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(debugMeasureBlocksCalls, measured);
    await app.dispose(tester);
  });
}
