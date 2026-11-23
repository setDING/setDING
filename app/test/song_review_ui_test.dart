import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/song_review.dart';
import 'package:setding/sync/sync_backend.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// The review status of songs in the app (ADR-0060, #989): set by the file
/// import, shown in the song list, on the overview and in sets, and
/// approved in the song view.
void main() {
  final toReviewIcon = find.byKey(const ValueKey('song-status-to-review'));
  final reportedIcon = find.byKey(const ValueKey('song-status-reported'));

  SongReviewRepository reviewOf(TestApp app) =>
      SongReviewRepository(app.db, app.storage);

  test('a file import sets every imported song to review', () async {
    final app = await TestApp.create();
    final result = await ImportExportService(app.songs, app.sets).importFiles([
      ImportFile('a.cho', utf8.encode('{title: A}\n[G]La')),
      ImportFile('b.cho', utf8.encode('{title: B}\n[C]Lu')),
    ], reviewReason: 'After import');
    expect(result.imported, 2);
    final songs = await app.songs.watchSongList().first;
    expect(songs.every((s) => s.toReview), isTrue);
    final row = await app.songs.getSong(songs.first.id);
    expect(row!.reviewReason, 'After import');
    // Without a reason (e.g. tests, older callers) nothing is set.
    await ImportExportService(
      app.songs,
      app.sets,
    ).importFiles([ImportFile('c.cho', utf8.encode('{title: C}'))]);
    final c = (await app.songs.watchSongList().first).firstWhere(
      (s) => s.title == 'C',
    );
    expect(c.toReview, isFalse);
    await app.db.close();
    app.dir.deleteSync(recursive: true);
  });

  testWidgets('the overview line filters the songs to review, which are '
      'approved all at once, with undo', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: '{title: Imported}');
      await app.songs.createSong(source: '{title: Checked}');
      await reviewOf(app).setToReview(a, reason: 'After import');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(find.text('1 song to review'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
    await tester.pumpAndSettle();
    expect(find.text('Imported'), findsOneWidget);
    expect(find.text('Checked'), findsNothing);
    expect(toReviewIcon, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('songs-approve-all')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Approve all songs?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-action')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 song approved'), findsOneWidget);
    expect(find.text('Imported'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Imported'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members see the icons but no To do and no approving', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.runAsync(() async {
      final songs = TestApp.songsIn(app, 'o1');
      final review = SongReviewRepository(app.db, app.storage, userId: 'ann');
      final a = await songs.createSong(source: '{title: New}');
      final b = await songs.createSong(source: '{title: Wrong}');
      await review.setToReview(a, reason: 'After import');
      await review.report(b, category: SongReportCategory.chords);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-todo-toReview')), findsNothing);
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(toReviewIcon, findsOneWidget);
    expect(reportedIcon, findsOneWidget);
    expect(
      find.byKey(const ValueKey('songs-attention-toReview')),
      findsNothing,
    );

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-hint')), findsOneWidget);
    expect(find.text('This song has not been checked yet.'), findsOneWidget);
    expect(find.byKey(const Key('review-banner')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the song view approves a song and offers to resolve its '
      'open reports', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Imported}');
      await reviewOf(app).setToReview(id, reason: 'After import');
      await reviewOf(app).report(id, category: SongReportCategory.lyrics);
      return id;
    }))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imported'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-banner')), findsOneWidget);
    expect(find.text('To review: After import'), findsOneWidget);
    expect(find.text('1 open report'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('review-approve')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Resolve the reports?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-action')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Song approved'), findsOneWidget);
    expect(find.byKey(const Key('review-banner')), findsNothing);
    final song = (await tester.runAsync(() => app.songs.getSong(id)))!;
    expect(song.reviewState, isNull);
    final open = (await tester.runAsync(() => reviewOf(app).openReports(id)))!;
    expect(open, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('the song menu marks a song for review with a reason', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(
      () => app.songs.createSong(source: '{title: Song}'),
    ))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-set-to-review')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Bridge is wrong');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('To review: Bridge is wrong'), findsOneWidget);
    final song = (await tester.runAsync(() => app.songs.getSong(id)))!;
    expect(song.reviewReason, 'Bridge is wrong');
    await app.dispose(tester);
  });

  testWidgets('an upcoming set shows how many of its songs need a check', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: '{title: A}');
      final b = await app.songs.createSong(source: '{title: B}');
      await reviewOf(app).setToReview(a);
      await reviewOf(app).report(b, category: SongReportCategory.key);
      final now = DateTime.now();
      final set = await app.sets.createSet(
        name: 'Gig',
        gigDate: DateTime(now.year, now.month, now.day + 3),
      );
      await app.sets.addSongs(set, [a, b]);
      final old = await app.sets.createSet(
        name: 'Old gig',
        gigDate: DateTime(now.year - 1, 1, 1),
      );
      await app.sets.addSongs(old, [a, b]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sets').first);
    await tester.pumpAndSettle();
    // In the list: the upcoming set only.
    expect(find.byKey(const ValueKey('set-review')), findsOneWidget);
    await tester.tap(find.text('Gig').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('set-review-hint')), findsOneWidget);
    expect(
      find.text('2 songs are not checked yet or have reported mistakes'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });
}
