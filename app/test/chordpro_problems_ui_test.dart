import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_editor_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';

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
    expect(find.text('3 songs imported'), findsOneWidget);
    expect(find.textContaining('2 imported songs contain'), findsOneWidget);
    expect(find.text('• Washed (1 place)'), findsOneWidget);
    expect(find.text('• Open (1 place)'), findsOneWidget);

    await tester.tap(find.text('Fix automatically'));
    await waitFor(() => report.evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 song fixed'), findsOneWidget);
    final songs = (await tester.runAsync(
      () => app.db.select(app.db.songs).get(),
    ))!;
    expect(
      {for (final s in songs) s.title: s.chordproProblems},
      {'Fine': 0, 'Open': 1, 'Washed': 0},
    );
    await app.dispose(tester);
  });
}
