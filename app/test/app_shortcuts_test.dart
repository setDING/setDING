import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/home_tab.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/widgets/app_shortcuts.dart';

import 'test_app.dart';

/// Keyboard shortcuts (#729, ADR-0049).
void main() {
  Future<TestApp> pump(WidgetTester tester, Widget home) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: home));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String character) async {
    final (key, physical) = switch (character) {
      '+' => (LogicalKeyboardKey.add, PhysicalKeyboardKey.equal),
      '-' => (LogicalKeyboardKey.minus, PhysicalKeyboardKey.minus),
      '?' => (LogicalKeyboardKey.slash, PhysicalKeyboardKey.slash),
      _ => (LogicalKeyboardKey.slash, PhysicalKeyboardKey.slash),
    };
    await tester.sendKeyEvent(key, character: character, physicalKey: physical);
    await tester.pumpAndSettle();
  }

  group('song', () {
    Future<(TestApp, String)> pumpSong(WidgetTester tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final id = await app.songs.createSong(
        source: '{title: One}\n{key: C}\n[C]Line',
      );
      await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
      await tester.pumpAndSettle();
      return (app, id);
    }

    testWidgets('E opens the editor', (tester) async {
      final (app, _) = await pumpSong(tester);
      await press(tester, LogicalKeyboardKey.keyE);
      expect(find.byType(SongEditorScreen), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('L starts live mode', (tester) async {
      final (app, _) = await pumpSong(tester);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(find.byType(LiveScreen), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('+ and − transpose', (tester) async {
      final (app, id) = await pumpSong(tester);
      await type(tester, '+');
      await type(tester, '+');
      expect((await app.songs.getOverlay(id)).transpose, 2);
      await type(tester, '-');
      expect((await app.songs.getOverlay(id)).transpose, 1);
      await press(tester, LogicalKeyboardKey.numpadSubtract);
      await press(tester, LogicalKeyboardKey.numpadSubtract);
      expect((await app.songs.getOverlay(id)).transpose, -1);
      await app.dispose(tester);
    });

    testWidgets('no shortcuts while a dialog is open', (tester) async {
      final (app, _) = await pumpSong(tester);
      showDialog<void>(
        context: tester.element(find.byType(SongScreen)),
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyE);
      expect(find.byType(SongEditorScreen), findsNothing);
      await app.dispose(tester);
    });
  });

  group('set', () {
    Future<(TestApp, String)> pumpSet(WidgetTester tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final ids = [
        for (final title in ['First', 'Second', 'Third'])
          await app.songs.createSong(source: '{title: $title}\n[C]Line'),
      ];
      final setId = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(setId, ids.sublist(0, 2));
      await app.sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');
      await app.sets.addSongs(setId, ids.sublist(2));
      await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
      await tester.pumpAndSettle();
      return (app, setId);
    }

    String shownSong(WidgetTester tester) =>
        (tester.widget<AppBar>(find.byType(AppBar).last).title! as Text).data!;

    testWidgets('← and → go through the songs of the set', (tester) async {
      final (app, _) = await pumpSet(tester);
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(shownSong(tester), 'Second');
      // Over the break to the next song.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(shownSong(tester), 'Third');
      // The last song stays.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(shownSong(tester), 'Third');
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(shownSong(tester), 'First');
      // Back goes to the set, not through the songs.
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(SongScreen), findsNothing);
      expect(find.byType(SetScreen), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('E edits the set', (tester) async {
      final (app, _) = await pumpSet(tester);
      await press(tester, LogicalKeyboardKey.keyE);
      expect(find.byType(AlertDialog), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('L starts live mode', (tester) async {
      final (app, _) = await pumpSet(tester);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(find.byType(LiveScreen), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a song opened without a set ignores ← and →', (tester) async {
      final (app, _) = await pumpSet(tester);
      final id = (await app.songs.createSong(source: '{title: Alone}'));
      Navigator.push(
        tester.element(find.byType(SetScreen)),
        MaterialPageRoute<void>(builder: (_) => SongScreen(songId: id)),
      );
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(shownSong(tester), 'Alone');
      await app.dispose(tester);
    });
  });

  group('song list', () {
    EditableText searchField(WidgetTester tester) =>
        tester.widget<EditableText>(
          find.descendant(
            of: find.byType(SearchBar, skipOffstage: false),
            matching: find.byType(EditableText, skipOffstage: false),
            skipOffstage: false,
          ),
        );

    testWidgets('/ and Ctrl+F focus the search; typing stays typing', (
      tester,
    ) async {
      final app = await pump(tester, const HomeScreen());
      await openTab(tester, HomeTab.songs);
      await app.songs.createSong(source: '{title: Ending}');
      await tester.pumpAndSettle();

      await type(tester, '/');
      expect(searchField(tester).focusNode.hasFocus, isTrue);
      // In the field, "e" is a letter, not "edit".
      await tester.enterText(find.byType(SearchBar, skipOffstage: false), 'e');
      await press(tester, LogicalKeyboardKey.keyE);
      expect(find.byType(SongEditorScreen), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(searchField(tester).focusNode.hasFocus, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await press(tester, LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(searchField(tester).focusNode.hasFocus, isTrue);
      await app.dispose(tester);
    });

    testWidgets('Esc closes the selection, also from the search', (
      tester,
    ) async {
      final app = await pump(tester, const HomeScreen());
      await openTab(tester, HomeTab.songs);
      await app.songs.createSong(source: '{title: Ending}');
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Songs'),
      );
      expect(title, findsOneWidget);

      await tester.longPress(find.text('Ending'));
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      await press(tester, LogicalKeyboardKey.escape);
      expect(title, findsOneWidget);

      // From the search field, with the search text kept.
      await tester.enterText(find.byType(SearchBar), 'End');
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Ending'));
      await tester.pumpAndSettle();
      expect(searchField(tester).focusNode.hasFocus, isTrue);
      await press(tester, LogicalKeyboardKey.escape);
      expect(title, findsOneWidget);
      expect(searchField(tester).controller.text, 'End');
      await app.dispose(tester);
    });

    testWidgets('a hidden tab takes no shortcuts', (tester) async {
      final app = await pump(tester, const HomeScreen());
      await openTab(tester, HomeTab.songs);
      await openTab(tester, HomeTab.sets);
      await type(tester, '/');
      expect(searchField(tester).focusNode.hasFocus, isFalse);
      await app.dispose(tester);
    });
  });

  group('help', () {
    testWidgets('? lists the shortcuts, once', (tester) async {
      final app = await pump(tester, const HomeScreen());
      await type(tester, '?');
      expect(find.byType(ShortcutHelpDialog), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Edit the song'), findsOneWidget);
      // Not a second dialog above the first.
      await type(tester, '?');
      expect(find.byType(ShortcutHelpDialog), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ShortcutHelpDialog), findsNothing);
      await app.dispose(tester);
    });
  });
}
