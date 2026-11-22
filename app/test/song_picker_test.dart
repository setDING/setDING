import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_attention.dart';
import 'package:setding/ui/songs/song_language.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

/// The song picker of a set is built like the song list (#884): the same
/// filters, sections and columns.
void main() {
  /// A set and songs of the local library: two tagged songs, one without
  /// chords (a To do of the overview), and one already played in the set.
  Future<(TestApp, String)> start(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = (await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Carol}\n{tag: Advent}\n[G]x');
      await app.songs.createSong(
        source: '{title: Hymn}\n{tag: Communion}\n[C]x',
      );
      await app.songs.createSong(source: '{title: Plain}');
      final played = await app.songs.createSong(
        source: '{title: Opener}\n[D]x',
      );
      final set = await app.sets.createSet(
        name: 'Last week',
        gigDate: DateTime.now().subtract(const Duration(days: 7)),
      );
      await app.sets.addSongs(set, [played]);
      return set;
    }))!;
    return (app, setId);
  }

  Future<void> openPicker(TestApp app, WidgetTester tester, String set) async {
    await tester.pumpWidget(app.build(home: SetScreen(setId: set)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add songs'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String chip, String item) async {
    await tester.tap(find.byKey(Key(chip)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(item)).first);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  }

  testWidgets('the picker offers the filters of the song list', (tester) async {
    useTabletSize(tester);
    final (app, set) = await start(tester);
    await openPicker(app, tester, set);

    expect(find.byKey(const Key('songs-sort')), findsOne);
    expect(find.byKey(const Key('songs-tags')), findsOne);
    expect(find.byKey(const Key('songs-played')), findsOne);
    // The To do filters are for fixing songs, not for choosing them.
    for (final kind in SongAttention.values) {
      expect(
        find.byKey(ValueKey('songs-attention-${kind.name}')),
        findsNothing,
      );
    }
    // Sections by the first letter, as on the song list.
    expect(find.byType(SongSectionHeader), findsWidgets);

    await choose(tester, 'songs-tags', 'songs-tag-Advent');
    expect(find.text('Carol'), findsOne);
    expect(find.text('Hymn'), findsNothing);
    expect(find.text('Plain'), findsNothing);

    await choose(tester, 'songs-tags', 'songs-tags-all');
    await choose(tester, 'songs-played', 'songs-played-never');
    expect(find.text('Opener'), findsNothing);
    expect(find.text('Carol'), findsOne);
    await app.dispose(tester);
  });

  testWidgets('the picker keeps the order of selection', (tester) async {
    useTabletSize(tester);
    final (app, set) = await start(tester);
    await openPicker(app, tester, set);

    await tester.tap(find.text('Plain'));
    await tester.tap(find.text('Carol'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOne);
    // The selection stays while a filter hides a selected song.
    await choose(tester, 'songs-tags', 'songs-tag-Advent');
    expect(find.text('2 selected'), findsOne);
    await tester.tap(find.byKey(const Key('song-picker-add')));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(() => app.sets.watchItems(set).first);
    expect(items!.map((i) => i.song?.title), ['Opener', 'Plain', 'Carol']);
    await app.dispose(tester);
  });

  testWidgets('the picker has two columns on a wide screen', (tester) async {
    useTabletSize(tester);
    final (app, set) = await start(tester);
    // Two songs of section C share a row.
    await tester.runAsync(
      () => app.songs.createSong(source: '{title: Cello}\n[A]x'),
    );
    await openPicker(app, tester, set);
    final carol = tester.getTopLeft(find.text('Carol'));
    final cello = tester.getTopLeft(find.text('Cello'));
    // Carol's tile also shows its tag, so its title sits a bit higher.
    expect((cello.dy - carol.dy).abs(), lessThan(20));
    expect(cello.dx, greaterThan(carol.dx + 400));
    await app.dispose(tester);
  });

  testWidgets('the picker has one column on a phone', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (app, set) = await start(tester);
    await tester.runAsync(
      () => app.songs.createSong(source: '{title: Cello}\n[A]x'),
    );
    await openPicker(app, tester, set);
    final carol = tester.getTopLeft(find.text('Carol'));
    final cello = tester.getTopLeft(find.text('Cello'));
    expect(cello.dx, carol.dx);
    expect(cello.dy, isNot(carol.dy));
    await app.dispose(tester);
  });

  group('filterSongList', () {
    const a = SongListEntry(id: 'a', title: 'A', language: 'de');
    const b = SongListEntry(id: 'b', title: 'B', language: 'en');
    const c = SongListEntry(id: 'c', title: 'C');
    final now = DateTime(2026, 11, 22);
    final lastPlayed = {'a': DateTime(2026, 11, 1), 'b': DateTime(2025, 1, 1)};
    List<String> ids(List<SongListEntry> songs) => [
      for (final s in songs) s.id,
    ];

    test('filters by language', () {
      expect(ids(filterSongList([a, b, c], language: 'en')), ['b']);
      expect(ids(filterSongList([a, b, c], language: noSongLanguage)), ['c']);
    });

    test('filters by plays and orders by the last one', () {
      expect(
        ids(
          filterSongList(
            [a, b, c],
            played: PlayedFilter.never,
            lastPlayed: lastPlayed,
            now: now,
          ),
        ),
        ['c'],
      );
      expect(
        ids(
          filterSongList(
            [a, b, c],
            played: PlayedFilter.stale,
            lastPlayed: lastPlayed,
            staleAfterMonths: 6,
            now: now,
          ),
        ),
        ['b'],
      );
      expect(
        ids(
          filterSongList([c, b, a], lastPlayed: lastPlayed, byLastPlayed: true),
        ),
        ['a', 'b', 'c'],
      );
    });

    test('ignores the plays without a band', () {
      expect(ids(filterSongList([a, b], played: PlayedFilter.never)), [
        'a',
        'b',
      ]);
    });
  });
}
