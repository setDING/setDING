import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/song_header.dart';
import 'package:setding/ui/sets/set_list.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'set_list_lines.dart';
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

  testWidgets('the song list keeps the song and hints at the arrangement', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await tester.runAsync(() async {
      final songs = TestApp.songsIn(app, 'o1');
      final id = await songs.createSong(
        source: '{title: Late Train}\n{key: G}\n{tempo: 100}\n[G]x',
      );
      await songs.createSong(source: '{title: Other}\n{key: D}');
      await ArrangementRepository(app.db)
          .save('b1', id, transpose: 2, sequence: 'V, C', tempo: 120);
    });
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();

    // The song as written: its key badge and tempo.
    final badges = find.byKey(const ValueKey('song-key-badge'));
    expect(
      find.descendant(of: badges, matching: find.text('G')),
      findsOneWidget,
    );
    expect(find.text('100 BPM'), findsOneWidget);
    // Only the arranged song gets the hint: the band's key, tempo, sequence.
    final hint = find.byKey(const ValueKey('band-arrangement-hint'));
    expect(hint, findsOneWidget);
    expect(
      find.descendant(of: hint, matching: find.text('Key A · 120 BPM')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hint,
        matching: find.byTooltip('Arrangement of Rock'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hint, matching: find.byType(SongSequenceView)),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the band\'s key, sequence and tempo are only in the card', (
    tester,
  ) async {
    final (app, _) = await start(
      tester,
      user: _bob,
      role: BandRole.member,
      transpose: 3,
    );
    // The arrangement is behind its own icon, marked with a dot.
    expect(find.byKey(const Key('band-arrangement')), findsNothing);
    final icon = find.byKey(const Key('open-band-arrangement'));
    expect(
      tester
          .widget<Badge>(
            find.descendant(of: icon, matching: find.byType(Badge)),
          )
          .isLabelVisible,
      isTrue,
    );
    await tester.tap(find.byTooltip('Band arrangement'));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('band-arrangement'));
    expect(find.text('Arrangement of Rock'), findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.byTooltip(
          'For the whole band – applies in all its sets.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Key Bb')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('120 BPM')),
      findsOneWidget,
    );
    // Everywhere else the song is shown as written (G, 100 BPM).
    expect(find.textContaining('Bb'), findsOneWidget);
    expect(find.textContaining('120 BPM'), findsOneWidget);
    expect(find.textContaining('100 BPM'), findsWidgets);
    expect(find.text('G'), findsWidgets);
    // Members only see it.
    expect(find.byKey(const Key('arrangement-key')), findsNothing);
    expect(find.byKey(const Key('arrangement-reset')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a single song is played live in its key with the band\'s '
      'sequence', (tester) async {
    final (app, _) = await start(tester, user: _ann, transpose: 3);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    final live = tester.widget<LiveScreen>(find.byType(LiveScreen));
    final item = live.items.single;
    // Only the sequence (#552); key and tempo stay as written.
    expect(item.arrangement?.sequence, 'V C');
    expect(item.bandTranspose, 0);
    expect(item.arrangement?.tempo, isNull);
    expect(item.setItemId, isNull);
    await app.dispose(tester);
  });

  for (final showOutside in [true, false]) {
    testWidgets('a single song live applies the band\'s sequence '
        '(parts outside shown: $showOutside)', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': 'en',
          'currentBandId': 'b1',
          'showOutsideSequence': showOutside,
        },
        user: _ann,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      final id = (await tester.runAsync(() async {
        final id = await TestApp.songsIn(app, 'o1').createSong(
          source:
              '{title: Seq}\n'
              '{c: Verse 1}\nfirst verse\n\n{c: Chorus}\nthe chorus\n\n'
              '{c: Verse 2}\nsecond verse\n\n{c: Bridge}\nthe bridge',
        );
        await ArrangementRepository(app.db)
            .save('b1', id, transpose: 0, sequence: 'V1, C');
        return id;
      }))!;
      await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      final dimmed = find.byKey(const ValueKey('dimmed-section'));
      if (showOutside) {
        expect(find.textContaining('the bridge'), findsWidgets);
        expect(
          find.ancestor(
            of: find.textContaining('the bridge'),
            matching: dimmed,
          ),
          findsWidgets,
        );
        expect(
          find.ancestor(
            of: find.textContaining('the chorus'),
            matching: dimmed,
          ),
          findsNothing,
        );
        expect(find.byKey(const Key('hidden-parts')), findsNothing);
      } else {
        expect(find.textContaining('the bridge'), findsNothing);
        expect(find.textContaining('second verse'), findsNothing);
        expect(dimmed, findsNothing);
        expect(
          find.text('Hidden (not in the sequence): V2, B'),
          findsOneWidget,
        );
      }
      await app.dispose(tester);
    });
  }

  testWidgets('the band of the arrangement is chosen in the panel', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addBand('b2', 'Blues', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    app.backend.addMember('b2', _bob, BandRole.member);
    final id = (await tester.runAsync(() async {
      final id = await TestApp.songsIn(app, 'o1').createSong(
        source:
            '{title: Two Bands}\n{tempo: 100}\n'
            '{c: Verse}\nthe verse\n\n{c: Bridge}\nthe bridge',
      );
      await ArrangementRepository(app.db)
          .save('b2', id, transpose: 0, sequence: 'V', tempo: 90);
      return id;
    }))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();

    // Rock has no arrangement, but Bob can choose another band.
    await tester.tap(find.byTooltip('Band arrangement'));
    await tester.pumpAndSettle();
    expect(find.text('Arrangement of Rock'), findsOneWidget);
    expect(find.text('As in the song'), findsOneWidget);

    await tester.tap(find.byKey(const Key('arrangement-band')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blues').last);
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('band-arrangement'));
    expect(find.text('Arrangement of Blues'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('90 BPM')),
      findsOneWidget,
    );
    // It is the band of the sets tab.
    expect(app.prefs.getString('currentBandId'), 'b2');

    // A single song played live follows the chosen band's sequence.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    final live = tester.widget<LiveScreen>(find.byType(LiveScreen));
    expect(live.items.single.arrangement?.sequence, 'V');
    await app.dispose(tester);
  });

  testWidgets('with one band the panel has no band choice', (tester) async {
    final (app, _) = await start(tester, user: _ann);
    await tester.tap(find.byTooltip('Band arrangement'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arrangement-band')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('without an arrangement members see the song as written', (
    tester,
  ) async {
    final (app, _) = await start(tester, user: _bob, role: BandRole.member);
    expect(find.byKey(const Key('band-arrangement')), findsNothing);
    expect(find.byTooltip('Band arrangement'), findsNothing);
    expect(find.textContaining('100 BPM'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('set planners change the tempo and go back to the song', (
    tester,
  ) async {
    final (app, id) = await start(tester, user: _bob, role: BandRole.planner);
    await tester.tap(find.byTooltip('Band arrangement'));
    await tester.pumpAndSettle();
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
        markerName: (_) => 'Break',
      );
    });
    // G + 3 (band) − 1 (tonight) = A; the band's sequence.
    expect(describeSetList(list!), contains('1. Late Train – A – V1, C, C'));
    await app.dispose(tester);
  });
}
