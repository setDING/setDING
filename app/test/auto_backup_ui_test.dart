import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/platform/backup_folder.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/settings/settings_layout.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

/// Automatic backup of the local library in the settings and at the start
/// (ADR-0054).
void main() {
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

  // #891: Storage & info in three sections, the automatic backup its own
  // (ADR-0050 rule 5), the local library apart from the backups.
  testWidgets('the storage tiles sit in their sections', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', AutoBackupController.enabledKey: true},
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openStorage(tester);

    Finder inSection(String title, String key) => find.ancestor(
      of: find.byKey(Key(key)),
      matching: find.byWidgetPredicate(
        (w) => w is SettingsSection && w.title == title,
      ),
    );
    for (final key in ['backup-all', 'backup-restore']) {
      expect(inSection('Backup', key), findsOneWidget, reason: key);
    }
    for (final key in [
      'auto-backup',
      'auto-backup-folder',
      'auto-backup-now',
      'auto-backup-keep',
      'auto-backup-device',
    ]) {
      expect(inSection('Automatic backup', key), findsOneWidget, reason: key);
    }
    expect(
      inSection('This device', 'settings-show-local-library'),
      findsOneWidget,
    );
    // Back up everything and the automatic backup's button differ.
    expect(find.text('Back up to the folder now'), findsOneWidget);
    Icon iconOf(String key) => tester.widget<Icon>(
      find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(Icon))
          .first,
    );
    expect(iconOf('auto-backup-now').icon, isNot(iconOf('backup-all').icon));
    await app.dispose(tester);
  });

  // #891: the automatic backup only backs up the local library, so it is
  // hidden with it; while it is still on, it stays to be switched off.
  for (final enabled in [false, true]) {
    testWidgets('with the local library hidden, the section is '
        '${enabled ? 'shown while it is on' : 'hidden'}', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': 'en',
          'showLocalLibrary': false,
          AutoBackupController.enabledKey: enabled,
        },
        user: const AuthUser(
          id: 'u-ann@example.test',
          email: 'ann@example.test',
          name: 'Ann',
        ),
      );
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await openStorage(tester);
      expect(
        find.byKey(const Key('settings-show-local-library')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('auto-backup')),
        enabled ? findsOneWidget : findsNothing,
      );
      await app.dispose(tester);
    });
  }

  testWidgets('switching it on chooses the folder and writes a backup', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    app.backupFolder.choice = (
      location: '/cloud/Band',
      name: 'Band',
      place: null,
    );
    await tester.runAsync(() => app.songs.createSong(source: '{title: A}'));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openStorage(tester);
    expect(find.byKey(const Key('auto-backup-folder')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('auto-backup')));
    await tester.tap(find.byKey(const Key('auto-backup')));
    await tester.pump();
    await waitFor(tester, () => app.backupFolder.files.isNotEmpty);

    final name = app.backupFolder.files.keys.single;
    expect(name, startsWith('Backup Test tablet '));
    final contents = (await tester.runAsync(
      () => BackupService.read(app.backupFolder.files[name]!),
    ))!;
    expect(contents.songs, hasLength(1));
    expect(contents.sourceName, 'On this device');
    expect(find.text('Band'), findsOneWidget);
    expect(find.textContaining('Last automatic backup:'), findsOneWidget);
    expect(app.prefs.getBool(AutoBackupController.enabledKey), isTrue);
    expect(app.prefs.getString(lastBackupKey), isNotNull);

    // The number kept, once the message is gone.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('auto-backup-keep-value')));
    await tester.tap(find.byKey(const Key('auto-backup-keep-value')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    expect(app.prefs.getInt(AutoBackupController.keepKey), 3);
    await app.dispose(tester);
  });

  testWidgets('without a chosen folder it stays off', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openStorage(tester);
    await tester.ensureVisible(find.byKey(const Key('auto-backup')));
    await tester.tap(find.byKey(const Key('auto-backup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auto-backup-folder')), findsNothing);
    expect(app.prefs.getBool(AutoBackupController.enabledKey), isNull);
    await app.dispose(tester);
  });

  testWidgets('a backup at the start; a failed one shows a hint with the '
      'folder choice', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        AutoBackupController.enabledKey: true,
        AutoBackupController.locationKey: '/cloud/Band',
        AutoBackupController.folderNameKey: 'Band',
      },
    );
    await tester.runAsync(() => app.songs.createSong(source: '{title: A}'));
    app.backupFolder.error = BackupFolderError.permission;
    await tester.pumpWidget(app.build());
    await waitFor(
      tester,
      () => find.byKey(const Key('auto-backup-failed')).evaluate().isNotEmpty,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('auto-backup-failed')),
        matching: find.textContaining('may no longer write into the folder'),
      ),
      findsOneWidget,
    );
    // The overview's readiness tile shows it as a warning too (#911).
    expect(
      find.descendant(
        of: find.byKey(const Key('overview-readiness-backup')),
        matching: find.textContaining('may no longer write into the folder'),
      ),
      findsOneWidget,
    );

    // Choosing the folder again writes the backup.
    app.backupFolder
      ..error = null
      ..choice = (location: '/cloud/Band2', name: 'Band2', place: null);
    await tester.tap(find.byKey(const Key('auto-backup-failed-action')));
    await tester.pump();
    await waitFor(tester, () => app.backupFolder.files.isNotEmpty);
    expect(
      app.prefs.getString(AutoBackupController.locationKey),
      '/cloud/Band2',
    );
    expect(app.prefs.getString(AutoBackupController.errorKey), isNull);
    await app.dispose(tester);
  });

  testWidgets('the folder shows its storage and path (#889)', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        AutoBackupController.enabledKey: true,
        AutoBackupController.locationKey: 'content://tree/1',
        AutoBackupController.folderNameKey: 'Backups',
        // Backed up today: no backup at the start.
        AutoBackupController.lastAtKey: DateTime.now().toIso8601String(),
      },
    );
    // A folder chosen before #889 is described at the start.
    app.backupFolder.described = (
      location: 'content://tree/1',
      name: 'Documents/Band/Backups',
      place: 'Internal shared storage',
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openStorage(tester);
    final tile = find.byKey(const Key('auto-backup-folder'));
    await tester.ensureVisible(tile);
    expect(
      find.descendant(of: tile, matching: find.text('Internal shared storage')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Documents/Band/Backups')),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('no backup reminder while automatic backups succeed', (
    tester,
  ) async {
    useTabletSize(tester);
    final old = DateTime.now().subtract(const Duration(days: 40));
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        AutoBackupController.enabledKey: true,
        AutoBackupController.locationKey: '/cloud/Band',
        AutoBackupController.lastAtKey: DateTime.now().toIso8601String(),
        lastBackupKey: old.toIso8601String(),
      },
    );
    await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Old}');
      await (app.db.update(app.db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(updatedAt: Value(old)),
      );
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-reminder')), findsNothing);
    await app.dispose(tester);
  });
}
