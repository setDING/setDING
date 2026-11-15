import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/demo_song.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/render/render_cache.dart';
import 'package:realchord/ui/render/song_view.dart';

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

    // The next song is measured once; going back uses the cached fit.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    final second = debugMeasureBlocksCalls;
    expect(second, greaterThan(first));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(debugMeasureBlocksCalls, second);
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
