// Screenshots of the song review and mistake reports (ADR-0060, #992).
// See screenshot_support.dart.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/song_review.dart';

import '../test/test_app.dart';

import 'screenshot_support.dart';

void main() {
  setUpScreenshots();

  const morning =
      '{title: Morning Light}\n{artist: Ann Trainor}\n{key: D}\n'
      '{start_of_verse}\n[D]Morning light on the [G]hill\n'
      '[A]Shining on the [D]road\n{end_of_verse}\n';
  const train =
      '{title: Train to Nowhere}\n{artist: House Band}\n{key: E}\n'
      '{start_of_verse}\n[E]Waiting at the [A]station\n{end_of_verse}\n';
  const river =
      '{title: River Song}\n{artist: The Locals}\n{key: G}\n'
      '{start_of_verse}\n[G]Down by the [C]river\n{end_of_verse}\n';

  /// Songs to review and reported, as after an import.
  Future<TestApp> setup(WidgetTester tester, String lang, bool dark) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': lang, 'themeMode': dark ? 'dark' : 'light'},
    );
    await tester.runAsync(() async {
      final review = SongReviewRepository(app.db, app.storage);
      final reason = lang == 'de' ? 'Nach Import' : 'After import';
      final a = await app.songs.createSong(source: morning);
      final b = await app.songs.createSong(source: train);
      final c = await app.songs.createSong(source: river);
      await review.setToReview(a, reason: reason);
      await review.setToReview(b, reason: reason);
      await review.report(
        a,
        category: SongReportCategory.chords,
        comment: lang == 'de'
            ? 'Im 2. Takt ist es ein Em, nicht G.'
            : 'Bar 2 is an Em, not a G.',
        location: SongReportLocation(
          section: lang == 'de' ? 'Strophe 1' : 'Verse 1',
          page: 1,
        ),
      );
      final resolved = await review.report(
        c,
        category: SongReportCategory.key,
        comment: lang == 'de' ? 'Wir spielen es in A.' : 'We play it in A.',
      );
      await review.resolve(
        resolved,
        resolution: lang == 'de'
            ? 'Tonart auf A geändert, danke!'
            : 'Changed the key to A, thanks!',
      );
    });
    return app;
  }

  // The song list filtered to the songs to review, with Approve all.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song review list $lang', (tester) async {
      final app = await setup(tester, lang, dark);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('songs-approve-all')), findsOneWidget);
      await shot(tester, '${lang}_53_songs_review');
      await app.dispose(tester);
    });
  }

  // The banner of a song to review with an open report.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song review banner $lang', (tester) async {
      final app = await setup(tester, lang, dark);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning Light'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-banner')), findsOneWidget);
      await shot(tester, '${lang}_53b_song_review_banner');
      await app.dispose(tester);
    });
  }

  // The sheet to report a mistake.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song report sheet $lang', (tester) async {
      final app = await setup(tester, lang, dark);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Train to Nowhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('song-report')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-category-lyrics')));
      await tester.enterText(
        find.byKey(const Key('report-comment')),
        lang == 'de'
            ? 'In der Strophe fehlt eine Zeile.'
            : 'A line is missing in the verse.',
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_53c_song_report_sheet');
      await app.dispose(tester);
    });
  }

  // Marking the place on a screenshot.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song report marking $lang', (tester) async {
      final app = await setup(tester, lang, dark);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Train to Nowhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('song-report')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-screenshot-add')));
      await tester.pumpAndSettle();
      final canvas = tester.getRect(find.byKey(const Key('screenshot-canvas')));
      // A circle around the chord A.
      final centre =
          canvas.topLeft + Offset(canvas.width * 0.21, canvas.height * 0.32);
      final gesture = await tester.startGesture(centre + const Offset(40, 0));
      for (var i = 1; i <= 24; i++) {
        final a = i / 24 * 2 * math.pi;
        await gesture.moveTo(
          centre + Offset(40 * math.cos(a), 26 * math.sin(a)),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await shot(tester, '${lang}_53d_song_report_marking');
      await app.dispose(tester);
    });
  }

  // The reports of a song, one resolved with an answer.
  for (final (lang, dark) in [('de', false), ('en', true)]) {
    screenshotTest('song reports panel $lang', (tester) async {
      final app = await setup(tester, lang, dark);
      await tester.pumpWidget(
        RepaintBoundary(key: UniqueKey(), child: app.build()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-todo-toReview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-song-reports')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-reports')), findsOneWidget);
      await shot(tester, '${lang}_53e_song_reports');
      await app.dispose(tester);
    });
  }
}
