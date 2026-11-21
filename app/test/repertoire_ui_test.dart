import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/band_view.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/sets/repertoire_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// The band repertoire in the sets tab and the song list by the band's plays
/// (ADR-0046, #661).
void main() {
  final now = DateTime.now();
  DateTime daysAgo(int days) => DateTime(now.year, now.month, now.day - days);
  String date(DateTime d) => DateFormat.yMMMd('en').format(d);

  /// A past set of [bandId] with [songIds], as the sync stores it.
  Future<void> gig(
    TestApp app,
    String name,
    DateTime day,
    List<String> songIds, {
    String bandId = localBandId,
  }) async {
    final id = '$name-set';
    await app.db
        .into(app.db.setlists)
        .insert(
          SetlistsCompanion.insert(
            id: id,
            bandId: bandId,
            name: name,
            gigDate: Value(day),
            updatedAt: day,
          ),
        );
    for (final (i, songId) in songIds.indexed) {
      await app.db
          .into(app.db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: '$id-$i',
              setId: id,
              songId: Value(songId),
              position: i,
              type: SetItemType.song,
            ),
          );
    }
  }

  /// The local library: Hit played often and lately, Oldie a year ago,
  /// Fresh never.
  Future<TestApp> local(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final hit = await app.songs.createSong(source: '{title: Hit}');
      final oldie = await app.songs.createSong(
        source: '{title: Oldie}\n{artist: The Olds}',
      );
      await app.songs.createSong(source: '{title: Fresh}');
      await gig(app, 'A', daysAgo(3), [hit]);
      await gig(app, 'B', daysAgo(30), [hit]);
      await gig(app, 'C', daysAgo(370), [oldie, hit]);
    });
    return app;
  }

  testWidgets('the sets tab opens the repertoire of the band', (tester) async {
    final app = await local(tester);
    await tester.pumpWidget(app.build(home: const SetsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sets-repertoire')));
    await tester.pumpAndSettle();

    expect(find.byType(RepertoireScreen), findsOneWidget);
    Finder inSection(String key, Finder f) =>
        find.descendant(of: find.byKey(Key(key)), matching: f);
    // The last 12 months first, then all time.
    expect(inSection('repertoire-most-played', find.text('Hit')), findsOne);
    expect(inSection('repertoire-most-played', find.text('2 times')), findsOne);
    expect(
      inSection('repertoire-most-played', find.text('Oldie')),
      findsNothing,
    );
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(inSection('repertoire-most-played', find.text('3 times')), findsOne);
    expect(inSection('repertoire-most-played', find.text('once')), findsOne);

    expect(inSection('repertoire-stale', find.text('Oldie')), findsOneWidget);
    expect(
      inSection(
        'repertoire-stale',
        find.text('The Olds · Last played on ${date(daysAgo(370))}'),
      ),
      findsOneWidget,
    );
    expect(
      inSection(
        'repertoire-stale',
        find.text('Last played more than 6 months ago'),
      ),
      findsOneWidget,
    );
    expect(inSection('repertoire-never', find.text('Fresh')), findsOneWidget);
    expect(
      inSection('repertoire-never', find.text('Never played (1)')),
      findsOne,
    );
    // The local library keeps the default threshold.
    expect(find.byKey(const Key('repertoire-threshold')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets(
    'set planners choose when songs count as not played for a while',
    (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _ann,
      );
      app.backend.addBand('b1', 'Rock', admin: _bob, organizationId: 'o1');
      app.backend.addMember('b1', _ann, BandRole.planner);
      // The band as the band service stores it from the server.
      await tester.runAsync(() async {
        await app.db
            .into(app.db.organizations)
            .insert(OrganizationsCompanion.insert(id: 'o1', name: 'Org'));
        await app.db
            .into(app.db.bands)
            .insert(
              BandsCompanion.insert(
                id: 'b1',
                name: 'Rock',
                organizationId: const Value('o1'),
              ),
            );
        final song = await TestApp.songsIn(
          app,
          'o1',
        ).createSong(source: '{title: Ballad}');
        await gig(app, 'Spring', daysAgo(100), [song], bandId: 'b1');
      });
      await tester.pumpWidget(app.build(home: const SetsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sets-repertoire')));
      await tester.pumpAndSettle();

      expect(find.text('Repertoire of Rock'), findsOneWidget);
      // 100 days are within the default of 6 months.
      expect(
        find.descendant(
          of: find.byKey(const Key('repertoire-stale')),
          matching: find.text('Ballad'),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('repertoire-threshold')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stale-after-3')));
      await tester.pumpAndSettle();

      expect(app.backend.bands['b1']!.staleAfterMonths, 3);
      // ignore: avoid_print
      print(
        await tester.runAsync(
          () async => [
            for (final l in await app.db.select(app.db.setlists).get())
              (l.bandId, l.deleted, l.gigDate),
            for (final i in await app.db.select(app.db.setItems).get())
              (i.setId, i.songId),
            for (final s in await app.db.select(app.db.songs).get())
              (s.id, s.libraryId, s.deleted),
          ],
        ),
      );
      expect(find.text('Last played more than 3 months ago'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('repertoire-stale')),
          matching: find.text('Ballad'),
        ),
        findsOneWidget,
      );
      await app.dispose(tester);
    },
  );

  testWidgets('the song list sorts and filters by the band\'s plays', (
    tester,
  ) async {
    final app = await local(tester);
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();

    List<String> titles() => [
      for (final tile in tester.widgetList<SongTile>(find.byType(SongTile)))
        tile.song.title,
    ];
    expect(titles(), ['Fresh', 'Hit', 'Oldie']);

    await tester.tap(find.byKey(const Key('songs-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last played').last);
    await tester.pumpAndSettle();
    expect(titles(), ['Hit', 'Oldie', 'Fresh']);
    expect(find.text('Last played on ${date(daysAgo(3))}'), findsOneWidget);
    expect(find.text('Never played'), findsWidgets);

    // One menu for the plays (#816), the last of the filters.
    final played = find.byKey(const Key('songs-played'));
    Future<void> choose(String filter) async {
      await tester.tap(played);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('songs-played-$filter')));
      await tester.pumpAndSettle();
    }

    expect(
      find.descendant(of: played, matching: find.text('Played')),
      findsOne,
    );
    await choose('never');
    expect(titles(), ['Fresh']);
    expect(
      find.descendant(of: played, matching: find.text('Never played')),
      findsOne,
    );
    await choose('stale');
    expect(titles(), ['Oldie']);
    await choose('all');
    expect(titles(), ['Hit', 'Oldie', 'Fresh']);
    expect(BandView.local.staleAfterMonths, 6);
    await app.dispose(tester);
  });
}
