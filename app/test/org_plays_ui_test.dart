import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/band_view.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/library_usage_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Plays across the bands of an organization (ADR-0046, #662): the other
/// bands in the song's Played panel and the library usage.
void main() {
  /// Ann in the band Rock of the organization o1, with the summary of the
  /// last sync: Jazz played Ballad twice, nobody played Lonely.
  Future<(TestApp, String, String)> start(
    WidgetTester tester, {
    bool annIsOrgAdmin = false,
    bool fetched = true,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        'currentBandId': 'b1',
        'currentLibraryId': 'o1',
      },
      user: _ann,
    );
    if (annIsOrgAdmin) {
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    } else {
      app.backend.addBand('b1', 'Rock', admin: _bob, organizationId: 'o1');
      app.backend.addMember('b1', _ann, BandRole.member);
    }
    final ids = (await tester.runAsync(() async {
      final songs = TestApp.songsIn(app, 'o1');
      final ballad = await songs.createSong(source: '{title: Ballad}');
      final lonely = await songs.createSong(source: '{title: Lonely}');
      if (fetched) {
        await app.db
            .into(app.db.orgPlays)
            .insert(
              OrgPlaysCompanion.insert(
                organizationId: 'o1',
                songId: ballad,
                bandId: 'b2',
                bandName: 'Jazz',
                playCount: 2,
                lastPlayed: DateTime(2026, 10, 12),
                playedKey: const Value('Bb'),
              ),
            );
        await app.db
            .into(app.db.syncCursors)
            .insert(
              SyncCursorsCompanion.insert(
                scope: 'o1',
                collection: SyncCollection.orgPlays,
                revision: Value(
                  DateTime(2026, 11, 19).millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            );
      }
      return (ballad, lonely);
    }))!;
    return (app, ids.$1, ids.$2);
  }

  testWidgets('the Played panel shows how the other bands play the song', (
    tester,
  ) async {
    final (app, ballad, lonely) = await start(tester);
    await tester.pumpWidget(app.build(home: SongScreen(songId: ballad)));
    await tester.pumpAndSettle();

    // Rock never played it, Jazz did: the panel is there.
    await tester.tap(find.byKey(const Key('open-play-history')));
    await tester.pumpAndSettle();
    final others = find.byKey(const Key('play-history-other-bands'));
    Finder inOthers(Finder f) => find.descendant(of: others, matching: f);
    expect(find.byKey(const Key('play-history-none')), findsOneWidget);
    expect(inOthers(find.text('Other bands')), findsOneWidget);
    expect(inOthers(find.text('Jazz')), findsOneWidget);
    expect(inOthers(find.text('Oct 12, 2026')), findsOneWidget);
    expect(inOthers(find.text('Bb')), findsOneWidget);
    expect(inOthers(find.text('2 times')), findsOneWidget);
    expect(inOthers(find.text('As of Nov 19, 2026')), findsOneWidget);
    await app.dispose(tester);

    expect(lonely, isNotEmpty);
  });

  testWidgets('a song no band played has no Played panel', (tester) async {
    final (app, _, lonely) = await start(tester);
    await tester.pumpWidget(app.build(home: SongScreen(songId: lonely)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-play-history')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('organization admins see the songs no band plays', (
    tester,
  ) async {
    final (app, _, lonely) = await start(tester, annIsOrgAdmin: true);
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-usage')));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryUsageScreen), findsOneWidget);
    expect(find.text('No band plays 1 of 2 songs'), findsOneWidget);
    expect(find.text('Lonely'), findsOneWidget);
    expect(find.text('Ballad'), findsNothing);

    await tester.tap(find.byKey(ValueKey('library-usage-delete-$lonely')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    final song = (await tester.runAsync(
      () => (app.db.select(
        app.db.songs,
      )..where((s) => s.id.equals(lonely))).getSingle(),
    ))!;
    expect(song.deleted, isTrue, reason: 'in the trash');
    expect(find.text('No band plays 0 of 1 songs'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members see no library usage; without a sync it is not '
      'loaded', (tester) async {
    final (app, _, _) = await start(tester, fetched: false);
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('songs-usage')), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      app.build(
        home: const LibraryUsageScreen(
          library: LibraryView(id: 'o1', orgRole: OrgRole.admin),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-usage-not-loaded')), findsOneWidget);
    await app.dispose(tester);
  });
}
