import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart' show AuthUser, ServerConfig;
import 'package:setding/ui/deep_links.dart';
import 'package:setding/ui/routes.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Links to sets and songs (ADR-0065 §5, #1115): shared from the set and
/// song screens, opened from App Links and setding:// links.
void main() {
  group('the screen a link opens', () {
    test('App Links and Universal Links', () {
      expect(
        appLocationOf(Uri.parse('https://app.setding.app/sets/abc-123')),
        AppPaths.set('abc-123'),
      );
      expect(
        appLocationOf(Uri.parse('https://app.setding.app/songs/abc-123/')),
        AppPaths.song('abc-123'),
      );
      expect(
        appLocationOf(
          Uri.parse('https://api.setding.app/invite/AbCdEfGhIjKlMnOp1234'),
        ),
        AppPaths.invite('AbCdEfGhIjKlMnOp1234'),
      );
    });

    test('setding:// links of the desktops', () {
      expect(
        appLocationOf(Uri.parse('setding://sets/abc-123')),
        AppPaths.set('abc-123'),
      );
      expect(
        appLocationOf(Uri.parse('setding://songs/abc-123')),
        AppPaths.song('abc-123'),
      );
      expect(
        appLocationOf(Uri.parse('setding://invite/AbCdEfGhIjKlMnOp1234')),
        AppPaths.invite('AbCdEfGhIjKlMnOp1234'),
      );
    });

    test('nothing else', () {
      for (final link in [
        'https://app.setding.app/',
        'https://app.setding.app/sets',
        'https://app.setding.app/sets/abc/edit',
        'https://app.setding.app/songs/new',
        'https://app.setding.app/settings/live',
        'https://app.setding.app/sets/a%2Fb',
        'setding://other/abc',
        'mailto:ann@example.test',
        'https://app.setding.app/invite/short',
      ]) {
        expect(appLocationOf(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  testWidgets('an incoming link opens the song', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await app.songs.createSong(source: '{title: Ending}');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.links.add(Uri.parse('https://app.setding.app/songs/$id'));
    await tester.pumpAndSettle();
    expect(find.byType(SongScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set opened from a link is not opened twice', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await app.sets.createSet(name: 'Gig');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.links.add(Uri.parse('setding://sets/$id'));
    await tester.pumpAndSettle();
    app.links.add(Uri.parse('setding://sets/$id'));
    await tester.pumpAndSettle();
    expect(find.byType(SetScreen), findsOneWidget);
    await app.dispose(tester);
  });

  group('sharing', () {
    // Desktops copy the link; phones and tablets open the share sheet.
    final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

    Future<(TestApp, List<String>)> openSet(
      WidgetTester tester, {
      required bool local,
    }) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', if (!local) 'currentBandId': 'b1'},
        user: local ? null : _ann,
      );
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      app.backend.config = const ServerConfig(
        linkBase: 'https://app.setding.app',
      );
      String id;
      if (local) {
        id = await app.sets.createSet(name: 'Gig');
        await tester.pumpWidget(app.build(home: SetScreen(setId: id)));
      } else {
        app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
        await tester.pumpWidget(app.build(home: const Scaffold()));
        await syncNow(tester);
        id = await SetRepository(
          app.db,
          app.storage,
          bandId: 'b1',
          userId: 'ann',
        ).createSet(name: 'Gig');
        await tester.pumpWidget(app.build(home: SetScreen(setId: id)));
      }
      await tester.pumpAndSettle();
      return (app, copied);
    }

    testWidgets('a set of a band is shared as a link to the web client', (
      tester,
    ) async {
      final (app, copied) = await openSet(tester, local: false);
      final id = (await app.db.select(app.db.setlists).getSingle()).id;
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set-share-link')));
      await tester.pumpAndSettle();
      expect(copied, ['https://app.setding.app/sets/$id']);
      expect(find.text('Link copied'), findsOneWidget);
      // The link opens the same set again.
      expect(appLocationOf(Uri.parse(copied.single)), AppPaths.set(id));
      await app.dispose(tester);
    }, variant: desktop);

    testWidgets('a set of the local band has no link', (tester) async {
      final (app, _) = await openSet(tester, local: true);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-share-link')), findsNothing);
      await app.dispose(tester);
    }, variant: desktop);
  });
}
