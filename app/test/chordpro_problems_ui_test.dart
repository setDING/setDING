import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'package:setding/ui/home_tab.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Warning icons for songs whose ChordPro has problems (#314).
void main() {
  const broken = '{title: Washed}\n{c: Chorus} (first time a cappella)\n[G]la';

  testWidgets('the song list and the song mark ChordPro problems', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: broken);
      await app.songs.createSong(source: '{title: Fine}\n[C]x');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('song-status-problems'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: badge, matching: find.byType(ListTile)),
        matching: find.text('Washed'),
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
        '1 place in the ChordPro will probably not be shown as intended',
      ),
      findsOneWidget,
    );

    // The song offers to show the problem: the editor opens with it
    // selected.
    await tester.tap(find.text('Washed'));
    await tester.pumpAndSettle();
    // The warning is the badge of the edit button (#600).
    expect(
      find.descendant(
        of: find.byKey(const Key('edit-song')),
        matching: find.byKey(const Key('song-problems')),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Show the ChordPro problem'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-song')));
    await tester.pumpAndSettle();
    expect(find.byType(SongEditorScreen), findsOneWidget);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(
      controller.selection.textInside(controller.text),
      '(first time a cappella)',
    );
    await app.dispose(tester);
  });

  testWidgets('a song without problems has no warning', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = (await tester.runAsync(
      () => app.songs.createSong(source: '{title: Fine}\n[C]x'),
    ))!;
    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-problems')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('members who cannot edit the song see no warning', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: _bob,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.addMember('b1', _bob, BandRole.member);
    final id = (await tester.runAsync(
      () => TestApp.songsIn(app, 'o1').createSong(source: broken),
    ))!;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Washed'), findsOneWidget);
    expect(find.byKey(const ValueKey('song-status-problems')), findsNothing);

    await tester.pumpWidget(app.build(home: SongScreen(songId: id)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-problems')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('sets show how many songs have problems', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final a = await app.songs.createSong(source: broken);
      final b = await app.songs.createSong(source: '{title: Fine}\n[C]x');
      final c = await app.songs.createSong(source: '{title: Open}\n[C x');
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [a, b, c]);
      final clean = await app.sets.createSet(name: 'Clean');
      await app.sets.addSongs(clean, [b]);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await openTab(tester, HomeTab.sets);

    expect(find.byKey(const ValueKey('set-problems')), findsOneWidget);
    expect(find.byTooltip('2 songs with ChordPro problems'), findsOneWidget);

    await tester.tap(find.text('Gig'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('set-item-problems')), findsNWidgets(2));
    await app.dispose(tester);
  });

  testWidgets('the import reports problems and fixes them', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    ImportFile file(String name, String text) =>
        ImportFile(name, Uint8List.fromList(utf8.encode(text)));
    final files = [
      file('washed.cho', broken),
      file('fine.cho', '{title: Fine}\n[C]x'),
      file('open.cho', '{title: Open}\n[C x'),
      file('short.cho', '{title: Short}\n{sov: Verse 1}\n[C]a\n{eov}'),
    ];
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => files,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    // The import writes to the database outside the fake clock: wait for
    // [done] in real time.
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    final report = find.byKey(const Key('import-problems'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files'));
    await waitFor(() => report.evaluate().isNotEmpty);
    await tester.pumpAndSettle();

    expect(report, findsOneWidget);
    expect(find.text('4 songs imported'), findsOneWidget);
    expect(find.textContaining('2 imported songs contain'), findsOneWidget);
    expect(find.text('• Washed (1 place)'), findsOneWidget);
    expect(find.text('• Open (1 place)'), findsOneWidget);

    expect(
      find.textContaining('1 imported song writes section labels'),
      findsOneWidget,
    );

    // Fixing keeps the report open for the labels.
    await tester.tap(find.text('Fix automatically'));
    final labels = find.byKey(const Key('import-legacy-labels'));
    await waitFor(() => find.text('Fix automatically').evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 song fixed'), findsOneWidget);
    expect(labels, findsOneWidget);
    expect(find.text('• Washed (1 place)'), findsNothing);

    await tester.tap(find.text('Convert labels'));
    await waitFor(() => report.evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Labels converted in 1 song'), findsOneWidget);
    final songs = (await tester.runAsync(
      () => app.db.select(app.db.songs).get(),
    ))!;
    expect(
      {for (final s in songs) s.title: s.chordproProblems},
      {'Fine': 0, 'Open': 1, 'Short': 0, 'Washed': 0},
    );
    expect(
      songs.firstWhere((s) => s.title == 'Short').chordproSource,
      startsWith('{title: Short}\n{sov: label="Verse 1"}\n[C]a\n{eov}'),
    );
    await app.dispose(tester);
  });

  testWidgets('the import report suggests keys from the chords (#925)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    ImportFile file(String name, String text) =>
        ImportFile(name, Uint8List.fromList(utf8.encode(text)));
    final files = [
      file('g.cho', '{title: In G}\n[G]a [C]b [D]c [G]d'),
      file('am.cho', '{title: In Am}\n[Am]a [F]b [C]c [G]d [Am]e'),
      file('keyed.cho', '{title: Keyed}\n{key: A}\n[A]a [D]b [E]c'),
    ];
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => files,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    Future<Map<String, String?>> keys() async => {
      for (final s in (await tester.runAsync(
        () => app.db.select(app.db.songs).get(),
      ))!)
        s.title: s.songKey,
    };

    final report = find.byKey(const Key('import-problems'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files'));
    await waitFor(() => report.evaluate().isNotEmpty);
    await tester.pumpAndSettle();

    // Only key suggestions: the report opens for them alone.
    expect(find.byKey(const Key('import-key-suggestions')), findsOneWidget);
    expect(find.textContaining('2 imported songs have no key'), findsOneWidget);
    expect(find.text('In G'), findsOneWidget);
    expect(find.text('In Am'), findsOneWidget);
    expect(find.text('Keyed'), findsNothing);
    expect(find.text('Fix automatically'), findsNothing);
    expect(await keys(), {'In G': null, 'In Am': null, 'Keyed': 'A'});

    // Picking the runner-up writes it; the row goes away.
    final c = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('import-key-') &&
          (w.key! as ValueKey<String>).value.endsWith('-C'),
    );
    expect(c, findsOneWidget);
    await tester.tap(c);
    await waitFor(() => find.text('In Am').evaluate().isEmpty);
    expect(report, findsOneWidget);
    expect((await keys())['In Am'], 'C');

    // The last one closes the report.
    final g = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.endsWith('-G') &&
          (w.key! as ValueKey<String>).value.startsWith('import-key-'),
    );
    await tester.tap(g);
    await waitFor(() => report.evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Keys set in 2 songs'), findsOneWidget);
    expect(await keys(), {'In G': 'G', 'In Am': 'C', 'Keyed': 'A'});
    await app.dispose(tester);
  });

  testWidgets('the editor offers to convert short-form labels (#672)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    const source =
        '{title: T}\n{start_of_verse: Verse 1}\n[C]a\n{end_of_verse}\n'
        '{soc: Chorus}\n[G]b\n{eoc}';
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(find.byType(LegacyLabelHint), findsOneWidget);
    expect(
      find.textContaining('2 section labels are in the short form'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(LegacyLabelHint),
        matching: find.widgetWithText(TextButton, 'Convert'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.text,
      '{title: T}\n{start_of_verse: label="Verse 1"}\n[C]a\n{end_of_verse}\n'
      '{soc: label="Chorus"}\n[G]b\n{eoc}',
    );
    expect(find.byType(LegacyLabelHint), findsNothing);
    // Saving shows no problem dialog for the short form.
    controller.text = source;
    await tester.pumpAndSettle();
    expect(find.byType(LegacyLabelHint), findsOneWidget);
    await tester.tap(find.byTooltip('Hide hint'));
    await tester.pumpAndSettle();
    expect(find.byType(LegacyLabelHint), findsNothing);
    expect(controller.text, source);
    await app.dispose(tester);
  });

  testWidgets('the editor offers to convert SongSelect directives (#777)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    const source = '{title: T}\n{ccli: 123}\n{ccli_license: 456}\n[C]a';
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(find.byType(SongSelectDirectiveHint), findsOneWidget);
    expect(
      find.textContaining('2 CCLI directives do not follow'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SongSelectDirectiveHint),
        matching: find.widgetWithText(TextButton, 'Convert'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.text, '{title: T}\n{x_ccli: 123}\n[C]a');
    expect(find.byType(SongSelectDirectiveHint), findsNothing);
    // Hiding leaves the text as it is.
    controller.text = source;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide hint'));
    await tester.pumpAndSettle();
    expect(find.byType(SongSelectDirectiveHint), findsNothing);
    expect(controller.text, source);
    await app.dispose(tester);
  });

  testWidgets('the editor offers to remove the CCLI footer (#785)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    const source =
        '{title: T}\n{x_ccli: 1}\n\n[C]a\n\nCCLI Song # 1\n'
        '© 2020 Example\nCCLI License # 2\n';
    await tester.pumpWidget(
      app.build(home: const SongEditorScreen(initialSource: source)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(find.byType(CcliFooterHint), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CcliFooterHint),
        matching: find.widgetWithText(TextButton, 'Remove'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.text,
      '{title: T}\n{x_ccli: 1}\n{copyright: 2020 Example}\n\n[C]a\n',
    );
    expect(find.byType(CcliFooterHint), findsNothing);
    controller.text = source;
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CcliFooterHint),
        matching: find.byTooltip('Hide hint'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CcliFooterHint), findsNothing);
    expect(controller.text, source);
    await app.dispose(tester);
  });
}
