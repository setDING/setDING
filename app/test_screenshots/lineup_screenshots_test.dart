// Screenshots of the lineup per set and substitutes (ADR-0061, #1012).
// See screenshot_support.dart.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:setding/ui/sets/set_screen.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

const _anna = AuthUser(id: 'anna', email: 'anna@example.test', name: 'Anna');
const _beat = AuthUser(id: 'beat', email: 'beat@example.test', name: 'Beat');
const _dario = AuthUser(
  id: 'dario',
  email: 'dario@example.test',
  name: 'Dario',
);
const _carla = AuthUser(
  id: 'carla',
  email: 'carla@example.test',
  name: 'Carla',
);

void main() {
  setUpScreenshots();

  const songs = [
    ('morning', 'Morning Light', 'D'),
    ('train', 'Train to Nowhere', 'E'),
    ('river', 'River Song', 'G'),
  ];

  /// The band "Abendrot" (Anna leads, Beat and Dario play) and Carla, who
  /// plays in "Jazz-Trio" and helps out at the summer party in five days
  /// instead of Dario. Signed in as [user], synced.
  Future<TestApp> setup(
    WidgetTester tester,
    String lang,
    bool dark, {
    required AuthUser user,
    String band = 'abendrot',
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': lang,
        'themeMode': dark ? 'dark' : 'light',
        'currentBandId': band,
        // Synced just now: no hint about data that may be out of date.
        'lastSync.${user.id}': DateTime.now().toIso8601String(),
      },
      user: user,
    );
    final server = app.backend;
    server.addBand('abendrot', 'Abendrot', admin: _anna, organizationId: 'o1');
    server.addMember('abendrot', _beat, BandRole.member);
    server.addMember('abendrot', _dario, BandRole.member);
    server.addBand('jazz', 'Jazz-Trio', admin: _carla, organizationId: 'o1');
    for (final (id, title, key) in songs) {
      server.putSong(
        RemoteSong(
          id: id,
          organizationId: 'o1',
          title: title,
          chordpro: '{title: $title}\n{key: $key}\n[$key]La la',
        ),
      );
    }
    final now = DateTime.now();
    server.putSet(
      RemoteSet(
        id: 'summer',
        bandId: 'abendrot',
        name: lang == 'de' ? 'Sommerfest' : 'Summer party',
        gigDate: DateTime(now.year, now.month, now.day + 5),
        venue: 'Bern',
        items: [
          for (final (id, _, _) in songs)
            RemoteSetItem(id: 'i-$id', type: SetItemType.song, songId: id),
        ],
        lineup: const ['anna', 'beat', 'carla'],
        lineupCustom: true,
      ),
      by: 'anna',
    );
    await tester.runAsync(
      () => SyncEngine(
        app.db,
        app.backend,
        BandService(app.db, app.backend),
      ).sync(),
    );
    return app;
  }

  Future<TestApp> openSet(WidgetTester tester, String lang, bool dark) async {
    final app = await setup(tester, lang, dark, user: _anna);
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: app.build(home: const SetScreen(setId: 'summer')),
      ),
    );
    await tester.pumpAndSettle();
    return app;
  }

  // The set with its lineup under the details.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('set lineup $lang', (tester) async {
      final app = await openSet(tester, lang, dark);
      expect(find.byKey(const Key('set-lineup')), findsOneWidget);
      await shot(tester, '${lang}_54_set_lineup');
      await app.dispose(tester);
    });
  }

  // Choosing the lineup: band members and a substitute.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('lineup dialog $lang', (tester) async {
      final app = await openSet(tester, lang, dark);
      await tester.tap(find.byKey(const Key('set-lineup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lineup-carla')), findsOneWidget);
      await shot(tester, '${lang}_54b_lineup_dialog');
      await app.dispose(tester);
    });
  }

  // The message to the lineup.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('lineup notify $lang', (tester) async {
      final app = await openSet(tester, lang, dark);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set-notify-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lineup-message')), findsOneWidget);
      await shot(tester, '${lang}_54c_lineup_notify');
      await app.dispose(tester);
    });
  }

  // Carla's overview in her own band: planned, and the gig as a substitute.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('overview substitute $lang', (tester) async {
      final app = await setup(tester, lang, dark, user: _carla, band: 'jazz');
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overview-planned')), findsOneWidget);
      expect(find.byKey(const Key('overview-substitute-gigs')), findsOneWidget);
      await shot(tester, '${lang}_54d_overview_substitute');
      await app.dispose(tester);
    });
  }
}
