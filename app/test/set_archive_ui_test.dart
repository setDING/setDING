import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/backup/backup_actions.dart';
import 'package:setding/ui/sets/set_archive_dialogs.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/import_dialog.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Set archive of ADR-0043 §1b (#707) in the UI.
void main() {
  /// The export and import run outside the fake clock (database, isolates):
  /// waits for [done] in real time.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
    await tester.pumpAndSettle();
  }

  bool shown(Key key) => find.byKey(key).evaluate().isNotEmpty;

  testWidgets('a set is exported with the chosen options', (tester) async {
    useTabletSize(tester);
    final saved = <(String, Uint8List)>[];
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = (await tester.runAsync(() async {
      final song = await app.songs.createSong(source: '{title: Hello}\n[C]x');
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [song]);
      return set;
    }))!;
    await tester.pumpWidget(
      app.build(
        home: SetScreen(setId: setId),
        extra: [
          saveFileProvider.overrideWithValue((
            name,
            bytes, {
            mimeType = '',
          }) async {
            saved.add((name, bytes));
            return true;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export as ZIP'));
    await tester.pumpAndSettle();

    expect(find.text('Export set'), findsOneWidget);
    final personal = find.byKey(const Key('set-export-personal'));
    expect(tester.widget<CheckboxListTile>(personal).value, isFalse);
    expect(
      find.text('Leave this off if you pass the file on.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('set-export-attachments')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-export-start')));
    await waitFor(tester, () => saved.isNotEmpty);

    expect(saved.single.$1, 'Gig.zip');
    final archive = (await tester.runAsync(
      () => SetArchiveService.read(saved.single.$2),
    ))!;
    expect(archive.name, 'Gig');
    expect(
      archive.holds,
      const SetArchiveOptions(attachments: false, personal: false),
    );
    expect(find.text('Exported'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the import dialog recognises an exported set and replaces the '
      'set it came from', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (setId, zip) = (await tester.runAsync(() async {
      final song = await app.songs.createSong(source: '{title: Hello}\n[C]x');
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [song]);
      final zip = await SetArchiveService(BackupService(app.db, app.storage))
          .export(set);
      // Changed since: the import puts it back.
      await app.sets.updateSet(set, name: 'Changed');
      await app.sets.addMarker(set, SetItemType.text, 'Later');
      return (set, zip);
    }))!;

    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => [ImportFile('Gig.zip', zip)],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files'));
    await waitFor(tester, () => shown(const Key('set-import-replace')));
    expect(find.text('Import set'), findsOneWidget);
    expect(find.textContaining('"Gig" from'), findsOneWidget);
    expect(
      find.text('This set is already in the band as "Changed":'),
      findsOneWidget,
    );
    expect(find.textContaining('1 song is already here'), findsOneWidget);
    expect(find.text('Also import:'), findsOneWidget);

    await tester.tap(find.byKey(const Key('set-import-start')));
    await waitFor(tester, () => shown(const Key('set-import-result')));
    expect(
      find.textContaining('The existing set was replaced.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    List<SetSummary>? sets;
    unawaited(app.sets.watchSets().first.then((s) => sets = s));
    await waitFor(tester, () => sets != null);
    expect(sets!.single.set.id, setId);
    expect(sets!.single.set.name, 'Gig');
    expect(sets!.single.itemCount, 1);
    await app.dispose(tester);
  });

  testWidgets('a set planner imports a set: missing songs become text items', (
    tester,
  ) async {
    useTabletSize(tester);
    final source = await TestApp.create(prefs: {'language': 'en'});
    final zip = (await tester.runAsync(() async {
      final song = await source.songs.createSong(source: '{title: New one}');
      final set = await source.sets.createSet(name: 'Gig');
      await source.sets.addSongs(set, [song]);
      return SetArchiveService(BackupService(source.db, source.storage))
          .export(set);
    }))!;
    await tester.runAsync(source.db.close);

    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.planner);
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => importSetArchive(context, zip),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await waitFor(
      tester,
      () =>
          shown(const Key('set-import-start')) &&
          find.textContaining('not in the library').evaluate().isNotEmpty,
    );
    expect(find.text('• New one'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set-import-start')));
    await waitFor(tester, () => shown(const Key('set-import-result')));
    expect(
      find.text('Not in the library, shown as text items in the set:'),
      findsOneWidget,
    );

    final items = <SetItemView>[];
    unawaited(
      SetRepository(app.db, app.storage, bandId: 'b1').watchSets().first.then(
        (sets) async => items.addAll(
          await SetRepository(
            app.db,
            app.storage,
            bandId: 'b1',
          ).getItems(sets.single.set.id),
        ),
      ),
    );
    await waitFor(tester, () => items.isNotEmpty);
    expect(items.single.item.type, SetItemType.text);
    expect(items.single.item.note, 'Missing: New one');
    await app.dispose(tester);
  });
}
