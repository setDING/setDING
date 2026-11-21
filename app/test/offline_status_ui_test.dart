import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// The offline status of sets (ADR-0001, #744): only sets with songs that
/// are not on the device are marked, and a warning above the sets says when
/// the data may not be up to date.
void main() {
  testWidgets('marks only sets with songs that are not offline', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = await tester.runAsync(() async {
      final a = await app.songs.createSong(title: 'Late Train Home');
      await app.songs.addAttachment(
        a,
        name: 'Lead sheet',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final b = await app.songs.createSong(title: 'Paper Moon');
      final complete = await app.sets.createSet(name: 'Complete');
      await app.sets.addSongs(complete, [b]);
      final missing = await app.sets.createSet(name: 'Missing');
      await app.sets.addSongs(missing, [a, b]);
      return (a, missing);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openTab(tester, HomeTab.sets);
    expect(find.byType(OfflineMissingBadge), findsNothing);

    // The PDF of a song is not on the device (e.g. not downloaded yet).
    await tester.runAsync(() async {
      final file = (await app.songs.getAttachments(ids!.$1)).single.fileName;
      await File('${app.dir.path}/$file').delete();
      // A file is not watched: a change to the set refreshes the status.
      await app.sets.addMarker(ids.$2, 'break', 'Break');
    });
    // The file check is real I/O: give it real time.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Missing').first,
      matching: find.byType(Card),
    );
    // A visible text, not only an icon with a tooltip.
    expect(
      find.descendant(of: card, matching: find.text('1 song not offline')),
      findsOneWidget,
    );
    expect(find.byType(OfflineMissingBadge), findsOneWidget);

    // Also in the set itself.
    await tester.tap(find.text('Missing').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SetScreen),
        matching: find.text('1 song not offline'),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  group('stale sync warning', () {
    Future<TestApp> start(WidgetTester tester, {DateTime? clock}) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _ann,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      await tester.pumpWidget(
        app.build(
          extra: [
            if (clock != null) syncClockProvider.overrideWithValue(() => clock),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => SetRepository(
          app.db,
          app.storage,
          bandId: 'b1',
        ).createSet(name: 'Gig'),
      );
      return app;
    }

    final banner = find.byKey(const Key('sync-stale-banner'));

    testWidgets('until the first sync, and not after it', (tester) async {
      final app = await start(tester);
      await openTab(tester, HomeTab.sets);
      expect(banner, findsOneWidget);
      expect(
        find.textContaining('has not synced with the server yet'),
        findsOneWidget,
      );

      await syncNow(tester);
      expect(banner, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('when the last sync is older than a day', (tester) async {
      final app = await start(
        tester,
        clock: DateTime.now().add(const Duration(hours: 25)),
      );
      await syncNow(tester);
      await openTab(tester, HomeTab.sets);
      expect(banner, findsOneWidget);
      expect(find.textContaining('Last sync with the server:'), findsOneWidget);
      expect(find.byKey(const Key('sync-stale-now')), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('when local changes did not reach the server', (tester) async {
      final app = await start(tester);
      await syncNow(tester);
      await openTab(tester, HomeTab.sets);
      expect(banner, findsNothing);

      await tester.runAsync(
        () => TestApp.songsIn(app, 'o1').createSong(source: '{title: New}'),
      );
      app.backend.failWith = BackendErrorKind.network;
      await syncNow(tester);
      expect(banner, findsOneWidget);
      expect(
        find.textContaining('1 change from this device has not reached'),
        findsOneWidget,
      );

      // "Sync now" in the warning, once the network is back.
      app.backend.failWith = null;
      await tester.tap(find.byKey(const Key('sync-stale-now')));
      for (var i = 0; i < 100 && banner.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(banner, findsNothing);
      await app.dispose(tester);
    });
  });
}
