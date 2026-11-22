import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_list.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

/// What a screen shows: the offered filter chips with their menu items,
/// the section headers and the songs in order.
typedef Shown = ({
  Map<String, List<String>> filters,
  List<String> sections,
  List<String> songs,
});

/// The song picker of a set stays in step with the song list (#884, #886):
/// with the same songs, both offer the same filters and show the same songs
/// in the same sections for every order and filter. A filter or order added
/// to only one of them fails here; the overview's To do filters are the one
/// deliberate difference (see [SongFilters.attentionFilters]).
void main() {
  const chips = ['songs-sort', 'songs-language', 'songs-tags', 'songs-played'];

  bool isFilterKey(Key? key) =>
      key is ValueKey<String> &&
      key.value.startsWith('songs-') &&
      !key.value.startsWith('songs-attention-');

  Future<Shown> shown(WidgetTester tester) async {
    final filters = <String, List<String>>{};
    for (final chip in chips) {
      final finder = find.byKey(Key(chip));
      if (finder.evaluate().isEmpty) continue;
      await tester.tap(finder);
      await tester.pumpAndSettle();
      // The items of the open menu, in order.
      filters[chip] = [
        for (final e
            in find
                .byWidgetPredicate(
                  (w) =>
                      (w is MenuItemButton || w is CheckboxMenuButton) &&
                      isFilterKey(w.key),
                )
                .evaluate())
          (e.widget.key! as ValueKey<String>).value,
      ];
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
    return (
      filters: filters,
      sections: [
        for (final h in tester.widgetList<SongSectionHeader>(
          find.byType(SongSectionHeader),
        ))
          h.label,
      ],
      songs: [
        for (final t in tester.widgetList<SongTile>(find.byType(SongTile)))
          t.song.title,
      ],
    );
  }

  /// Chooses [item] in the menu of [chip]; a tag is ticked.
  Future<void> choose(WidgetTester tester, String chip, String item) async {
    await tester.tap(find.byKey(Key(chip)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(item)).first);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  }

  // Each case: the menu items chosen, in order.
  const cases = <String, List<(String, String)>>{
    'all songs': [],
    'by artist': [('songs-sort', 'songs-sort-artist')],
    'by key': [('songs-sort', 'songs-sort-key')],
    'by last edit': [('songs-sort', 'songs-sort-recent')],
    'by last play': [('songs-sort', 'songs-sort-lastPlayed')],
    'a tag': [('songs-tags', 'songs-tag-Jazz')],
    'two tags': [
      ('songs-tags', 'songs-tag-Jazz'),
      ('songs-tags', 'songs-tag-Ballad'),
    ],
    'a language': [('songs-language', 'songs-language-de')],
    'no language': [('songs-language', 'songs-language-none')],
    'never played': [('songs-played', 'songs-played-never')],
    'not played for a while': [('songs-played', 'songs-played-stale')],
    'tag, language and plays': [
      ('songs-sort', 'songs-sort-artist'),
      ('songs-tags', 'songs-tag-Jazz'),
      ('songs-language', 'songs-language-en'),
      ('songs-played', 'songs-played-never'),
    ],
  };

  for (final MapEntry(key: name, value: steps) in cases.entries) {
    testWidgets('the song picker shows what the song list shows: $name', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final set = (await tester.runAsync(() async {
        final ids = <String>[];
        for (final source in [
          '{title: River}\n{artist: Bea}\n{key: G}\n{tag: Jazz}\n'
              'I walk along the river and you are always there with me,\n'
              'when the wind is in the willows and the night is calling me.',
          '{title: Fluss}\n{artist: Anna}\n{key: D}\n{tag: Ballad}\n'
              'Ich gehe durch die Nacht und du bist immer bei mir,\n'
              'wenn der Wind über das Land zieht, singe ich mit dir.',
          '{title: Morning}\n{artist: Bea}\n{key: C}\n{tag: Jazz}\n'
              '{tag: Ballad}\nThe morning sun is rising over the hills and '
              'all the birds are singing in the trees for you and me.',
          '{title: Groove}\n{key: Am}\n[Am]x',
          '{title: Abend}\n{artist: Carl}\n{tag: Jazz}\n'
              'Am Abend sitzen wir zusammen und singen unsere Lieder,\n'
              'die Sonne geht unter und wir sehen uns morgen wieder.',
        ]) {
          ids.add(await app.songs.createSong(source: source));
        }
        final now = DateTime.now();
        final recent = await app.sets.createSet(
          name: 'Recent',
          gigDate: now.subtract(const Duration(days: 10)),
        );
        await app.sets.addSongs(recent, [ids[0]]);
        final old = await app.sets.createSet(
          name: 'Old',
          gigDate: now.subtract(const Duration(days: 800)),
        );
        await app.sets.addSongs(old, [ids[1], ids[4]]);
        return app.sets.createSet(name: 'Next');
      }))!;

      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: app.build(home: const SongsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (final (chip, item) in steps) {
        await choose(tester, chip, item);
      }
      final list = await shown(tester);

      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: app.build(home: SetScreen(setId: set)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add songs'));
      await tester.pumpAndSettle();
      for (final (chip, item) in steps) {
        await choose(tester, chip, item);
      }
      final picker = await shown(tester);

      // Every chip of [chips] is offered here, so a renamed or new one
      // needs this test to follow.
      expect(list.filters.keys, chips);
      expect(picker.filters, list.filters);
      expect(picker.sections, list.sections);
      expect(picker.songs, list.songs);
      expect(list.songs, isNotEmpty, reason: 'the case shows songs');
      await app.dispose(tester);
    });
  }
}
