import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// The song play history in the song view, the set's key picker and the
/// song picker (ADR-0046, #660).
void main() {
  final now = DateTime.now();
  DateTime daysAgo(int days) => DateTime(now.year, now.month, now.day - days);
  String date(DateTime d) => DateFormat.yMMMd('en').format(d);

  /// A set of the local library on [day] with [songId], stored as the sync
  /// would: with [played] values or without (then derived).
  Future<String> gig(
    TestApp app,
    String name,
    DateTime day,
    String songId, {
    PlayedValues? played,
  }) async {
    final id = await app.sets.createSet(name: name, gigDate: day);
    await app.db
        .into(app.db.setItems)
        .insert(
          SetItemsCompanion.insert(
            id: '$id-item',
            setId: id,
            songId: Value(songId),
            position: 0,
            type: SetItemType.song,
            played: Value(played),
          ),
        );
    return id;
  }

  /// A song in G played six times: in A last, then four times in G, the
  /// oldest without stored values.
  Future<(TestApp, String, String)> start(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() async {
      final song = await app.songs.createSong(
        source: '{title: Late Train}\n{key: G}\n{tempo: 100}\n[G]x',
      );
      final never = await app.songs.createSong(source: '{title: New One}');
      await gig(
        app,
        'Autumn fair',
        daysAgo(10),
        song,
        played: const PlayedValues(key: 'A', tempo: 104, sequence: 'V C'),
      );
      for (var i = 1; i <= 4; i++) {
        await gig(
          app,
          'Gig $i',
          daysAgo(10 + 20 * i),
          song,
          played: const PlayedValues(key: 'G', tempo: 100),
        );
      }
      await gig(app, 'Old times', daysAgo(500), song);
      final next = await app.sets.createSet(name: 'Next', gigDate: daysAgo(-7));
      await app.sets.addSongs(next, [song]);
      return (song, never, next);
    }))!;
    expect(ids.$2, isNotEmpty);
    return (app, ids.$1, ids.$3);
  }

  testWidgets('the song shows how often and how the band played it', (
    tester,
  ) async {
    final (app, song, _) = await start(tester);
    await tester.pumpWidget(app.build(home: SongScreen(songId: song)));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('open-play-history'));
    expect(
      find.descendant(of: button, matching: find.text('6')),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('play-history'));
    expect(panel, findsOneWidget);
    Finder inPanel(Finder f) => find.descendant(of: panel, matching: f);
    expect(inPanel(find.text('in total')), findsOneWidget);
    expect(inPanel(find.text('5')), findsOneWidget, reason: '12 months');
    expect(inPanel(find.text(date(daysAgo(10)))), findsNWidgets(2));
    // The latest five, the key other than the band's today highlighted.
    expect(inPanel(find.textContaining('Gig ')), findsNWidgets(4));
    expect(inPanel(find.text('Old times')), findsNothing);
    expect(inPanel(find.byKey(const Key('play-key-differs'))), findsOneWidget);
    expect(inPanel(find.text('104')), findsOneWidget);
    expect(
      inPanel(find.text("Highlighted: a key other than today's (G)")),
      findsOneWidget,
    );
    expect(inPanel(find.textContaining('≈')), findsNothing);

    await tester.tap(inPanel(find.text('Show all 6')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Old times')), findsOneWidget);
    expect(inPanel(find.text('≈ G')), findsOneWidget);
    expect(inPanel(find.textContaining('derived from today')), findsOneWidget);
    expect(
      inPanel(find.text('First on ${date(daysAgo(500))}')),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('a song the band never played has no play history', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = (await tester.runAsync(
      () => app.songs.createSong(source: '{title: Fresh}\n{key: C}'),
    ))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: song)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-play-history')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the key picker of a set tells how the song was played', (
    tester,
  ) async {
    final (app, _, next) = await start(tester);
    await tester.pumpWidget(app.build(home: SetScreen(setId: next)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Key in this set – for the whole band'));
    await tester.pumpAndSettle();
    expect(
      find.text('Last A on ${date(daysAgo(10))} · mostly G (5 of 6)'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the song picker of a set tells when a song was last played', (
    tester,
  ) async {
    final (app, _, next) = await start(tester);
    await tester.pumpWidget(app.build(home: SetScreen(setId: next)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add songs'));
    await tester.pumpAndSettle();
    expect(find.text('Last played on ${date(daysAgo(10))}'), findsOneWidget);
    expect(find.text('Never played'), findsOneWidget);
    await app.dispose(tester);
  });
}
