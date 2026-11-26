import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/sync/sync_backend.dart' show AuthUser;
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/routes.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/sets/sets_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// The browser history as the web engine keeps it: the entries the router
/// reports (`routeInformationUpdated`), and the browser's back button, which
/// sends the previous entry back to the app (`pushRouteInformation`).
class _BrowserHistory {
  _BrowserHistory(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method != 'routeInformationUpdated') return null;
        final args = (call.arguments as Map).cast<String, Object?>();
        final entry = (uri: args['uri']! as String, state: args['state']);
        if (args['replace'] == true && entries.isNotEmpty) {
          entries[entries.length - 1] = entry;
        } else {
          entries.add(entry);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
  }

  final WidgetTester tester;
  final entries = <({String uri, Object? state})>[];

  /// The browser's back button: the previous entry becomes the current one.
  Future<void> back() async {
    entries.removeLast();
    final entry = entries.last;
    final message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {
        'location': entry.uri,
        'state': entry.state,
      }),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      message,
      (_) {},
    );
    await tester.pumpAndSettle();
  }
}

/// URL routing (ADR-0065, #1113): every screen has a path, the browser's
/// back button goes back to the previous screen, a link opens its screen.
void main() {
  Future<TestApp> start(WidgetTester tester, {bool web = false}) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, web: web);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  String location(WidgetTester tester) =>
      routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

  Future<void> go(WidgetTester tester, String location) async {
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('the browser back button goes back to the previous screen', (
    tester,
  ) async {
    // The bug of #1113: the app pushed its screens without browser history
    // entries, so the back button left setDING.
    final history = _BrowserHistory(tester);
    final app = await start(tester);
    final setId = await app.sets.createSet(name: 'Gig');
    await tester.pumpAndSettle();

    await openTab(tester, HomeTab.sets);
    expect(history.entries.last.uri, AppPaths.sets);
    unawaited(routerOf(tester).push(AppPaths.set(setId)));
    await tester.pumpAndSettle();
    expect(find.byType(SetScreen), findsWidgets);
    expect(history.entries.last.uri, AppPaths.set(setId));
    expect(history.entries.length, greaterThanOrEqualTo(3));

    await history.back();
    expect(location(tester), AppPaths.sets);
    expect(find.byType(SetsScreen), findsOneWidget);

    await history.back();
    expect(location(tester), AppPaths.overview);
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)), isNotNull);
    await app.dispose(tester);
  });

  testWidgets('the browser back button asks before discarding an edit', (
    tester,
  ) async {
    final history = _BrowserHistory(tester);
    final app = await start(tester);
    final id = await app.songs.createSong(source: '{title: Ending}\n[C]La');
    unawaited(routerOf(tester).push(AppPaths.songEdit(id)));
    await tester.pumpAndSettle();
    expect(find.byType(SongEditorScreen), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'changed');
    await tester.pumpAndSettle();

    await history.back();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SongEditorScreen), findsOneWidget);
    // The source is untouched.
    expect((await app.songs.getSong(id))!.chordproSource, contains('Ending'));
    await app.dispose(tester);
  });

  testWidgets('a link opens its screen above its tab, with a back button', (
    tester,
  ) async {
    final app = await start(tester);
    final setId = await app.sets.createSet(name: 'Gig');
    await go(tester, AppPaths.set(setId));
    expect(find.byType(SetScreen), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(location(tester), AppPaths.sets);
    expect(find.byType(SetsScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the tabs have paths', (tester) async {
    final app = await start(tester);
    await openTab(tester, HomeTab.songs);
    expect(location(tester), AppPaths.songs);
    await openTab(tester, HomeTab.settings);
    expect(location(tester), AppPaths.settings);
    // A path selects its tab.
    await go(tester, AppPaths.sets);
    expect(find.byType(SetsScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a song opened from a link opens by itself', (tester) async {
    final app = await start(tester);
    final id = await app.songs.createSong(source: '{title: Ending}');
    // Without the set the route passes along (a link), the song opens alone.
    await go(tester, AppPaths.song(id));
    final screen = tester.widget<SongScreen>(find.byType(SongScreen));
    expect(screen.songId, id);
    expect(screen.setSongs, isNull);
    await app.dispose(tester);
  });

  testWidgets('the editor opened from a link loads the song', (tester) async {
    final app = await start(tester);
    final id = await app.songs.createSong(source: '{title: Ending}\n[C]La');
    await go(tester, AppPaths.songEdit(id));
    final editor = tester.widget<SongEditorScreen>(
      find.byType(SongEditorScreen),
    );
    // Never an empty text that saving would write over the song.
    expect(editor.initialSource, contains('{title: Ending}'));
    await app.dispose(tester);
  });

  testWidgets('live mode opens from its path', (tester) async {
    final app = await start(tester);
    final song = await app.songs.createSong(source: '{title: Ending}\n[C]La');
    final setId = await app.sets.createSet(name: 'Gig');
    await app.sets.addSongs(setId, [song]);
    await go(tester, AppPaths.setLive(setId));
    expect(find.byType(LiveScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('every path opens a screen', (tester) async {
    final app = await start(tester);
    final song = await app.songs.createSong(source: '{title: Ending}');
    final setId = await app.sets.createSet(name: 'Gig');
    for (final path in [
      AppPaths.overview,
      AppPaths.sets,
      AppPaths.songs,
      AppPaths.settings,
      AppPaths.set(setId),
      AppPaths.song(song),
      AppPaths.songNew,
      AppPaths.songLive(song),
      AppPaths.settingsCategory(SettingsCategory.live),
      AppPaths.songDisplayEditor,
      AppPaths.bands,
      AppPaths.closedOrganizations,
      AppPaths.recentChanges,
      AppPaths.join,
      AppPaths.signIn,
    ]) {
      await go(tester, path);
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.isError,
        isFalse,
        reason: path,
      );
      // Leave the editor of a new song without asking.
      if (path == AppPaths.songNew) await go(tester, AppPaths.overview);
    }
    await app.dispose(tester);
  });

  testWidgets('a signed-out web visitor signs in and lands on the link', (
    tester,
  ) async {
    const ann = AuthUser(
      id: 'u-ann@example.test',
      email: 'ann@example.test',
      name: 'Ann',
    );
    final app = await start(tester, web: true);
    app.backend.addBand('b1', 'The Band', admin: ann);
    app.backend.accounts[ann.email] = 'secret-pw';

    await go(tester, AppPaths.recentChanges);
    expect(find.byKey(const Key('web-sign-in')), findsOneWidget);
    expect(
      Uri.parse(location(tester)).queryParameters[AppPaths.nextParameter],
      AppPaths.recentChanges,
    );

    await tester.enterText(find.byKey(const Key('account-email')), ann.email);
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'secret-pw',
    );
    await tester.tap(find.byKey(const Key('account-submit')));
    await tester.pumpAndSettle();
    expect(location(tester), AppPaths.recentChanges);
    await app.dispose(tester);
  });

  test('the web client starts at the URL it was opened at', () {
    // The engine's default route can miss it after a reload (#1113).
    expect(webStartLocation(Uri.parse('https://app.test/')), '/');
    expect(webStartLocation(Uri.parse('https://app.test')), '/');
    expect(
      webStartLocation(Uri.parse('https://app.test/songs/abc/edit')),
      '/songs/abc/edit',
    );
    expect(
      webStartLocation(Uri.parse('https://app.test/sets/abc/live?index=2')),
      '/sets/abc/live?index=2',
    );
  });
}
