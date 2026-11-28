import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_review.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Reporting mistakes in songs and resolving the reports (ADR-0060, #990).
void main() {
  Future<List<SongReportRow>> reports(WidgetTester tester, TestApp app) async =>
      (await tester.runAsync(() => app.db.select(app.db.songReports).get()))!;

  Future<void> openSong(WidgetTester tester, String title) async {
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  /// A report starts a sync when signed in: lets it finish.
  Future<void> settleSync(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSend(WidgetTester tester, String comment) async {
    await tester.tap(find.byKey(const ValueKey('report-category-chords')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('report-comment')), comment);
    await tester.tap(find.byKey(const Key('report-send')));
    await settleSync(tester);
  }

  testWidgets('a member reports a mistake from the song menu, sees it and '
      'withdraws it', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.runAsync(
      () => TestApp.songsIn(app, 'o1').createSong(source: '{title: Song}'),
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'Song');

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsOneWidget);
    // Nothing to send without a category.
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('report-send'))).enabled,
      isFalse,
    );
    await fillAndSend(tester, 'Bar 3 is Em');
    expect(find.text('Mistake reported. Thank you!'), findsOneWidget);
    final stored = (await reports(tester, app)).single;
    expect(stored.authorId, 'bob');
    expect(stored.categoryValue, SongReportCategory.chords);
    expect(stored.comment, 'Bar 3 is Em');

    // The hint and the reports of the song.
    expect(find.text('A mistake was reported in this song.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-song-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-reports')), findsOneWidget);
    expect(find.text('Bar 3 is Em'), findsOneWidget);
    expect(find.byKey(const Key('report-resolve')), findsNothing);
    await tester.tap(find.byKey(const Key('report-withdraw')));
    await settleSync(tester);
    expect(
      (await reports(tester, app)).single.statusValue,
      SongReportStatus.withdrawn,
    );
    await app.dispose(tester);
  });

  // A new report the server refused stays on this device, marked, and is
  // sent again only on request (#1269).
  testWidgets('a refused report is marked as only on this device and sent '
      'again on request', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.runAsync(
      () => TestApp.songsIn(app, 'o1').createSong(source: '{title: Song}'),
    );
    await syncNow(tester);
    await tester.pumpAndSettle();
    await openSong(tester, 'Song');
    app.backend.reportPushError = const BackendException(
      BackendErrorKind.notAllowed,
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-report')));
    await tester.pumpAndSettle();
    await fillAndSend(tester, 'Bar 3 is Em');
    expect(
      (await reports(tester, app)).single.uploadRefused,
      UploadRefusal.notAllowed,
    );

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-song-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-only-here')), findsOneWidget);
    expect(
      find.textContaining(
        'Only on this device: no permission to report mistakes',
        findRichText: true,
      ),
      findsOneWidget,
    );

    app.backend.reportPushError = null;
    await tester.tap(find.byKey(const Key('report-send-again')));
    await settleSync(tester);
    expect(app.backend.reports.values.single.comment, 'Bar 3 is Em');
    expect(find.byKey(const Key('report-only-here')), findsNothing);
    expect(find.byKey(const Key('report-send-again')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('whoever may edit the song resolves a report with an answer '
      'and opens it again', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Song}');
      await SongReviewRepository(app.db, app.storage).report(
        id,
        category: SongReportCategory.lyrics,
        comment: 'Typo in verse 2',
        location: const SongReportLocation(section: 'Verse 2'),
      );
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openSong(tester, 'Song');
    await tester.tap(find.byKey(const Key('review-show-reports')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verse 2'), findsWidgets);

    await tester.tap(find.byKey(const Key('report-resolve')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Fixed, thanks');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final row = (await reports(tester, app)).single;
    expect(row.statusValue, SongReportStatus.resolved);
    expect(row.resolution, 'Fixed, thanks');

    // Resolved reports are history, folded away.
    await tester.tap(find.byKey(const Key('reports-closed')));
    await tester.pumpAndSettle();
    expect(find.text('Resolved: Fixed, thanks'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('report-reopen')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(
      (await reports(tester, app)).single.statusValue,
      SongReportStatus.open,
    );
    await app.dispose(tester);
  });

  testWidgets('live mode reports a mistake with the page', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Live}\n[G]La');
      return app.songs.getSong(id);
    }))!;
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song)])),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(find.byType(PageView)).center);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live-report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-location')), findsOneWidget);
    expect(find.text('Where: Page 1'), findsOneWidget);
    await fillAndSend(tester, 'Wrong chord');
    final row = (await reports(tester, app)).single;
    expect(row.locationValue?.page, 1);
    expect(row.comment, 'Wrong chord');
    await app.dispose(tester);
  });

  testWidgets('a page turner sends the report, or cancels without a '
      'category', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Live}\n[G]La');
      return app.songs.getSong(id);
    }))!;
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song)])),
    );
    await tester.pumpAndSettle();
    Future<void> openSheet() async {
      // A tap in the middle shows the controls, unless they are shown.
      if (find.byKey(const Key('live-report')).evaluate().isEmpty) {
        await tester.tapAt(tester.getRect(find.byType(PageView)).center);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('live-report')));
      await tester.pumpAndSettle();
    }

    await openSheet();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(await reports(tester, app), isEmpty);

    await openSheet();
    await tester.tap(find.byKey(const ValueKey('report-category-tempo')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settleSync(tester);
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(
      (await reports(tester, app)).single.categoryValue,
      SongReportCategory.tempo,
    );
    await app.dispose(tester);
  });

  testWidgets('the reporter is told once when someone resolved their report', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {
        'language': 'en',
        'currentBandId': 'b1',
        // Answers seen before on this device.
        'seenReportAnswers': <String>[],
      },
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    app.backend.putSong(
      const RemoteSong(
        id: 's1',
        organizationId: 'o1',
        title: 'Song',
        chordpro: '{title: Song}',
      ),
      by: 'ann',
    );
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    final id = (await tester.runAsync(
      () => SongReviewRepository(
        app.db,
        app.storage,
        userId: 'bob',
      ).report('s1', category: SongReportCategory.key),
    ))!;
    await syncNow(tester);
    final pushed = app.backend.reports[id]!;
    app.backend.putReport(
      RemoteSongReport(
        id: id,
        songId: 's1',
        organizationId: 'o1',
        category: pushed.category,
        status: 'resolved',
        resolution: 'It is in G now',
        resolvedBy: 'ann',
      ),
    );
    await syncNow(tester);
    expect(
      find.text('Your report on “Song” was resolved: It is in G now'),
      findsOneWidget,
    );
    // Not again at the next sync.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await syncNow(tester);
    expect(find.byKey(const Key('report-answered')), findsNothing);
    await app.dispose(tester);
  });
}
