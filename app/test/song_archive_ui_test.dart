import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/songs_screen.dart';
import 'package:setding/ui/widgets/export_file.dart';

import 'test_app.dart';

/// Song archive of ADR-0043 §1c (#792) in the UI.
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 score'.codeUnits);

  /// The export and import run outside the fake clock (database, isolates):
  /// waits for [done] in real time.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
    await tester.pumpAndSettle();
  }

  bool shown(Key key) => find.byKey(key).evaluate().isNotEmpty;

  Override saveTo(List<(String, Uint8List)> saved) =>
      saveFileProvider.overrideWithValue((name, bytes, {mimeType = ''}) async {
        saved.add((name, bytes));
        return true;
      });

  testWidgets('a song is exported with its attachments from its menu', (
    tester,
  ) async {
    useTabletSize(tester);
    final saved = <(String, Uint8List)>[];
    final app = await TestApp.create(prefs: {'language': 'en'});
    final songId = (await tester.runAsync(() async {
      final song = await app.songs.createSong(source: '{title: Hello}\n[C]x');
      await app.songs.addAttachment(song, name: 'Score', bytes: pdf);
      return song;
    }))!;
    await tester.pumpWidget(
      app.build(
        home: SongScreen(songId: songId),
        extra: [saveTo(saved)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Export ChordPro file'), findsOneWidget);
    await tester.tap(find.byKey(const Key('song-export-archive')));
    await tester.pumpAndSettle();

    expect(find.text('Export song'), findsOneWidget);
    // Attachments on, the own adjustments off by default; the local band's
    // arrangements may be added.
    bool checked(String key) => tester
        .widget<CheckboxListTile>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(CheckboxListTile),
          ),
        )
        .value!;
    expect(checked('song-export-attachments'), isTrue);
    expect(checked('song-export-arrangements'), isFalse);
    expect(checked('song-export-personal'), isFalse);
    await tester.tap(find.byKey(const Key('song-export-start')));
    await waitFor(tester, () => saved.isNotEmpty);

    expect(saved.single.$1, 'Hello.zip');
    final archive = (await tester.runAsync(
      () => SongArchiveService.read(saved.single.$2),
    ))!;
    expect(archive.titles, ['Hello']);
    expect(
      BackupService.attachmentsOf(archive.contents.songs.single).single['name'],
      'Score',
    );
    await app.dispose(tester);
  });

  testWidgets('selected songs are exported together from the song list', (
    tester,
  ) async {
    useTabletSize(tester);
    final saved = <(String, Uint8List)>[];
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Alpha}\n[C]x');
      await app.songs.createSong(source: '{title: Beta}\n[C]x');
    });
    await tester.pumpWidget(
      app.build(home: const SongsScreen(), extra: [saveTo(saved)]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-export-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Export 2 songs'), findsOneWidget);
    await tester.tap(find.byKey(const Key('song-export-start')));
    await waitFor(tester, () => saved.isNotEmpty);

    expect(saved.single.$1, startsWith('setDING-Songs '));
    final archive = (await tester.runAsync(
      () => SongArchiveService.read(saved.single.$2),
    ))!;
    expect(archive.titles.toSet(), {'Alpha', 'Beta'});
    await app.dispose(tester);
  });

  testWidgets('the import dialog recognises exported songs, shows a preview '
      'and completes the attachments of a song already here', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final (existing, zip) = (await tester.runAsync(() async {
      final hello = await app.songs.createSong(source: '{title: Hello}\n[C]x');
      await app.songs.addAttachment(hello, name: 'Score', bytes: pdf);
      final bye = await app.songs.createSong(source: '{title: Bye}\n[G]y');
      final zip = await SongArchiveService(BackupService(app.db, app.storage))
          .export([hello, bye]);
      // Here "Hello" lost its attachment and "Bye" is gone.
      for (final a in await app.songs.getAttachments(hello)) {
        await app.songs.deleteAttachment(a);
      }
      await app.songs.deleteSong(bye);
      return (hello, zip);
    }))!;

    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => [ImportFile('Songs.zip', zip)],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files'));
    await waitFor(tester, () => shown(const Key('song-import-start')));
    await waitFor(
      tester,
      () => find.text('1 new, added to the library').evaluate().isNotEmpty,
    );

    expect(find.text('Import songs'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Bye'), findsOneWidget);
    expect(find.text('1 already here with the same text'), findsOneWidget);
    expect(
      find.text('1 attachment added to songs that are already here'),
      findsOneWidget,
    );
    expect(find.text('Attachments (PDFs, images)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('song-import-start')));
    await waitFor(tester, () => shown(const Key('song-import-result')));
    expect(find.text('Songs imported'), findsOneWidget);
    expect(
      find.textContaining('1 attachment added to existing songs'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('song-import-close')));
    await tester.pumpAndSettle();

    final attachments = (await tester.runAsync(
      () => app.songs.getAttachments(existing),
    ))!;
    expect([for (final a in attachments) a.name], ['Score']);
    final songs = (await tester.runAsync(
      () => (app.db.select(
        app.db.songs,
      )..where((s) => s.deleted.equals(false))).get(),
    ))!;
    expect({for (final s in songs) s.title}, {'Hello', 'Bye'});
    await app.dispose(tester);
  });
}
