import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/providers.dart';
import 'package:setding/sync/browser_session_store.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/live/pdf_spread_view.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/settings_screen.dart';

import 'package:setding/ui/home_tab.dart';

import 'test_app.dart';

// The fake backend gives a signed-in account the id `u-<email>`.
const _ann = AuthUser(
  id: 'u-ann@example.test',
  email: 'ann@example.test',
  name: 'Ann',
);

final _pdf = utf8.encode('''%PDF-1.1
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj
trailer<</Root 1 0 R>>
%%EOF
''');

class _Storage implements KeyValueStorage {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

/// The web client (ADR-0018): sign-in required, no local library, file import
/// but no export, local data only while signed in.
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

  testWidgets('hides the local library', (tester) async {
    final app = await start(tester, user: _ann);
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-switcher')).last);
    await tester.pumpAndSettle();
    expect(find.text('The Band'), findsWidgets);
    expect(find.text('On this device'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('imports ChordPro files into the band and syncs them', (
    tester,
  ) async {
    final app = await start(tester, user: _ann);
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('songs-import')));
    await tester.pumpAndSettle();
    expect(find.text('Import ChordPro files'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final result = await tester.runAsync(
      () => container.read(importExportProvider).importFiles([
        ImportFile('web.cho', utf8.encode('{title: From the browser}\n[G]La')),
      ]),
    );
    expect(result!.imported, 1);

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

    expect(
      app.backend.songs.values.map((s) => s.title),
      contains('From the browser'),
    );
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
    await openSettingsCategory(tester, SettingsCategory.account);
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

  testWidgets('an invitation URL opens the join screen', (tester) async {
    final app = await start(tester);
    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    // The page was opened at https://app.setding.app/invite/<token>.
    final link = app.backend
        .addFounderInvite('Choir')
        .replaceFirst('api.', 'app.');
    app.links.add(Uri.parse(link));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Join'), findsOneWidget);
    // The link is checked first, also signed out (ADR-0024).
    expect(find.text('Found Choir?'), findsOneWidget);
    // Signed out: it offers to create an account or sign in first.
    expect(find.byKey(const Key('join-sign-up')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a stored choice of the local library is not used', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      before: (app) => app.prefs.setString('currentBandId', localBandId),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(currentBandProvider).id, 'b1');
    await app.dispose(tester);
  });

  testWidgets('a stored choice of the local song library is not used', (
    tester,
  ) async {
    final app = await start(
      tester,
      user: _ann,
      before: (app) => app.prefs.setString('currentLibraryId', localBandId),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(currentLibraryProvider).id, 'org-b1');
    expect(container.read(librariesProvider).value!.map((l) => l.id), [
      'org-b1',
    ]);
    await app.dispose(tester);
  });

  testWidgets('shows no "Offline ready" status', (tester) async {
    final app = await start(tester, user: _ann);
    // After the start: the band arrives with the first refresh.
    await SetRepository(
      app.db,
      app.storage,
      bandId: 'b1',
    ).createSet(name: 'Gig');
    await tester.pumpAndSettle();
    await openTab(tester, HomeTab.sets);
    // Listed and, on the wide test screen, shown next to the list (#266):
    // neither has the status.
    expect(find.text('Gig'), findsNWidgets(2));
    expect(find.byType(SetScreen), findsOneWidget);
    expect(find.byType(OfflineMissingBadge), findsNothing);
    // No sync warning either: the web client makes no offline promise.
    expect(find.byKey(const Key('sync-stale-banner')), findsNothing);
    await app.dispose(tester);
  });

  group('PDF attachments are loaded when opened', () {
    Future<(TestApp, LiveItem)> pdfSong(
      WidgetTester tester, {
      bool landscape = true,
    }) async {
      final cache = Directory.systemTemp.createTempSync('setding_pdfrx');
      addTearDown(() => cache.deleteSync(recursive: true));
      Pdfrx.cacheDirectoryPath = cache.path;
      useTabletSize(tester, landscape: landscape);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _ann,
        web: true,
      );
      app.backend.addBand('b1', 'The Band', admin: _ann);
      app.backend.files['a1_x.pdf'] = _pdf;
      // Synced from the server: the record without the file (ADR-0018).
      final songs = TestApp.songsIn(app, 'org-b1');
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
              sizeBytes: _pdf.length,
              updatedAt: DateTime(2026),
            ),
          );
      return (app, LiveItem.song((await songs.getSong(id))!));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    for (final landscape in [true, false]) {
      testWidgets('downloads and shows the PDF (landscape: $landscape)', (
        tester,
      ) async {
        final (app, item) = await pdfSong(tester, landscape: landscape);
        await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
        await settle(tester);
        expect(find.byKey(const Key('pdf-missing')), findsNothing);
        if (landscape) {
          // Two pages side by side, loaded from memory (ADR-0009).
          expect(find.byType(PdfSpreadView), findsOneWidget);
          expect(
            find.byKey(const ValueKey('pdf-spread-page-1')),
            findsOneWidget,
          );
        } else {
          expect(find.byType(PdfViewer), findsOneWidget);
        }
        expect(app.backend.downloads, 1);
        // Live mode in the browser is not offline-safe (ADR-0018).
        expect(find.byKey(const Key('live-web-notice')), findsOneWidget);
        await app.dispose(tester);
      });
    }

    testWidgets('explains a failed download', (tester) async {
      final (app, item) = await pdfSong(tester);
      app.backend.offlineFiles.add('a1_x.pdf');
      await tester.pumpWidget(app.build(home: LiveScreen(items: [item])));
      await settle(tester);
      expect(
        find.text(
          'The PDF could not be loaded from the server. Check the connection '
          'and open the song again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PdfViewer), findsNothing);
      expect(find.byType(PdfSpreadView), findsNothing);
      await app.dispose(tester);
    });
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
