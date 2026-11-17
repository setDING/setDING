import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Pulls the list down and releases it, then lets the sync run to the end
/// (database work needs real time, the widgets fake time).
Future<void> pullToSync(WidgetTester tester, bool Function() done) async {
  await tester.fling(
    find
        .descendant(
          of: find.byKey(const Key('sync-refresh')),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, 400),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  for (var i = 0; i < 500 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  Future<TestApp> setup(WidgetTester tester, {AuthUser? user = _ann}) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: user,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    return app;
  }

  testWidgets('pulling the song list down syncs', (tester) async {
    final app = await setup(tester);
    final id = await TestApp.songsIn(
      app,
      'o1',
    ).createSong(source: '{title: Pulled}');
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    expect(app.backend.songs, isEmpty);

    await pullToSync(tester, () => app.backend.songs.containsKey(id));
    expect(app.backend.songs.containsKey(id), isTrue);
    await app.dispose(tester);
  });

  testWidgets('pulling the empty list of sets down syncs', (tester) async {
    final app = await setup(tester);
    final id = await TestApp.songsIn(
      app,
      'o1',
    ).createSong(source: '{title: Pulled}');
    await tester.pumpWidget(app.build(home: const SetsScreen()));
    await tester.pumpAndSettle();

    await pullToSync(tester, () => app.backend.songs.containsKey(id));
    expect(app.backend.songs.containsKey(id), isTrue);
    await app.dispose(tester);
  });

  testWidgets('a failed pull reports being offline', (tester) async {
    final app = await setup(tester);
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    app.backend.failWith = BackendErrorKind.network;

    await pullToSync(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);
    expect(find.textContaining('No connection'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('signed out the lists cannot be pulled to sync', (tester) async {
    final app = await setup(tester, user: null);
    await tester.pumpWidget(app.build(home: const SongsScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-refresh')), findsNothing);
    await tester.pumpWidget(app.build(home: const SetsScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-refresh')), findsNothing);
    await app.dispose(tester);
  });
}
