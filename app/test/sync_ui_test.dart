import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:realchord/data/database.dart';
import 'package:realchord/sync/sync_backend.dart';
import 'package:realchord/sync/sync_controller.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/settings_screen.dart';
import 'package:realchord/ui/songs/song_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Runs a sync to the end. The database work needs real time, while the
/// widgets' stream queries run in the test's fake time, so both are
/// advanced alternately.
Future<void> syncNow(WidgetTester tester, {Finder? within}) async {
  final container = ProviderScope.containerOf(
    tester.element(within ?? find.byType(Scaffold).first),
  );
  var done = false;
  unawaited(
    container
        .read(syncControllerProvider.notifier)
        .syncNow()
        .whenComplete(() => done = true),
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done, isTrue, reason: 'sync did not finish');
  await tester.pumpAndSettle();
}

void main() {
  Future<TestApp> setup(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    return app;
  }

  testWidgets('shows pending changes and syncs on request', (tester) async {
    final app = await setup(tester);
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    final id = await TestApp.songsIn(
      app,
      'o1',
    ).createSong(source: '{title: New}');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1 change is not on the server yet.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sync-now')), findsOneWidget);

    await syncNow(tester);
    expect(app.backend.songs.containsKey(id), isTrue);
    expect(
      find.textContaining('All changes are on the server.'),
      findsOneWidget,
    );
    expect(find.textContaining('Last synced'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('reports being offline', (tester) async {
    final app = await setup(tester);
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    app.backend.failWith = BackendErrorKind.network;
    await syncNow(tester);
    expect(find.textContaining('No connection'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a conflict is resolved on the song screen', (tester) async {
    final app = await setup(tester);
    final songs = TestApp.songsIn(app, 'o1');
    final id = await songs.createSong(source: '{title: Song}\n[C]mine');
    await app.db
        .into(app.db.songConflicts)
        .insert(
          SongConflictsCompanion.insert(
            songId: id,
            title: 'Song',
            chordproSource: '{title: Song}\n[C]theirs',
            revision: 5,
            detectedAt: DateTime(2026),
          ),
        );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conflict-banner')), findsOneWidget);
    await tester.tap(find.text('Show server version'));
    await tester.pumpAndSettle();
    expect(find.textContaining('theirs'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('conflict-take-server')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conflict-banner')), findsNothing);
    expect((await songs.getSong(id))!.chordproSource, contains('theirs'));
    await app.dispose(tester);
  });

  testWidgets('no sync runs while live mode is open', (tester) async {
    final app = await setup(tester);
    await tester.pumpWidget(app.build(home: const SizedBox()));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    final controller = container.read(syncControllerProvider.notifier);
    await TestApp.songsIn(app, 'o1').createSong(source: '{title: Stage}');

    controller.pause();
    expect(await controller.syncNow(), isNull);
    expect(app.backend.songs, isEmpty);

    // Resuming catches up on the requested sync shortly afterwards.
    await tester.runAsync(() async {
      controller.resume();
      await Future<void>.delayed(
        SyncController.remoteDelay + const Duration(milliseconds: 500),
      );
    });
    expect(app.backend.songs, hasLength(1));
    await app.dispose(tester);
  });

  testWidgets('live mode explains a PDF that is not downloaded yet', (
    tester,
  ) async {
    final app = await setup(tester);
    final songs = TestApp.songsIn(app, 'o1');
    final id = await songs.createSong(title: 'Only PDF');
    await app.db
        .into(app.db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'a1',
            songId: id,
            name: 'Score',
            fileName: 'a1.pdf',
            remoteFile: const Value('a1_x.pdf'),
            sizeBytes: 10,
            updatedAt: DateTime(2026),
          ),
        );
    final song = await tester.runAsync(() => songs.getSong(id));
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdf-missing')), findsOneWidget);
    // The apps are offline-safe: no notice.
    expect(find.byKey(const Key('live-web-notice')), findsNothing);
    await app.dispose(tester);
  });
}
