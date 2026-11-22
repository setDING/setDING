// Screenshot of the overview with its cards (ADR-0045, #868).
// See screenshot_support.dart.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/platform/input_devices.dart';
import 'package:setding/ui/widgets/app_info.dart';
import 'package:setding/update/whats_new.dart';
import 'package:setding/util/app_version.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // The next set, more sets, newest songs and songs not played for a while;
  // the version and What's new at the bottom of the screen (#896).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('overview cards $lang', (tester) async {
      useTabletSize(tester, landscape: false);
      final app = await TestApp.create(
        prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        final ids = <String>[];
        for (final (i, (title, artist, key)) in [
          ('Amazing Grace', 'Traditional', 'G'),
          ('Danny Boy', 'Traditional', 'C'),
          ('Scarborough Fair', 'Traditional', 'Am'),
          ('When the Saints', 'Traditional', 'F'),
          ('Swing Low', 'Traditional', 'D'),
          ('Wayfaring Stranger', 'Traditional', 'Em'),
        ].indexed) {
          final id = await app.songs.createSong(
            source: '{title: $title}\n{artist: $artist}\n{key: $key}\n[$key]La',
          );
          ids.add(id);
          await (app.db.update(
            app.db.songs,
          )..where((s) => s.id.equals(id))).write(
            SongsCompanion(
              createdAt: Value(today.subtract(Duration(days: 3 + i * 4))),
            ),
          );
        }
        final longAgo = await app.sets.createSet(
          name: lang == 'de' ? 'Herbstkonzert' : 'Autumn concert',
          gigDate: DateTime(today.year - 1, today.month, today.day),
        );
        await app.sets.addSongs(longAgo, ids.sublist(2));
        for (final (name, venue, days) in [
          ('Sommerfest', 'Bern', 3),
          (lang == 'de' ? 'Hochzeit Meier' : 'Meier wedding', 'Thun', 17),
          (lang == 'de' ? 'Probe' : 'Rehearsal', null, 24),
          ('Jazznacht', 'Biel', 38),
        ]) {
          final id = await app.sets.createSet(
            name: name,
            venue: venue,
            gigDate: today.add(Duration(days: days)),
          );
          await app.sets.addSongs(id, ids.take(4).toList());
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(
            extra: [
              appVersionProvider.overrideWith((ref) async => '0.18.0 (1)'),
              recentNotesProvider.overrideWithValue(
                const VersionNotes('0.18.0', {
                  'en': ['Language versions of songs'],
                }),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overview-more-sets')), findsOneWidget);
      expect(find.byKey(const Key('overview-newest-songs')), findsOneWidget);
      expect(find.byKey(const Key('overview-not-played')), findsOneWidget);
      expect(find.byKey(const Key('overview-version')), findsOneWidget);
      expect(find.byKey(const Key('overview-whats-new')), findsOneWidget);
      await shot(tester, '${lang}_44_overview');
      await app.dispose(tester);
    });
  }

  // The readiness tile (#911) with its details: a keyboard that is not
  // connected (a warning), the next set offline, the page turner.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('overview readiness $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'instrument': 'keyboard',
          'userName': 'Ann',
          'midiEnabled': true,
          'midiOutputName': 'Nord Stage 3 MIDI',
          'midiProfile': 'nordStage3',
        },
      );
      final now = DateTime.now();
      await tester.runAsync(() async {
        final ids = [
          for (final title in ['Amazing Grace', 'Danny Boy', 'Swing Low'])
            await app.songs.createSong(source: '{title: $title}\n[G]La'),
        ];
        final id = await app.sets.createSet(
          name: 'Sommerfest',
          venue: 'Bern',
          gigDate: DateTime(now.year, now.month, now.day + 3),
        );
        await app.sets.addSongs(id, ids);
      });
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      final details = find.byKey(const Key('overview-readiness-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('overview-readiness-midi')),
      );
      expect(
        find.byKey(const Key('overview-readiness-offline')),
        findsOneWidget,
      );
      await shot(tester, '${lang}_44c_overview_readiness');
      await app.dispose(tester);
    });
  }

  // A page turner pressed on the overview, offered for pairing (#930).
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('overview page turner offer $lang', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await TestApp.create(
        prefs: {
          'language': lang,
          'themeMode': dark ? 'dark' : 'light',
          'userName': 'Ann',
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      app.inputDevices.press(
        const InputDeviceInfo(
          name: 'DUO500 v3.0.13 6887',
          vendorId: 0x0122,
          productId: 0x000d,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-turner-offer')), findsOneWidget);
      await shot(tester, '${lang}_44d_page_turner_offer');
      await app.dispose(tester);
    });
  }
}
