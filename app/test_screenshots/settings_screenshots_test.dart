// Screenshots of the organization, band and settings screens.
// See screenshot_support.dart.

import 'package:chordpro/chordpro.dart' show SectionRole;
import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:setding/ui/backup/backup_actions.dart';
import 'package:setding/ui/bands/band_screen.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/platform/input_devices.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/update/app_menu_entry.dart';
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
      // Its hint says the person joins no band yet (issue #893).
      await shot(tester, '${lang}_13a_invite_hint');
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
      // The band's invitation hint says the role it gives (issue #901).
      await tester.scrollUntilVisible(
        find.byKey(const Key('invite-create')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(tester, '${lang}_14a_invite_band_hint');

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
      // The editor: controls next to the preview (#478); tapping a section
      // in the preview selects its type and frames it (#1040).
      await tester.tap(find.byKey(const Key('song-display-customise')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey(('role-target', SectionRole.chorus))).first,
      );
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

  // The automatic backup of the local library (ADR-0054), its own
  // section of *Storage & info*: folder, the last backup, backups kept,
  // device name.
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
          // The storage and the path of the folder (#889).
          AutoBackupController.folderNameKey: 'Documents/Band/setDING-Backup',
          AutoBackupController.folderPlaceKey: lang == 'de'
              ? 'Interner gemeinsamer Speicher'
              : 'Internal shared storage',
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
        find.byKey(const Key('auto-backup-device')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // The section from its heading on.
      await tester.ensureVisible(
        find.text(lang == 'de' ? 'Automatische Sicherung' : 'Automatic backup'),
      );
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_43_settings_auto_backup');
      await app.dispose(tester);
    });
  }

  // In-app help (#993): the book icon next to the title of a category and
  // the user guide entry under Help & info.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings help $lang', (tester) async {
      // Upright, so the title with its help button and the entry at the
      // end of the category fit together.
      useTabletSize(tester, landscape: false);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      expect(find.byKey(const Key('settings-category-docs')), findsOneWidget);
      expect(find.byKey(const Key('settings-docs')), findsOneWidget);
      await shot(tester, '${lang}_51_settings_help');
      await app.dispose(tester);
    });
  }

  // The application menu entry of the Linux AppImage (#1006) under
  // *Storage & info → This device*.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings app menu entry $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: const SettingsScreen(),
            extra: [appMenuEntryProvider.overrideWithValue(_MenuEntry())],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      await tester.ensureVisible(find.byKey(const Key('app-menu-entry')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_52_settings_app_menu_entry');
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
  // Hiding the local library (ADR-0054): the setting in *Storage & backup*
  // and the hint after switching it off.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('hide local library $lang', (tester) async {
      useTabletSize(tester);
      const ann = AuthUser(
        id: 'ann',
        email: 'ann@example.test',
        name: 'Ann Keller',
      );
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          // Nothing runs on the settings screen alone.
          AutoBackupController.enabledKey: true,
          AutoBackupController.locationKey: 'content://nextcloud/setDING',
          AutoBackupController.folderNameKey: 'Nextcloud › setDING',
        },
        user: ann,
      );
      app.backend.addBand('b1', 'Rock Band', admin: ann);
      await tester.runAsync(() async {
        for (final t in ['Hallelujah', 'Rocky Road', 'Demo']) {
          await app.songs.createSong(source: '{title: $t}');
        }
        await app.sets.createSet(name: lang == 'de' ? 'Probe' : 'Rehearsal');
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      final tile = find.byKey(const Key('settings-show-local-library'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await shot(tester, '${lang}_45_hide_local_library');
      await app.dispose(tester);
    });
  }

  // Space starts the beat instead of turning (#969), switched on, in the
  // controls of the live settings of a drummer.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings space beat $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'drums',
          'spaceStartsBeat': true,
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-live')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('settings-space-starts-beat'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_19c_settings_space_beat');
      await app.dispose(tester);
    });
  }

  // The language drop-down of the general settings, open (#983).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings language $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-general')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-language')));
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_18b_settings_language');
      await app.dispose(tester);
    });
  }

  // The paired page turner in the live settings (ADR-0057, #913), connected.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings page turner $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const pedal = InputDeviceInfo(
        name: 'AirTurn DUO',
        vendorId: 0x1234,
        productId: 0x5678,
      );
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          PairedPageTurnerNotifier.nameKey: pedal.name,
          PairedPageTurnerNotifier.vendorKey: pedal.vendorId,
          PairedPageTurnerNotifier.productKey: pedal.productId,
        },
      );
      app.inputDevices.connected.add(pedal);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-live')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('settings-page-turner'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-page-turner-paired')), findsOne);
      await shot(tester, '${lang}_19b_settings_page_turner');
      await app.dispose(tester);
    });
  }

  // An instrument entered as voice or role gets a hint (#939).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings voice hint $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'guitar',
          'userName': 'bass',
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-musician')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('settings-voice'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_16a_settings_voice_hint');
      await app.dispose(tester);
    });
  }

  // A chorus written out again shown only once (#955): the switch in the
  // display settings.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings chorus once $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'repeatedChorusOnce': true,
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-display')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('settings-repeated-chorus-once'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_17b_settings_chorus_once');
      await app.dispose(tester);
    });
  }

  // The spelling of Roman numerals (ADR-0059) in the display settings.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('settings numeral spelling $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'chordView': 'numerals',
          'numeralSpelling': 'chordSymbol',
          'chordStyle': 'standard',
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-display')));
      await tester.pumpAndSettle();
      // The chord view above the spelling, so both are in the picture.
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-chord-view')),
        200,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-numeral-spelling')).hitTestable(),
        findsOneWidget,
      );
      await shot(tester, '${lang}_17c_settings_numeral_spelling');
      await app.dispose(tester);
    });
  }
}

/// An AppImage not yet in the application menu (#1006).
class _MenuEntry implements AppMenuEntry {
  @override
  Future<AppMenuEntryState> state() async => AppMenuEntryState.missing;

  @override
  Future<void> install() async {}

  @override
  Future<void> remove() async {}

  @override
  Future<bool> repairIfMoved() async => false;
}
