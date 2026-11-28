import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:chordpro/chordpro.dart' show ChordNotation;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/widgets/export_file.dart';
import 'package:setding/ui/backup/full_backup.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Full backup in the settings (#639).
void main() {
  late List<(String, Uint8List)> saved;

  setUp(() => saved = []);

  Widget build(TestApp app, {Widget? home}) => app.build(
    home: home,
    extra: [
      saveFileProvider.overrideWithValue((name, bytes, {mimeType = ''}) async {
        saved.add((name, bytes));
        return true;
      }),
    ],
  );

  /// Waits for [done] in real time (database, isolates).
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

  Future<void> openStorage(WidgetTester tester) async {
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.about);
  }

  testWidgets('everything is backed up: libraries with rights in full, '
      'otherwise the personal adjustments', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _ann);
    app.backend.addOrganization('o1', 'School', admin: _ann);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    // In "Choir" Ann leads a band but has no library rights.
    app.backend.addOrganization('o2', 'Choir', admin: _bob);
    app.backend.addBand('b2', 'Choir', admin: _ann, organizationId: 'o2');
    await tester.pumpWidget(build(app));
    await tester.pumpAndSettle();
    await openStorage(tester);
    expect(
      find.textContaining('Not backed up on this device yet.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('backup-all')));
    await tester.pump();
    await waitFor(tester, () => saved.isNotEmpty);

    final (name, bytes) = saved.single;
    expect(name, startsWith('Backup all '));
    final backup = (await tester.runAsync(
      () => BackupService.readFull(bytes),
    ))!;
    expect(backup.isFull, isTrue);
    expect([
      for (final l in backup.libraries) (l.manifest['source'] as Map)['id'],
    ], unorderedEquals([localBandId, 'o1']));
    expect([for (final p in backup.personal) p.libraryId], ['o2']);
    expect(backup.personalSettings['language'], 'en');
    expect(backup.deviceSettings.containsKey('serverUrl'), isFalse);
    expect(app.prefs.getString(lastBackupKey), isNotNull);
    expect(find.textContaining('Last backup:'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a full backup is restored, the settings only on request', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final zip = (await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: From backup}');
      final zip = await BackupService(app.db, app.storage).exportAll(
        libraries: [(id: localBandId, name: 'Old phone')],
        personalSettings: {'notation': 'german'},
      );
      await app.db.delete(app.db.songs).go();
      return zip;
    }))!;
    await tester.pumpWidget(
      build(
        app,
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
      () => find.byKey(const Key('backup-full-restore')).evaluate().isNotEmpty,
    );
    expect(find.textContaining('"Old phone" (1 song, 0 sets)'), findsOneWidget);
    final settings = find.byKey(const Key('backup-restore-settings'));
    expect(tester.widget<CheckboxListTile>(settings).value, isFalse);
    await tester.tap(settings);
    await tester.pump();
    await tester.tap(find.byKey(const Key('backup-full-restore-start')));
    await waitFor(
      tester,
      () => find
          .byKey(const Key('backup-full-restore-result'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.textContaining('1 song imported'), findsOneWidget);
    expect(find.textContaining('Settings restored'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('backup-full-restore-result'))),
    );
    expect(container.read(settingsProvider).notation, ChordNotation.german);
    await app.dispose(tester);
  });

  // #1244: a damaged ZIP threw an archive error that openBackup did not
  // catch, so nothing was shown; a ZIP bomb was unpacked in full.
  testWidgets('a damaged backup and a ZIP bomb are refused with a message', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final bomb = (await tester.runAsync(() async {
      final archive = Archive()
        ..addFile(ArchiveFile('bomb.cho', 80 << 20, Uint8List(80 << 20)));
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }))!;
    final damaged = Uint8List.fromList('PK\x03\x04 damaged'.codeUnits);
    Uint8List zip = damaged;
    await tester.pumpWidget(
      build(
        app,
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
      () =>
          find.text('This file is not a setDING backup.').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));
    zip = bomb;
    await tester.tap(find.text('open'));
    await waitFor(
      tester,
      () => find
          .text(
            'This file contains too many or too large files and is not '
            'imported.',
          )
          .evaluate()
          .isNotEmpty,
    );
    await app.dispose(tester);
  });

  testWidgets('the local library reminds of a backup after 30 days', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Old}');
      await (app.db.update(app.db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          updatedAt: Value(DateTime.now().subtract(const Duration(days: 40))),
        ),
      );
    });
    await tester.pumpWidget(build(app));
    await waitFor(
      tester,
      () => find.byKey(const Key('backup-reminder')).evaluate().isNotEmpty,
    );
    expect(
      find.textContaining('not been backed up for 40 days'),
      findsOneWidget,
    );
    expect(app.prefs.getString(backupReminderKey), isNotNull);
    await app.dispose(tester);
  });

  testWidgets('no reminder for a fresh backup', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        lastBackupKey: DateTime.now().toIso8601String(),
      },
    );
    await tester.runAsync(() => app.songs.createSong(source: '{title: New}'));
    await tester.pumpWidget(build(app));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-reminder')), findsNothing);
    await app.dispose(tester);
  });
}
