import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

/// Layout of the song list: sections and columns (#251).
void main() {
  test('rows: a header where a section starts, then songs per row', () {
    List<Object?> rows(List<String?> sections, int columns) => [
      for (final r in songListRows(sections, columns)) r.header ?? r.songs,
    ];
    expect(rows(['A', 'A', 'A', 'B'], 2), [
      'A',
      [0, 1],
      [2],
      'B',
      [3],
    ]);
    expect(rows([null, null, null], 2), [
      [0, 1],
      [2],
    ]);
    expect(rows(['A', 'B'], 1), [
      'A',
      [0],
      'B',
      [1],
    ]);
  });

  test('marked text becomes spans with the hits styled', () {
    const hit = TextStyle(fontWeight: FontWeight.bold);
    final spans = highlightedSpans(
      'a ${hitStart}bc$hitEnd d ${hitStart}e$hitEnd',
      hit,
    );
    expect(
      [for (final s in spans) (s.text, s.style == hit)],
      [('a ', false), ('bc', true), (' d ', false), ('e', true)],
    );
    expect(highlightedSpans('plain', hit).single.text, 'plain');
  });

  testWidgets('a search shows where the lyrics matched', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}\n[G]Sun is shining');
      await app.songs.createSong(source: '{title: Sunday}\n[G]Rain');
    });
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'sun');
    await tester.pump(songSearchDelay);
    await tester.pumpAndSettle();

    // Alpha matched in the lyrics: a snippet; Sunday in the title: none.
    final snippet = find.byKey(const ValueKey('song-lyrics-hit'));
    expect(snippet, findsOneWidget);
    expect(
      find.descendant(
        of: snippet,
        matching: find.text('Sun is shining', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(find.text('Sunday', findRichText: true), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a changed search replaces the list in one step (#297)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}\n[G]Sun is shining');
      await app.songs.createSong(source: '{title: Sunday}\n[G]Rain');
      await app.songs.createSong(source: '{title: Beta}\n[G]Snow');
    });
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    final beta = find.text('Beta', findRichText: true);
    final snippet = find.byKey(const ValueKey('song-lyrics-hit'));
    expect(beta, findsOneWidget);

    // Every frame shows either the whole previous list or the results with
    // their hits highlighted: no progress indicator, no results without
    // highlighting in between.
    void expectOneStep() {
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Alpha', findRichText: true), findsOneWidget);
      expect(snippet.evaluate().length, 1 - beta.evaluate().length);
    }

    for (final text in ['sun', '']) {
      await tester.enterText(find.byType(SearchBar), text);
      await tester.pump(songSearchDelay);
      for (var i = 0; i < 10; i++) {
        expectOneStep();
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expectOneStep();
      expect(beta, text.isEmpty ? findsOneWidget : findsNothing);
    }
    await app.dispose(tester);
  });

  Future<TestApp> start(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}');
      await app.songs.createSong(source: '{title: Another}');
    });
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('wide screens show two songs side by side', (tester) async {
    final app = await start(tester, const Size(1280, 800));
    final a = tester.getTopLeft(find.text('Alpha'));
    final b = tester.getTopLeft(find.text('Another'));
    expect(b.dy, a.dy);
    expect(b.dx, greaterThan(a.dx + 400));
    // The header spans the row, above both songs.
    expect(find.text('A'), findsOneWidget);
    expect(tester.getTopLeft(find.text('A')).dy, lessThan(a.dy));
    await app.dispose(tester);
  });

  testWidgets('the keyboard opening keeps the list as it is (#297)', (
    tester,
  ) async {
    final app = await start(tester, const Size(800, 1280));
    SongTile tile() => tester.widget(find.byType(SongTile).first);
    final before = tile();
    // Only the height changes: the songs are not built again.
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    await tester.pumpAndSettle();
    expect(identical(tile(), before), isTrue);
    // A width with another number of columns still gives a new layout.
    tester.view.physicalSize = const Size(1280, 1280);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Another')).dy,
      tester.getTopLeft(find.text('Alpha')).dy,
    );
    await app.dispose(tester);
  });

  testWidgets('narrow screens keep one column', (tester) async {
    final app = await start(tester, const Size(600, 900));
    final a = tester.getTopLeft(find.text('Alpha'));
    final b = tester.getTopLeft(find.text('Another'));
    expect(b.dx, a.dx);
    expect(b.dy, greaterThan(a.dy));
    await app.dispose(tester);
  });
}
