import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/band_providers.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/sync_backend.dart' show AuthUser;
import 'package:setding/ui/routes.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// A set or song opened by its path, e.g. from a link (ADR-0065 §3, #1114):
/// it switches to its band or library, or says it is not available.
void main() {
  /// Ann in two bands of two organizations, synced, on the band "Rock".
  Future<TestApp> twoBands(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _ann,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addBand('b2', 'Choir', admin: _ann, organizationId: 'o2');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    return app;
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  Future<void> go(WidgetTester tester, String location) async {
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }

  final notAvailable = find.byKey(const Key('link-not-available'));

  testWidgets('a set of another band switches to that band', (tester) async {
    final app = await twoBands(tester);
    expect(containerOf(tester).read(currentBandProvider).id, 'b1');
    final id = await SetRepository(
      app.db,
      app.storage,
      bandId: 'b2',
      userId: 'ann',
    ).createSet(name: 'Christmas');

    await go(tester, AppPaths.set(id));
    expect(containerOf(tester).read(currentBandProvider).id, 'b2');
    expect(find.byType(SetScreen), findsWidgets);
    expect(find.text('Christmas'), findsWidgets);
    expect(find.text('Switched to Choir'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set of the current band opens without a hint', (tester) async {
    final app = await twoBands(tester);
    final id = await SetRepository(
      app.db,
      app.storage,
      bandId: 'b1',
      userId: 'ann',
    ).createSet(name: 'Gig');
    await go(tester, AppPaths.set(id));
    expect(find.byType(SetScreen), findsWidgets);
    expect(find.textContaining('Switched to'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a song of another library switches to that library', (
    tester,
  ) async {
    final app = await twoBands(tester);
    final id = await TestApp.songsIn(
      app,
      'o2',
      userId: 'ann',
    ).createSong(source: '{title: Silent Night}');

    await go(tester, AppPaths.song(id));
    final container = containerOf(tester);
    expect(container.read(currentLibraryProvider).id, 'o2');
    expect(container.read(currentBandProvider).id, 'b2');
    expect(find.byType(SongScreen), findsOneWidget);
    expect(find.text('Switched to Choir'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set not on this device offers a sync, then says so', (
    tester,
  ) async {
    final app = await twoBands(tester);
    await go(tester, AppPaths.set('not-here'));
    expect(notAvailable, findsOneWidget);
    expect(find.text('Not available on this device'), findsOneWidget);
    expect(
      find.text(
        'It is not synced to this device yet, or you have no access to it.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('link-sync')));
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (find.byKey(const Key('link-sync')).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(
      find.text('Not available: it was deleted, or you have no access to it.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('link-sync')), findsNothing);
    // The back button leads to the sets.
    expect(find.byType(BackButton), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a set that arrives later opens by itself', (tester) async {
    final app = await twoBands(tester);
    const id = 'arrives-later';
    await go(tester, AppPaths.set(id));
    expect(notAvailable, findsOneWidget);
    await SetRepository(
      app.db,
      app.storage,
      bandId: 'b1',
      userId: 'ann',
    ).createSet(name: 'Late gig', id: id);
    await tester.pumpAndSettle();
    expect(notAvailable, findsNothing);
    expect(find.byType(SetScreen), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('a deleted set does not show its name', (tester) async {
    final app = await twoBands(tester);
    final sets = SetRepository(
      app.db,
      app.storage,
      bandId: 'b1',
      userId: 'ann',
    );
    final id = await sets.createSet(name: 'Secret gig');
    await sets.deleteSet(id);
    await go(tester, AppPaths.set(id));
    expect(notAvailable, findsOneWidget);
    expect(find.textContaining('Secret gig'), findsNothing);
    expect(find.byKey(const Key('link-sync')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('signed out, a missing song asks to sign in', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await go(tester, AppPaths.song('not-here'));
    expect(notAvailable, findsOneWidget);
    expect(find.text('Sign in to see it.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('link-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a song of the local library opens signed out', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await app.songs.createSong(source: '{title: Ending}');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await go(tester, AppPaths.song(id));
    expect(find.byType(SongScreen), findsOneWidget);
    expect(notAvailable, findsNothing);
    await app.dispose(tester);
  });
}
