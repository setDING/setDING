import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/attachment_storage_memory.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/sync/browser_session_store.dart';
import 'package:realchord/sync/sync_backend.dart';

import 'test_app.dart';

// The fake backend gives a signed-in account the id `u-<email>`.
const _ann = AuthUser(
  id: 'u-ann@example.test',
  email: 'ann@example.test',
  name: 'Ann',
);

class _Storage implements KeyValueStorage {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

/// The web client (ADR-0018): sign-in required, no local library, no file
/// import/export, local data only while signed in.
void main() {
  Future<TestApp> start(
    WidgetTester tester, {
    AuthUser? user,
    bool withBand = true,
    Future<void> Function(TestApp app)? before,
    BrowserSessionStore? sessionStore,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en'},
      user: user,
      web: true,
      sessionStore: sessionStore,
    );
    if (withBand) app.backend.addBand('b1', 'The Band', admin: _ann);
    await before?.call(app);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  Future<int> songCount(TestApp app) async =>
      (await app.db.select(app.db.songs).get()).length;

  testWidgets('requires signing in, with "Stay signed in"', (tester) async {
    final store = BrowserSessionStore(tab: _Storage(), persistent: _Storage());
    final app = await start(tester, sessionStore: store);
    app.backend.accounts[_ann.email] = 'secret-pw';

    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('account-open-join')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('account-email')), _ann.email);
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'secret-pw',
    );
    await tester.tap(find.byKey(const Key('account-keep-signed-in')));
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();

    expect(store.keepSignedIn, isTrue);
    expect(find.byKey(const Key('web-sign-in')), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the native sign-in has no "Stay signed in"', (tester) async {
    final app = await start(tester);
    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    // A non-browser session store (tests, native apps) has no choice.
    expect(find.byKey(const Key('account-keep-signed-in')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('hides the local library and file import/export', (tester) async {
    final app = await start(tester, user: _ann);
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('songs-import')), findsNothing);

    await tester.tap(find.byKey(const Key('band-switcher')).last);
    await tester.pumpAndSettle();
    expect(find.text('The Band'), findsWidgets);
    expect(find.text('On this device'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('without a band it offers to create or join one', (tester) async {
    final app = await start(tester, user: _ann, withBand: false);
    expect(find.byKey(const Key('web-no-band')), findsOneWidget);
    expect(find.text('No band yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('web-no-band-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('signing out deletes the data in the browser', (tester) async {
    final app = await start(
      tester,
      user: _ann,
      before: (app) =>
          TestApp.songsIn(app, 'org-b1').createSong(source: '{title: A}'),
    );
    expect(await songCount(app), greaterThan(0));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The data in this browser is deleted. Songs and sets stay on the server.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    expect(await songCount(app), 0);
    expect(await app.db.select(app.db.organizations).get(), isEmpty);
    await app.dispose(tester);
  });

  testWidgets('starting signed out deletes data of an earlier session', (
    tester,
  ) async {
    final app = await start(
      tester,
      before: (app) => app.songs.createSong(source: '{title: Left over}'),
    );
    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    expect(await songCount(app), 0);
    await app.dispose(tester);
  });

  testWidgets('the native apps keep their data when signed out', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await app.songs.createSong(source: '{title: Mine}');
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(await songCount(app), 1);
    await app.dispose(tester);
  });

  test('clearAll deletes everything but keeps the local library', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final songs = SongRepository(db, MemoryAttachmentStorage());
    await songs.createSong(source: '{title: Hello}\n[C]World');
    expect(await songs.watchSongList(query: 'hello').first, isNotEmpty);

    await db.clearAll();
    for (final table in db.allTables) {
      if (table.actualTableName == 'songs_fts') continue;
      final rows = await db.select(table).get();
      if (table.actualTableName == 'bands') {
        expect(rows, hasLength(1), reason: 'the local library stays');
      } else {
        expect(rows, isEmpty, reason: table.actualTableName);
      }
    }
    expect(await songs.watchSongList(query: 'hello').first, isEmpty);
    // Foreign keys are on again.
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.single, 1);
  });
}
