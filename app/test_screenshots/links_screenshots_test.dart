// Screenshots of links to sets and songs (ADR-0065): sharing a set's link
// and a link the device cannot open (yet).
// See screenshot_support.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/routes.dart';
import 'package:setding/ui/sets/set_screen.dart';

import '../test/sync_ui_test.dart' show syncNow;
import '../test/test_app.dart';

import 'screenshot_support.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

void main() {
  setUpScreenshots();

  Future<TestApp> bandApp(WidgetTester tester, String lang) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(
      prefs: {
        'language': lang,
        'themeMode': lang == 'de' ? 'light' : 'dark',
        'currentBandId': 'b1',
      },
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    RemoteSong song(String id, String title, String key) => RemoteSong(
      id: id,
      organizationId: 'o1',
      title: title,
      chordpro: '{title: $title}\n{key: $key}',
    );
    RemoteSetItem item(String id, String songId) =>
        RemoteSetItem(id: id, type: SetItemType.song, songId: songId);
    app.backend
      ..putSong(song('s1', 'Morning Light', 'D'))
      ..putSong(song('s2', 'Late Train Home', 'E'))
      ..putSet(
        RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Sommerfest',
          venue: 'Bern',
          items: [item('i1', 's1'), item('i2', 's2')],
        ),
      );
    return app;
  }

  for (final lang in ['de', 'en']) {
    // The ⋮ menu of a band's set with "Share link" (#1115).
    screenshotTest('set share link $lang', (tester) async {
      final app = await bandApp(tester, lang);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await syncNow(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: UniqueKey(),
          child: app.build(home: const SetScreen(setId: 'set1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-share-link')), findsOneWidget);
      await shot(tester, '${lang}_61_set_share_link');
      await app.dispose(tester);
    });

    // A link to a set that is not on this device (#1114).
    screenshotTest('link not available $lang', (tester) async {
      final app = await bandApp(tester, lang);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await syncNow(tester);
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .go(AppPaths.set('elsewhere'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('link-not-available')), findsOneWidget);
      await shot(tester, '${lang}_61b_link_not_available');
      await app.dispose(tester);
    });
  }
}
