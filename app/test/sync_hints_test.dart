import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/overview/recent_changes.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Hints when a sync changes the open song or set (#691).
void main() {
  RemoteSong song(String id, String title, {String line = 'One'}) => RemoteSong(
    id: id,
    organizationId: 'o1',
    title: title,
    chordpro: '{title: $title}\n[C]$line',
  );
  RemoteSetItem item(String id, String songId) =>
      RemoteSetItem(id: id, type: SetItemType.song, songId: songId);
  RemoteSet gig({List<String> order = const ['s1', 's2']}) => RemoteSet(
    id: 'g1',
    bandId: 'b1',
    name: 'Gig',
    items: [for (final (i, s) in order.indexed) item('i$i', s)],
  );

  /// Ann's device with Bob's library and set, synced once (the first sync
  /// of a library or band tells nothing).
  Future<TestApp> setup(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend
      ..addBand('b1', 'Rock', admin: _ann, organizationId: 'o1')
      ..addMember('b1', _bob, BandRole.member)
      ..putSong(song('s1', 'Opener'), by: 'bob')
      ..putSong(song('s2', 'Closer'), by: 'bob')
      ..putSet(gig(), by: 'bob');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pumpAndSettle();
  }

  final hint = find.byType(SnackBar);

  testWidgets('a song someone else changed: a hint on its screen', (
    tester,
  ) async {
    final app = await setup(tester);
    await open(tester, const SongScreen(songId: 's1'));

    app.backend.putSong(song('s1', 'Opener', line: 'Two'), by: 'bob');
    await syncNow(tester);
    expect(find.text('"Opener" was changed by Bob.'), findsOneWidget);
    expect(find.byType(SongScreen), findsOneWidget);

    // Another song's change is not this screen's business.
    ScaffoldMessenger.of(tester.element(find.byType(SongScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    app.backend.putSong(song('s2', 'Closer', line: 'Two'), by: 'bob');
    await syncNow(tester);
    expect(hint, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a song someone else deleted: its screen closes', (tester) async {
    final app = await setup(tester);
    await open(tester, const SongScreen(songId: 's1'));

    app.backend.putSong(
      RemoteSong(
        id: 's1',
        organizationId: 'o1',
        title: 'Opener',
        chordpro: '{title: Opener}\n[C]One',
        deleted: true,
      ),
      by: 'bob',
    );
    await syncNow(tester, within: find.byType(SongScreen));
    expect(find.byType(SongScreen), findsNothing);
    expect(find.text('"Opener" was deleted by Bob.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set someone else reordered: a hint on its screen', (
    tester,
  ) async {
    final app = await setup(tester);
    await open(tester, const SetScreen(setId: 'g1'));

    app.backend.putSet(gig(order: ['s2', 's1']), by: 'bob');
    await syncNow(tester);
    expect(find.text('The set "Gig" was changed by Bob.'), findsOneWidget);
    expect(find.byType(SetScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a song of the open set deleted: the set tells', (tester) async {
    final app = await setup(tester);
    await open(tester, const SetScreen(setId: 'g1'));

    // Bob deletes the song; his device removes it from the set, too.
    app.backend
      ..putSong(
        RemoteSong(
          id: 's2',
          organizationId: 'o1',
          title: 'Closer',
          chordpro: '{title: Closer}',
          deleted: true,
        ),
        by: 'bob',
      )
      ..putSet(gig(order: ['s1']), by: 'bob');
    await syncNow(tester);
    expect(find.text('The set "Gig" was changed by Bob.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set someone else deleted: its screen closes', (tester) async {
    final app = await setup(tester);
    await open(tester, const SetScreen(setId: 'g1'));

    final deleted = gig();
    app.backend.putSet(
      RemoteSet(
        id: deleted.id,
        bandId: deleted.bandId,
        name: deleted.name,
        items: deleted.items,
        deleted: true,
      ),
      by: 'bob',
    );
    await syncNow(tester, within: find.byType(SetScreen));
    expect(find.byType(SetScreen), findsNothing);
    expect(find.text('The set "Gig" was deleted by Bob.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('own changes, also from another device, tell nothing', (
    tester,
  ) async {
    final app = await setup(tester);
    await open(tester, const SongScreen(songId: 's1'));

    app.backend.putSong(song('s1', 'Opener', line: 'Mine'), by: 'ann');
    await syncNow(tester);
    expect(hint, findsNothing);
    await app.dispose(tester);
  });

  testWidgets('after live mode, one hint sums up what changed', (tester) async {
    final app = await setup(tester);
    await open(tester, const SetScreen(setId: 'g1'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetScreen)),
    );
    final controller = container.read(syncControllerProvider.notifier);

    // On stage: Bob changes one song and deletes the other; the sync
    // waits.
    controller.pause();
    app.backend
      ..putSong(song('s1', 'Opener', line: 'Two'), by: 'bob')
      ..putSong(
        RemoteSong(
          id: 's2',
          organizationId: 'o1',
          title: 'Closer',
          chordpro: '{title: Closer}',
          deleted: true,
        ),
        by: 'bob',
      )
      ..putSet(gig(order: ['s1']), by: 'bob');
    expect(await tester.runAsync(controller.syncNow), isNull);
    expect(hint, findsNothing);

    // Off stage: the sync catches up, and one hint sums it up instead of
    // the set's own.
    controller.resume();
    await syncNow(tester);
    expect(
      find.text(
        'While you were playing live: 1 song deleted, 1 song changed, '
        '1 set changed.',
      ),
      findsOneWidget,
    );
    expect(find.text('The set "Gig" was changed by Bob.'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.byType(RecentChangesScreen), findsOneWidget);

    // The next sync is a normal one again.
    Navigator.of(tester.element(find.byType(RecentChangesScreen))).pop();
    await tester.pumpAndSettle();
    app.backend.putSet(gig(order: ['s1', 's1']), by: 'bob');
    await syncNow(tester);
    expect(find.text('The set "Gig" was changed by Bob.'), findsOneWidget);
    await app.dispose(tester);
  });
}
