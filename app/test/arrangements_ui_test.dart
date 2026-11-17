import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/data/arrangement_repository.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/ui/sets/set_list_text.dart';
import 'package:realchord/ui/songs/song_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Band arrangements on the songs tab and in the set list (ADR-0025).
void main() {
  Future<(TestApp, String)> start(
    WidgetTester tester, {
    required AuthUser user,
    BandRole role = BandRole.admin,
    int? transpose,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: user,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    if (user.id != _ann.id) app.backend.addMember('b1', user, role);
    final id = (await tester.runAsync(
      () => TestApp.songsIn(
        app,
        'o1',
      ).createSong(source: '{title: Late Train}\n{key: G}\n{tempo: 100}\n[G]x'),
    ))!;
    if (transpose != null) {
      await tester.runAsync(
        () => ArrangementRepository(app.db)
            .save('b1', id, transpose: transpose, sequence: 'V C', tempo: 120),
      );
    }
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();
    return (app, id);
  }

  testWidgets('the song is shown in the band\'s key, sequence and tempo', (
    tester,
  ) async {
    final (app, _) = await start(
      tester,
      user: _bob,
      role: BandRole.member,
      transpose: 2,
    );
    expect(find.text('Arrangement of Rock'), findsOneWidget);
    expect(find.textContaining('Key A'), findsWidgets);
    expect(find.textContaining('120 BPM'), findsWidgets);
    expect(find.textContaining('100 BPM'), findsNothing);
    expect(find.byKey(const ValueKey('sequence-from-band')), findsWidgets);
    // Members only see it.
    expect(find.byKey(const Key('arrangement-key')), findsNothing);
    expect(find.byKey(const Key('arrangement-reset')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('without an arrangement members see the song as written', (
    tester,
  ) async {
    final (app, _) = await start(tester, user: _bob, role: BandRole.member);
    expect(find.byKey(const Key('band-arrangement')), findsNothing);
    expect(find.textContaining('100 BPM'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('set planners change the tempo and go back to the song', (
    tester,
  ) async {
    final (app, id) = await start(tester, user: _bob, role: BandRole.planner);
    expect(find.text('As in the song'), findsOneWidget);

    await tester.tap(find.byKey(const Key('arrangement-tempo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '132');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final repo = ArrangementRepository(app.db);
    final saved = await tester.runAsync(() => repo.get('b1', id));
    expect(saved!.tempo, 132);
    expect(find.textContaining('132 BPM'), findsWidgets);

    await tester.tap(find.byKey(const Key('arrangement-reset')));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => repo.get('b1', id)), isNull);
    expect(find.text('As in the song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the set list uses the band\'s key below the set key', (
    tester,
  ) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    final list = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source: '{title: Late Train}\n{key: G}\n{x_sequence: V1, C}',
      );
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, [id]);
      final items = await app.sets.getItems(setId);
      await app.sets.setItemTranspose(items.single.item.id, -1);
      final set = await app.sets.getSet(setId);
      return buildSetList(
        set!,
        await app.sets.getItems(setId),
        arrangements: {
          id: BandArrangement(
            bandId: set.bandId,
            songId: id,
            transpose: 3,
            sequence: 'V1, C, C',
            revision: 0,
            deleted: false,
          ),
        },
        notation: cp.ChordNotation.international,
        formatDate: (d) => '$d',
        untitled: 'Untitled',
        songMissing: 'Missing',
      );
    });
    // G + 3 (band) − 1 (tonight) = A; the band's sequence.
    expect(setListText(list!), contains('1. Late Train – A – V1, C, C'));
    await app.dispose(tester);
  });
}
