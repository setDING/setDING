// Screenshot of the overview with its cards (ADR-0045, #868).
// See screenshot_support.dart.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  // The next set, more sets, newest songs and songs not played for a while.
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
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overview-more-sets')), findsOneWidget);
      expect(find.byKey(const Key('overview-newest-songs')), findsOneWidget);
      expect(find.byKey(const Key('overview-not-played')), findsOneWidget);
      await shot(tester, '${lang}_44_overview');
      await app.dispose(tester);
    });
  }
}
