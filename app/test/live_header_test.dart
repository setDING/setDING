import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/song_view.dart';

import 'test_app.dart';

/// Key, tempo and time are large and clearly readable in the live header
/// (issue #264); the song is still fitted below the header.
void main() {
  const source = '{title: Late Train}\n{key: G}\n{tempo: 92}\n{time: 3/4}\n';

  Future<LiveItem> createItem(
    WidgetTester tester,
    TestApp app, {
    String body = '[G]Line one [C]and two',
  }) async => (await tester.runAsync(() async {
    final id = await app.songs.createSong(source: '$source$body');
    final song = (await app.songs.getSong(id))!;
    // As in a set: band arrangement (+3, 120 BPM) and tonight's key (−1).
    return LiveItem.song(
      song,
      arrangement: BandArrangement(
        bandId: 'b1',
        songId: id,
        transpose: 3,
        tempo: 120,
        revision: 0,
        deleted: false,
      ),
      setTranspose: -1,
      setItemId: 'item-1',
    );
  }))!;

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  double fontSize(WidgetTester tester, String key) => tester
      .widget<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      )
      .style!
      .fontSize!;

  testWidgets('key, tempo and time are large chips beside the title', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final item = await createItem(tester, app);
    await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
    await tester.pumpAndSettle();

    // G + 3 (band) − 1 (set) = A; the band's tempo.
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-key')),
        matching: find.text('Key: A'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-tempo')),
        matching: find.text('120 BPM'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-time')),
        matching: find.text('3/4'),
      ),
      findsOneWidget,
    );
    // No small info line any more.
    expect(find.textContaining('92 BPM'), findsNothing);
    expect(find.textContaining('Key: A   '), findsNothing);

    // As large as the title, beside it on the right.
    final title = tester.getRect(find.text('Late Train'));
    final titleSize = tester
        .widget<Text>(find.text('Late Train'))
        .style!
        .fontSize!;
    for (final chip in ['stage-key', 'stage-tempo', 'stage-time']) {
      expect(fontSize(tester, chip), greaterThanOrEqualTo(titleSize));
      expect(fontSize(tester, chip), greaterThanOrEqualTo(20));
      expect(rect(tester, chip).left, greaterThan(title.right));
      expect(
        (rect(tester, chip).center.dy - title.center.dy).abs(),
        lessThan(4),
      );
    }
    expect(
      rect(tester, 'stage-time').right,
      lessThanOrEqualTo(tester.getRect(find.byType(PageView)).right),
    );
    await app.dispose(tester);
  });

  testWidgets('a capo gets a chip of its own', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final item = await createItem(tester, app, body: '{capo: 2}\n[G]Line');
    await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
    await tester.pumpAndSettle();
    // The shapes as written, the sounding key follows the capo.
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-capo')),
        matching: find.textContaining('Capo: 2'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stage-key')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('on a phone the chips are below the title', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final item = await createItem(tester, app);
    await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Late Train'));
    expect(rect(tester, 'stage-key').top, greaterThanOrEqualTo(title.bottom));
    expect(rect(tester, 'stage-key').left, title.left);
    await app.dispose(tester);
  });

  testWidgets('the fitted song stays below the larger header', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final body = StringBuffer();
    for (var i = 0; i < 12; i++) {
      body.writeln('{start_of_verse: Verse $i}');
      body.writeln('[G]Some words to [C]sing along [D]with the band');
      body.writeln('[Em]and another [C]line of [D]lyrics here');
      body.writeln('{end_of_verse}');
    }
    final item = await createItem(tester, app, body: body.toString());
    await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Fitted without scrolling: the song starts below the chips and ends
    // on the page.
    expect(find.byType(SingleChildScrollView), findsNothing);
    final song = tester.getRect(find.byType(SongBody));
    final page = tester.getRect(find.byType(PageView));
    expect(song.top, greaterThanOrEqualTo(rect(tester, 'stage-key').bottom));
    expect(song.bottom, lessThanOrEqualTo(page.bottom + 0.5));
    await app.dispose(tester);
  });
}
