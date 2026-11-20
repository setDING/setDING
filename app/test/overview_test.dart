import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/overview/overview_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// The overview as the start screen (ADR-0045).
void main() {
  const broken = '{title: Washed}\n{c: Chorus} (first time a cappella)\n[G]la';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final nextSet = find.byKey(const Key('overview-next-set'));
  final todo = find.byKey(const Key('overview-todo'));

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('opens on the overview, the first of four tabs', (tester) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(
      [for (final d in bar.destinations.cast<NavigationDestination>()) d.label],
      ['Overview', 'Sets', 'Songs', 'Settings'],
    );
    expect(find.byType(OverviewScreen), findsOneWidget);
    // Nothing to show but the footer: no sets, no songs to fix.
    expect(nextSet, findsNothing);
    expect(todo, findsNothing);
    expect(find.byKey(const Key('overview-footer')), findsOneWidget);

    await openTab(tester, HomeTab.sets);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('New set'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the next set starts live on its first song', (tester) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: '{title: Opener}\n[C]One');
      final b = await app.songs.createSong(source: '{title: Closer}\n[G]Two');
      final past = await app.sets.createSet(
        name: 'Last night',
        gigDate: today.subtract(const Duration(days: 1)),
      );
      await app.sets.addSongs(past, [a]);
      await app.sets.createSet(name: 'Rehearsal');
      final later = await app.sets.createSet(
        name: 'Later gig',
        gigDate: today.add(const Duration(days: 10)),
      );
      await app.sets.addSongs(later, [b]);
      final next = await app.sets.createSet(
        name: 'Tomorrow gig',
        gigDate: today.add(const Duration(days: 1)),
        venue: 'Club',
      );
      await app.sets.addMarker(next, SetItemType.text, 'Welcome');
      await app.sets.addSongs(next, [a, b]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: nextSet, matching: find.text('Next set')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nextSet, matching: find.text('Tomorrow gig')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: nextSet,
        matching: find.textContaining('Tomorrow · Club · 2 songs'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('overview-start-live')));
    await tester.pumpAndSettle();
    final live = tester.widget<LiveScreen>(find.byType(LiveScreen));
    // The text item before it is skipped.
    expect(live.items.length, 3);
    expect(live.initialIndex, 1);
    expect(live.items[1].song?.title, 'Opener');
    Navigator.of(tester.element(find.byType(LiveScreen))).pop();
    await tester.pumpAndSettle();
    // Leaving live mode returns to the overview.
    expect(find.byType(OverviewScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('overview-open-set')));
    await tester.pumpAndSettle();
    expect(tester.widget<SetScreen>(find.byType(SetScreen)).setId, isNotEmpty);
    expect(find.text('Tomorrow gig'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('without a next gig, the most recently edited set', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final old = await app.sets.createSet(name: 'Old');
      final recent = await app.sets.createSet(
        name: 'Recent',
        gigDate: today.subtract(const Duration(days: 30)),
      );
      final song = await app.songs.createSong(source: '{title: A}\n[C]x');
      await app.sets.addSongs(recent, [song]);
      for (final (id, days) in [(old, 5), (recent, 1)]) {
        await (app.db.update(
          app.db.setlists,
        )..where((s) => s.id.equals(id))).write(
          SetlistsCompanion(
            updatedAt: Value(now.subtract(Duration(days: days))),
          ),
        );
      }
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: nextSet, matching: find.text('Last edited set')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nextSet, matching: find.text('Recent')),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  test('overviewSet: next gig first, then the last edited set', () {
    SetSummary summary(String id, {DateTime? gig, required int edited}) =>
        SetSummary(
          SetlistEntry(
            id: id,
            bandId: 'local',
            name: id,
            gigDate: gig,
            revision: 0,
            updatedAt: DateTime(2026, 1, edited),
            deleted: false,
            purged: false,
          ),
          0,
        );
    final day = DateTime(2026, 6, 10);
    expect(overviewSet(const [], day), isNull);
    final past = summary('past', gig: DateTime(2026, 6, 9), edited: 9);
    final undated = summary('undated', edited: 3);
    expect(overviewSet([past, undated], day)!.summary.set.id, 'past');
    expect(overviewSet([past, undated], day)!.upcoming, isFalse);
    final todayGig = summary('today', gig: day, edited: 1);
    final later = summary('later', gig: DateTime(2026, 7, 1), edited: 1);
    final shown = overviewSet([later, past, todayGig, undated], day)!;
    expect(shown.summary.set.id, 'today');
    expect(shown.upcoming, isTrue);
  });

  testWidgets('to do: each line opens the song list filtered', (tester) async {
    usePhoneSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: broken);
      await app.songs.createSong(source: '{title: Fine}\n[C]x');
      await app.songs.createSong(title: 'Sheet');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    expect(todo, findsOneWidget);
    expect(find.text('1 song with ChordPro problems'), findsOneWidget);
    expect(find.text('1 song with sheet music (PDF) only'), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-todo-conflicts')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('overview-todo-problems')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    final chip = find.byKey(const Key('songs-attention-filter'));
    expect(chip, findsOneWidget);
    expect(find.text('Washed'), findsOneWidget);
    expect(find.text('Fine'), findsNothing);
    expect(find.text('Sheet'), findsNothing);

    // Removing the filter shows all songs again.
    await tester.tap(find.byTooltip('Remove filter'));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(find.text('Fine'), findsOneWidget);
    expect(find.text('Sheet'), findsOneWidget);

    // The other line, from the overview again.
    await openTab(tester, HomeTab.overview);
    await tester.tap(
      find.byKey(const ValueKey('overview-todo-sheetMusicOnly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Washed'), findsNothing);
    await app.dispose(tester);
  });

  for (final (user, role, shown) in [
    (_ann, 'an organization admin', true),
    (_bob, 'a member', false),
  ]) {
    testWidgets('to do for $role: ${shown ? 'shown' : 'hidden'}', (
      tester,
    ) async {
      usePhoneSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: user,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      app.backend.addMember('b1', _bob, BandRole.member);
      await tester.runAsync(
        () => TestApp.songsIn(
          app,
          'o1',
          userId: 'ann',
        ).createSong(source: broken),
      );
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.byType(OverviewScreen), findsOneWidget);
      expect(todo, shown ? findsOneWidget : findsNothing);
      await app.dispose(tester);
    });
  }

  testWidgets('one column on phones, two from 720 px', (tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final song = await app.songs.createSong(source: broken);
      final set = await app.sets.createSet(
        name: 'Gig',
        gigDate: today.add(const Duration(days: 3)),
      );
      await app.sets.addSongs(set, [song]);
    });
    final columns = find.byKey(const Key('overview-two-columns'));

    usePhoneSize(tester);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(nextSet, findsOneWidget);
    expect(todo, findsOneWidget);
    expect(columns, findsNothing);
    expect(
      tester.getTopLeft(todo).dy,
      greaterThan(tester.getBottomLeft(nextSet).dy - 1),
    );

    useTabletSize(tester);
    await tester.pumpAndSettle();
    expect(columns, findsOneWidget);
    expect(tester.getTopLeft(todo).dy, tester.getTopLeft(nextSet).dy);
    expect(
      tester.getTopLeft(todo).dx,
      greaterThan(tester.getTopRight(nextSet).dx),
    );
    await app.dispose(tester);
  });

  testWidgets('the footer shows the version', (tester) async {
    usePhoneSize(tester);
    PackageInfo.setMockInitialValues(
      appName: 'setDING',
      packageName: 'app.setding',
      version: '0.1.1',
      buildNumber: '3',
      buildSignature: '',
    );
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(find.text('Version 0.1.1 (3)'), findsOneWidget);
    // No newer release known.
    expect(find.byKey(const Key('overview-update-install')), findsNothing);
    await app.dispose(tester);
  });
}
