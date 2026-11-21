// Screenshots of the splash screen, the set list and the set archive.
// See screenshot_support.dart.

import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/ui/widgets/export_file.dart' show saveFileProvider;
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/widgets/logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  for (final dark in [false, true]) {
    screenshotTest('sets grouped by gig date ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      useTabletSize(tester, landscape: false);
      final app = await TestApp.create(
        // Past sets expanded, to show all three sections.
        prefs: {
          'language': 'de',
          'themeMode': dark ? 'dark' : 'light',
          'pastSetsCollapsed': false,
        },
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        for (final (name, venue, days) in [
          ('Sommerfest', 'Bern', 3),
          ('Hochzeit Meier', 'Thun', 17),
          ('Probe', null, null),
          ('Jazznacht', 'Biel', -12),
          ('Weihnachtskonzert', 'Luzern', -200),
        ]) {
          await app.sets.createSet(
            name: name,
            venue: venue,
            gigDate: days == null ? null : today.add(Duration(days: days)),
          );
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await shot(tester, 'de_1_sets_grouped${dark ? '_dark' : ''}');
      await app.dispose(tester);
    });
  }

  for (final dark in [false, true]) {
    screenshotTest('splash ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.5;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SplashScreen(),
          ),
        ),
      );
      await shot(tester, '0_splash_${dark ? 'dark' : 'light'}');
    });
  }

  // Set archive (ADR-0043 §1b, #707): the export options, the preview of an
  // import that finds the set again and the report.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('set archive $lang', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final (setId, zip) = (await tester.runAsync(() async {
        final morning = await app.songs.createSong(
          source:
              '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
              '[D]Morning light on the [G]hill\n',
        );
        final grace = await app.songs.createSong(
          source: '{title: Amazing Grace}\n{key: G}\n[G]Amazing grace\n',
        );
        await ArrangementRepository(app.db)
            .save(localBandId, morning, transpose: 2, sequence: 'V1, C, V2, C');
        final set = await app.sets.createSet(
          name: lang == 'de' ? 'Sommerfest' : 'Summer party',
          gigDate: DateTime(2027, 6, 21),
          venue: 'Bern',
        );
        await app.sets.addSongs(set, [morning]);
        await app.sets.addMarker(set, MarkerIcons.breakIcon, '');
        await app.sets.addSongs(set, [grace]);
        final zip = await SetArchiveService(BackupService(app.db, app.storage))
            .export(set);
        // Gone from the library since: the import adds it again.
        await app.songs.deleteSong(grace);
        return (set, zip);
      }))!;

      var pdfSaved = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: SetScreen(setId: setId),
            extra: [
              saveFileProvider.overrideWithValue((
                name,
                bytes, {
                mimeType = '',
              }) async {
                pdfSaved = true;
                return true;
              }),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openSetMenu() async {
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
      }

      // After the PDF export, the message offers "Open" (#721).
      await openSetMenu();
      await tester.tap(
        find.text(
          lang == 'de'
              ? 'Set-Liste exportieren (PDF zum Drucken)'
              : 'Export set list (PDF for printing)',
        ),
      );
      // The PDF is built outside the fake clock (fonts, isolates).
      for (var i = 0; i < 200 && !pdfSaved; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(SnackBarAction), findsOneWidget);
      await shot(tester, '${lang}_28_set_pdf_exported');
      ScaffoldMessenger.of(tester.element(find.byType(SetScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await openSetMenu();
      await tester.tap(
        find.text(lang == 'de' ? 'Als ZIP exportieren' : 'Export as ZIP'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-export')), findsOneWidget);
      await shot(tester, '${lang}_27_set_export');

      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showImportDialog(
                      context,
                      pick: ({extensions}) async => [
                        ImportFile('set.zip', zip),
                      ],
                    ),
                    child: const Text('import'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'de' ? 'Dateien auswählen' : 'Choose files'),
      );
      // The preview reads the database outside the fake clock.
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(finder, findsOneWidget);
      }

      await waitFor(find.byKey(const Key('set-import-replace')));
      // As a copy: the preview shows the copy name (#719).
      await tester.tap(find.byKey(const Key('set-import-copy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-import-new-name')), findsOneWidget);
      await shot(tester, '${lang}_27b_set_import');
      await tester.tap(find.byKey(const Key('set-import-start')));
      await waitFor(find.byKey(const Key('set-import-result')));
      await shot(tester, '${lang}_27c_set_import_result');
      await app.dispose(tester);
    });
  }
}
