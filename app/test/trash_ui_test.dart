import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// The trash of ADR-0043: reached from the song and set lists, restores and
/// deletes permanently (#866).
void main() {
  testWidgets('a deleted song is restored from the trash', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Lost song}');
      await app.songs.deleteSong(id);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Lost song'), findsNothing);

    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-trash')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted songs'), findsOneWidget);
    expect(find.text('Lost song'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('30 days left'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions for "Lost song"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('"Lost song" restored'), findsOneWidget);
    expect(find.textContaining('The trash is empty.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lost song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a deleted set is restored from the trash', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.sets.createSet(name: 'Lost gig');
      await app.sets.deleteSet(id);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sets').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sets-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sets-trash')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted sets'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions for "Lost gig"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lost gig'), findsOneWidget);
    await app.dispose(tester);
  });

  Future<TestApp> openSongTrash(
    WidgetTester tester,
    List<String> titles,
  ) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      for (final t in titles) {
        final id = await app.songs.createSong(source: '{title: $t}');
        await app.songs.deleteSong(id);
      }
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-trash')));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('a song is deleted permanently after a confirmation', (
    tester,
  ) async {
    final app = await openSongTrash(tester, ['Lost song', 'Kept song']);
    await tester.tap(find.byTooltip('Actions for "Lost song"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Delete permanently?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('"Lost song" deleted permanently'), findsOneWidget);
    expect(find.text('Lost song'), findsNothing);
    expect(find.text('Kept song'), findsOneWidget);
    final songs = await tester.runAsync(
      () => app.db.select(app.db.songs).get(),
    );
    expect([for (final s in songs!) s.title], ['Kept song']);
    await app.dispose(tester);
  });

  testWidgets('selected songs are restored, the rest is emptied', (
    tester,
  ) async {
    final app = await openSongTrash(tester, ['One', 'Two', 'Three']);
    await tester.longPress(find.text('One'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    // The checkbox leads the row in place of the icon, like in the other
    // multi-select lists.
    final row = find.ancestor(
      of: find.text('One'),
      matching: find.byType(ListTile),
    );
    final checkbox = find.descendant(of: row, matching: find.byType(Checkbox));
    expect(checkbox, findsOneWidget);
    expect(
      tester.getCenter(checkbox).dx,
      lessThan(tester.getTopLeft(find.text('One')).dx),
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.music_note_outlined),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash-restore-selected')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('2 entries restored'), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Three'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trash-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash-empty')));
    await tester.pumpAndSettle();
    expect(find.text('Empty the trash?'), findsOneWidget);
    expect(find.textContaining('1 entry will be deleted'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.textContaining('The trash is empty.'), findsOneWidget);
    final songs = await tester.runAsync(
      () => app.db.select(app.db.songs).get(),
    );
    expect([for (final s in songs!) s.title]..sort(), ['One', 'Two']);
    await app.dispose(tester);
  });
}
