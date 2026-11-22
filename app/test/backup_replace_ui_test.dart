import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:setding/ui/backup/backup_actions.dart';
import 'package:setding/ui/backup/full_backup.dart';
import 'package:setding/ui/backup/replace_local.dart';
import 'package:setding/ui/widgets/export_file.dart';

import 'test_app.dart';

/// Restoring by replacing the local library in the UI (ADR-0054 section 2).
void main() {
  late List<String> saved;
  late bool saveResult;

  setUp(() {
    saved = [];
    saveResult = true;
  });

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

  /// A local library with "Old" in a backup, then "New" added and "Old"
  /// changed; returns the backup.
  Future<Uint8List> prepare(WidgetTester tester, TestApp app) async =>
      (await tester.runAsync(() async {
        final old = await app.songs.createSong(source: '{title: Old}\n[C]A');
        final zip = await BackupService(app.db, app.storage).export(
          localBandId,
          libraryName: 'On this device',
          device: 'Old tablet',
        );
        await app.songs.createSong(source: '{title: New}');
        await app.songs.updateSource(old, '{title: Old}\n[G]B');
        return zip;
      }))!;

  Future<void> open(
    WidgetTester tester,
    TestApp app,
    Future<void> Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(
      app.build(
        extra: [
          saveFileProvider.overrideWithValue((
            name,
            bytes, {
            mimeType = '',
          }) async {
            if (saveResult) saved.add(name);
            return saveResult;
          }),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => action(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-import-start')).evaluate().isNotEmpty,
    );
  }

  Future<List<String>> titles(WidgetTester tester, TestApp app) async =>
      (await tester.runAsync(() async {
        final songs = await (app.db.select(
          app.db.songs,
        )..where((s) => s.libraryId.equals(localBandId))).get();
        return [for (final s in songs) '${s.title}:${s.chordproSource}'];
      }))!;

  Future<void> chooseReplace(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('backup-mode-replace')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already here'), findsNothing);
    await tester.tap(find.byKey(const Key('backup-import-start')));
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-replace')).evaluate().isNotEmpty,
    );
  }

  test('the safety backup is named like an automatic backup but never '
      'counted as one (#874)', () {
    final name = safetyBackupFileName('Tab', DateTime(2026, 5, 2, 8, 30));
    expect(name, 'Backup Tab 2026-05-02 0830 before restore.setDING.zip');
    expect(autoBackupsOf('Tab', [name]), isEmpty);
  });

  testWidgets('replaces the local library after a safety backup', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = await prepare(tester, app);
    await open(tester, app, (context) => importBackup(context, zip));
    await chooseReplace(tester);
    expect(find.textContaining('Backup of “Old tablet” from'), findsOneWidget);
    expect(find.textContaining('Now on this device: 2 songs'), findsOneWidget);
    expect(find.text('You choose where to save it.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-replace-start')));
    await waitFor(
      tester,
      () => find.textContaining('Local library replaced').evaluate().isNotEmpty,
    );
    expect(saved.single, endsWith(' before restore.setDING.zip'));
    expect(await titles(tester, app), ['Old:{title: Old}\n[C]A']);
    await app.dispose(tester);
  });

  testWidgets('the safety backup goes into the automatic backup folder', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        AutoBackupController.enabledKey: true,
        AutoBackupController.locationKey: '/cloud/Band',
        AutoBackupController.folderNameKey: 'Band',
      },
    );
    final zip = await prepare(tester, app);
    await open(tester, app, (context) => importBackup(context, zip));
    await chooseReplace(tester);
    expect(
      find.text('Into the folder of the automatic backup (Band).'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('backup-replace-start')));
    await waitFor(
      tester,
      () => find.textContaining('Local library replaced').evaluate().isNotEmpty,
    );
    expect(saved, isEmpty);
    final name = app.backupFolder.files.keys.single;
    expect(name, startsWith('Backup Test tablet '));
    expect(name, endsWith(' before restore.setDING.zip'));
    // It holds the library as it was before.
    final safety = (await tester.runAsync(
      () => BackupService.read(app.backupFolder.files[name]!),
    ))!;
    expect(safety.songs, hasLength(2));
    // Never removed as an old automatic backup.
    expect(autoBackupsOf('Test tablet', [name]), isEmpty);
    await app.dispose(tester);
  });

  testWidgets('the safety backup can be skipped', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = await prepare(tester, app);
    await open(tester, app, (context) => importBackup(context, zip));
    await chooseReplace(tester);
    await tester.tap(find.byKey(const Key('backup-replace-safety')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be restored'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-replace-start')));
    await waitFor(
      tester,
      () => find.textContaining('Local library replaced').evaluate().isNotEmpty,
    );
    expect(saved, isEmpty);
    expect(await titles(tester, app), hasLength(1));
    await app.dispose(tester);
  });

  testWidgets('nothing is replaced when the safety backup is not saved', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = await prepare(tester, app);
    saveResult = false;
    await open(tester, app, (context) => importBackup(context, zip));
    await chooseReplace(tester);
    await tester.tap(find.byKey(const Key('backup-replace-start')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Local library replaced'), findsNothing);
    expect(await titles(tester, app), hasLength(2));
    await app.dispose(tester);
  });

  testWidgets('the local library of a full backup can replace it', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = (await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Old}');
      final zip = await BackupService(app.db, app.storage).exportAll(
        libraries: [(id: localBandId, name: 'On this device')],
        personalOnly: const [],
        personalSettings: const {},
        deviceSettings: const {},
      );
      await app.songs.createSong(source: '{title: New}');
      return zip;
    }))!;
    await tester.pumpWidget(
      app.build(
        extra: [
          saveFileProvider.overrideWithValue((
            name,
            bytes, {
            mimeType = '',
          }) async {
            saved.add(name);
            return true;
          }),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openBackup(context, zip),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitFor(
      tester,
      () => find
          .byKey(const Key('backup-restore-replace-local'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('backup-restore-replace-local')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-full-restore-start')));
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-replace')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('backup-replace-start')));
    await waitFor(
      tester,
      () => find
          .byKey(const Key('backup-full-restore-result'))
          .evaluate()
          .isNotEmpty,
    );
    expect(saved.single, endsWith(' before restore.setDING.zip'));
    expect(await titles(tester, app), ['Old:{title: Old}']);
    await app.dispose(tester);
  });

  testWidgets('an organization archive offers no replacing', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = (await tester.runAsync(() async {
      final contents = await BackupService.read(
        await BackupService(
          app.db,
          app.storage,
        ).export(localBandId, libraryName: 'On this device'),
      );
      return zipArchive({
        ...contents.files,
        backupManifestName: BackupService.json({
          ...contents.manifest,
          'source': {'kind': 'organization', 'id': 'o1', 'name': 'School'},
        }),
      });
    }))!;
    await open(tester, app, (context) => importBackup(context, zip));
    expect(find.byKey(const Key('backup-mode-replace')), findsNothing);
    expect(find.textContaining('imported as a copy'), findsOneWidget);
    await app.dispose(tester);
  });
}
