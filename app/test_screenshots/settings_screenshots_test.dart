// Screenshots of the organization, band and settings screens.
// See screenshot_support.dart.

import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:setding/ui/backup/backup_actions.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // Organization, band and invitation screens for the user documentation
  // (website, ADR-0030), signed in as the organization admin.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('organization and band $lang', (tester) async {
      useTabletSize(tester);
      const ann = AuthUser(
        id: 'ann',
        email: 'ann@example.test',
        name: 'Ann Keller',
      );
      const people = [
        AuthUser(id: 'ben', email: 'ben@example.test', name: 'Ben Frei'),
        AuthUser(id: 'cara', email: 'cara@example.test', name: 'Cara Meier'),
        AuthUser(id: 'dan', email: 'dan@example.test', name: 'Dan Huber'),
        AuthUser(id: 'eva', email: 'eva@example.test', name: 'Eva Graf'),
      ];
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
        user: ann,
      );
      final school = lang == 'de' ? 'Musikschule Bern' : 'Music School';
      app.backend.addOrganization('o1', school, admin: ann);
      app.backend.addBand('b1', 'Rock Band', admin: ann, organizationId: 'o1');
      app.backend.addBand('b2', 'Jazz Combo', admin: ann, organizationId: 'o1');
      app.backend.addOrgMember('o1', people[0], OrgRole.librarian);
      app.backend.addMember('b1', people[1], BandRole.planner);
      app.backend.addMember('b1', people[2], BandRole.member);
      app.backend.addMember('b2', people[3], BandRole.member);

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const OrganizationScreen(organizationId: 'o1'),
          ),
        ),
      );
      await shot(tester, '${lang}_12_organization');

      // The invitation button is below the people.
      await tester.scrollUntilVisible(
        find.byKey(const Key('invite-create')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_13_invite');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const BandScreen(bandId: 'b1')),
        ),
      );
      await shot(tester, '${lang}_14_band');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await shot(tester, '${lang}_15_settings');
      // The musician settings: instrument, voice, diagrams, beat.
      await tester.tap(find.text(lang == 'de' ? 'Musiker' : 'Musician'));
      await shot(tester, '${lang}_16_settings_musician');
      // On a wide screen the sections flow into two columns (#774).
      tester.view.physicalSize = const Size(1680, 900);
      await tester.tap(find.byKey(const Key('settings-category-general')));
      await shot(tester, '${lang}_18_settings_general');
      useTabletSize(tester);
      await tester.pumpAndSettle();
      // Song display styles (ADR-0033) with a preset of colours.
      await tester.tap(find.byKey(const Key('settings-category-songDisplay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-preset-colorCoded')));
      await shot(tester, '${lang}_20_settings_song_display');
      // The editor: controls next to the preview (#478).
      await tester.tap(find.byKey(const Key('song-display-customise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-display-type-chorus')));
      await shot(tester, '${lang}_21_song_display_editor');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Not every category fits on a landscape tablet.
      final live = find.byKey(const Key('settings-category-live'));
      await tester.ensureVisible(live);
      await tester.pumpAndSettle();
      await tester.tap(live);
      await shot(tester, '${lang}_19_settings_live');
      await app.dispose(tester);
    });
  }

  // Managing the own account (issue #779): the account category with
  // name and password, and the password dialog.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('account $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
        user: const AuthUser(
          id: 'ann',
          email: 'ann@example.test',
          name: 'Ann Keller',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.account);
      await shot(tester, '${lang}_35_account');
      await tester.tap(find.byKey(const Key('account-change-password')));
      await shot(tester, '${lang}_35b_change_password');
      await tester.tap(find.text(lang == 'de' ? 'Abbrechen' : 'Cancel'));
      await tester.pumpAndSettle();
      // Deleting the account (ADR-0052).
      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('delete-account-password')),
        'password-123',
      );
      await shot(tester, '${lang}_36_delete_account');
      await app.dispose(tester);
    });
  }

  // The automatic backup of the local library (ADR-0054) in *Storage &
  // backup*: folder, device name, backups kept, the last backup.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('auto backup $lang', (tester) async {
      useTabletSize(tester);
      final lastAt = DateTime(2026, 11, 22, 18, 30).toIso8601String();
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          AutoBackupController.enabledKey: true,
          AutoBackupController.locationKey: 'content://nextcloud/setDING',
          AutoBackupController.folderNameKey: 'Nextcloud › setDING',
          AutoBackupController.deviceKey: lang == 'de'
              ? 'Tablet Probe'
              : 'Rehearsal tablet',
          AutoBackupController.keepKey: 7,
          AutoBackupController.lastAtKey: lastAt,
          // The automatic backup counts as the last backup.
          lastBackupKey: lastAt,
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      await tester.scrollUntilVisible(
        find.byKey(const Key('auto-backup-now')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await shot(tester, '${lang}_43_settings_auto_backup');
      await app.dispose(tester);
    });
  }

  // Restoring by replacing the local library (ADR-0054): the choice in the
  // import of a backup of the local library and the preview with the
  // safety backup.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('replace local library $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          AutoBackupController.enabledKey: true,
          AutoBackupController.locationKey: 'content://nextcloud/setDING',
          AutoBackupController.folderNameKey: 'Nextcloud › setDING',
        },
      );
      final zip = (await tester.runAsync(() async {
        final titles = lang == 'de'
            ? ['Hallelujah', 'Rocky Road', 'Sternennacht']
            : ['Hallelujah', 'Rocky Road', 'Starry Night'];
        final ids = [
          for (final t in titles)
            await app.songs.createSong(source: '{title: $t}'),
        ];
        final set = await app.sets.createSet(
          name: lang == 'de' ? 'Sommerfest' : 'Summer party',
        );
        await app.sets.addSongs(set, ids);
        final zip = await BackupService(app.db, app.storage).export(
          localBandId,
          libraryName: lang == 'de' ? 'Auf diesem Gerät' : 'On this device',
          device: lang == 'de' ? 'Tablet Probe' : 'Rehearsal tablet',
          now: DateTime(2026, 11, 20, 21, 15),
        );
        await app.songs.createSong(source: '{title: Demo}');
        return zip;
      }))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => importBackup(context, zip),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find
            .byKey(const Key('backup-mode-replace'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.tap(find.byKey(const Key('backup-mode-replace')));
      await shot(tester, '${lang}_44_backup_replace_choice');
      await tester.tap(find.byKey(const Key('backup-import-start')));
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.byKey(const Key('backup-replace')).evaluate().isNotEmpty) {
          break;
        }
      }
      await shot(tester, '${lang}_44b_backup_replace');
      await app.dispose(tester);
    });
  }
}
