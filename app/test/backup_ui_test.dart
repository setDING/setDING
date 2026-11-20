import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/backup/backup_actions.dart';
import 'package:setding/ui/songs/import_dialog.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Backup archive of ADR-0043 in the UI.
void main() {
  /// Files saved by the export.
  late List<(String, Uint8List)> saved;

  setUp(() => saved = []);

  Future<TestApp> start(
    WidgetTester tester, {
    AuthUser? user,
    void Function(TestApp app)? server,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: user);
    server?.call(app);
    await tester.pumpWidget(
      app.build(
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
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    return app;
  }

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

  Future<void> backUp(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-backup')));
    await tester.pump();
  }

  testWidgets('the local library is saved as a backup', (tester) async {
    final app = await start(tester);
    await tester.runAsync(
      () => app.songs.createSong(source: '{title: Kept safe}'),
    );
    await backUp(tester);
    await waitFor(tester, () => saved.isNotEmpty);

    final (name, bytes) = saved.single;
    expect(name, startsWith('setDING-Backup On this device '));
    expect(name, endsWith('.zip'));
    final contents = (await tester.runAsync(() => BackupService.read(bytes)))!;
    expect(contents.songs.map((s) => s['title']), contains('Kept safe'));
    expect(find.text('Backup saved.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('an organization is not exported without a sync', (tester) async {
    final app = await start(
      tester,
      user: _ann,
      server: (app) {
        app.backend.addOrganization('o1', 'School', admin: _ann);
        app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      },
    );
    await tester.tap(find.byKey(const Key('library-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School').last);
    await tester.pumpAndSettle();
    app.backend.failWith = BackendErrorKind.network;

    await backUp(tester);
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-failed')).evaluate().isNotEmpty,
    );
    expect(find.text('Backup not possible'), findsOneWidget);
    expect(find.textContaining('needs a working connection'), findsOneWidget);
    expect(saved, isEmpty);

    // Online again: synced first, then saved.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    app.backend.failWith = null;
    await tester.runAsync(
      () => TestApp.songsIn(app, 'o1').createSong(source: '{title: New}'),
    );
    await backUp(tester);
    await waitFor(tester, () => saved.isNotEmpty);
    expect(saved.single.$1, startsWith('setDING-Backup School '));
    expect(app.backend.songs.values.map((s) => s.title), contains('New'));
    await app.dispose(tester);
  });

  testWidgets('a backup is imported from the import dialog', (tester) async {
    // Prepared before the UI starts: its database queries would wait for
    // the fake clock.
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = (await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Existing}\n[C]Same');
      final other = await app.songs.createSong(source: '{title: Other}');
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [other]);
      final zip = await BackupService(
        app.db,
        app.storage,
      ).export(localBandId, libraryName: 'Old phone');
      // Gone since: only "Other" and the set come back.
      await app.songs.deleteSong(other);
      await app.sets.deleteSet(set);
      return zip;
    }))!;

    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => [
                  ImportFile('setDING-Backup.zip', zip),
                ],
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
    await waitFor(
      tester,
      () =>
          find.byKey(const Key('backup-import-start')).evaluate().isNotEmpty &&
          find.textContaining('Backup of "Old phone"').evaluate().isNotEmpty,
    );
    expect(find.textContaining('1 song is already here'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-import-start')));
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-import-result')).evaluate().isNotEmpty,
    );
    expect(find.textContaining('1 song imported'), findsOneWidget);
    expect(find.textContaining('1 set imported'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    // The UI holds the database: read while pumping.
    List<SetSummary>? sets;
    unawaited(app.sets.watchSets().first.then((s) => sets = s));
    await waitFor(tester, () => sets != null);
    expect(sets!.single.set.name, 'Gig');
    expect(sets!.single.itemCount, 1);
    await app.dispose(tester);
  });
}
