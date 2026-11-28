import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:drift/drift.dart' show Value;
import 'package:setding/data/database.dart';
import 'package:setding/ui/trash/trash_screen.dart';

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

    // The trash is at the end of the list, also when every set is deleted
    // (#882), with the number of deleted sets (#888).
    expect(find.text('Trash (1)'), findsOneWidget);
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
    // An empty trash is not offered (#888).
    expect(find.byKey(const Key('sets-trash')), findsNothing);
    await app.dispose(tester);
  });

  // #888: the trash on the sets page was too prominent; it is a small link
  // that appears only while it holds deleted sets.
  for (final deleted in [0, 2]) {
    testWidgets('the sets page with $deleted deleted sets', (tester) async {
      useTabletSize(tester, landscape: false);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.runAsync(() async {
        await app.sets.createSet(name: 'Gig');
        for (var i = 0; i < deleted; i++) {
          await app.sets.deleteSet(await app.sets.createSet(name: 'Old $i'));
        }
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sets').first);
      await tester.pumpAndSettle();
      expect(find.text('Gig'), findsOneWidget);
      // No row of its own any more, only the link.
      expect(find.widgetWithText(ListTile, 'Trash'), findsNothing);
      expect(
        find.widgetWithText(TextButton, 'Trash ($deleted)'),
        deleted == 0 ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(const Key('sets-trash')),
        deleted == 0 ? findsNothing : findsOneWidget,
      );
      await app.dispose(tester);
    });
  }

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

  // ADR-0070: a PDF deleted on its own counts against the storage until it
  // is deleted permanently, from the trash of its organization's library.
  testWidgets('a deleted PDF is in the trash and is deleted permanently', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
    final id = (await tester.runAsync(() async {
      final song = await songs.createSong(source: '{title: Morning Light}');
      final a = await songs.addAttachment(
        song,
        name: 'Horns',
        bytes: Uint8List.fromList('%PDF-1.4 x'.codeUnits),
      );
      await (app.db.update(
        app.db.attachments,
      )..where((x) => x.id.equals(a))).write(
        AttachmentsCompanion(
          revision: const Value(1),
          deleted: const Value(true),
          deletedAt: Value(DateTime.now()),
        ),
      );
      return a;
    }))!;
    await tester.pumpWidget(
      app.build(home: const TrashScreen.songs(libraryId: 'o1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Attachment in “Morning Light”'),
      findsOneWidget,
    );
    expect(find.textContaining('Deleted attachments count'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('trash-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Horns'), findsNothing);
    final row = await tester.runAsync(
      () => (app.db.select(
        app.db.attachments,
      )..where((x) => x.id.equals(id))).getSingle(),
    );
    expect(row!.purged, isTrue);
    await app.dispose(tester);
  });
}
