import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/database.dart';
import 'package:setding/platform/svg_viewer_page.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/songs/save_attachment.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/widgets/export_file.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

AttachmentEntry _entry(String name, String fileName) => AttachmentEntry(
  id: 'a1',
  songId: 's1',
  name: name,
  fileName: fileName,
  sizeBytes: 3,
  revision: 0,
  updatedAt: DateTime(2026),
  deleted: false,
  purged: false,
);

/// An attachment can be saved as a file, not only viewed and removed
/// (#1025).
void main() {
  group('file name and type', () {
    test('the name gets the extension of the stored file', () {
      expect(attachmentSaveName(_entry('Horns', 'x1.pdf')), 'Horns.pdf');
      expect(attachmentSaveName(_entry('Horns.PDF', 'x1.pdf')), 'Horns.pdf');
      expect(attachmentSaveName(_entry('a/b: c?', 'x1.png')), 'ab c.png');
      expect(attachmentSaveName(_entry(' ', 'x1.svg')), 'untitled.svg');
    });

    test('the media type follows the extension', () {
      expect(attachmentMimeType('x.pdf'), 'application/pdf');
      expect(attachmentMimeType('x.JPG'), 'image/jpeg');
      expect(attachmentMimeType('x.svg'), 'image/svg+xml');
      expect(attachmentMimeType('x.bin'), 'application/octet-stream');
    });

    // An SVG of a bandmate opened as a document in a tab of the web client
    // would run its scripts in the app's origin (#1227): it is shown as an
    // image on a page that forbids scripts.
    test('an SVG is opened as an image on a page without scripts', () {
      final svg = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg">'
        '<script>alert(1)</script></svg>',
      );
      final page = svgViewerPage(Uint8List.fromList(svg));
      expect(page, isNot(contains('<script')));
      expect(page, isNot(contains('<svg')));
      expect(page, contains("content=\"default-src 'none'; img-src data:;"));
      expect(
        page,
        contains(
          '<img alt="" src="data:image/svg+xml;base64,${base64Encode(svg)}">',
        ),
      );
      expect(RegExp('<img').allMatches(page), hasLength(1));
    });
  });

  group('song screen', () {
    late List<(String, Uint8List, String)> saved;
    final bytes = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

    setUp(() => saved = []);

    Widget build(TestApp app, String songId) => app.build(
      home: SongScreen(songId: songId),
      extra: [
        saveFileProvider.overrideWithValue((
          name,
          bytes, {
          mimeType = '',
        }) async {
          saved.add((name, bytes, mimeType));
          return true;
        }),
      ],
    );

    Future<(String, String)> addSong(TestApp app, WidgetTester tester) async =>
        (await tester.runAsync(() async {
          final id = await app.songs.createSong(source: '{title: X}\n[G]One');
          final pdfId = await app.songs.addAttachment(
            id,
            name: 'Lead sheet',
            bytes: bytes,
            pages: 1,
          );
          return (id, pdfId);
        }))!;

    Future<void> save(WidgetTester tester, String pdfId) async {
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('attachment-menu-$pdfId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 20 && saved.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
    }

    testWidgets('a PDF is saved under its name', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final (id, pdfId) = await addSong(app, tester);
      await tester.pumpWidget(build(app, id));
      await tester.pumpAndSettle();

      await save(tester, pdfId);
      expect(saved.single.$1, 'Lead sheet.pdf');
      expect(saved.single.$2, bytes);
      expect(saved.single.$3, 'application/pdf');
      expect(find.text('Saved'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('the menu reads Rename, Save, divider, Delete', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final (id, pdfId) = await addSong(app, tester);
      await tester.pumpWidget(build(app, id));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-attachments')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('attachment-menu-$pdfId')));
      await tester.pumpAndSettle();
      double y(Finder f) => tester.getTopLeft(f).dy;
      final rename = y(find.text('Rename'));
      final save = y(find.text('Save'));
      final divider = y(find.byType(PopupMenuDivider));
      final delete = y(find.text('Delete'));
      expect(rename < save && save < divider && divider < delete, isTrue);
      await app.dispose(tester);
    });

    testWidgets('a member who cannot edit can save, too', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _bob,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      app.backend.addMember('b1', _bob, BandRole.member);
      final (id, pdfId) = (await tester.runAsync(() async {
        final songs = TestApp.songsIn(app, 'o1');
        final id = await songs.createSong(source: '{title: X}\n[G]One');
        final pdfId = await songs.addAttachment(
          id,
          name: 'Lead sheet',
          bytes: bytes,
          pages: 1,
        );
        return (id, pdfId);
      }))!;
      await tester.pumpWidget(build(app, id));
      await tester.pumpAndSettle();

      await save(tester, pdfId);
      expect(find.text('Rename'), findsNothing);
      expect(saved.single.$1, 'Lead sheet.pdf');
      await app.dispose(tester);
    });

    testWidgets('a file that is not on the device is reported', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final (id, pdfId) = await addSong(app, tester);
      await tester.runAsync(() async {
        final a = await (app.db.select(
          app.db.attachments,
        )..where((t) => t.id.equals(pdfId))).getSingle();
        await app.storage.delete(a.fileName);
      });
      await tester.pumpWidget(build(app, id));
      await tester.pumpAndSettle();

      await save(tester, pdfId);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(
        find.text('The attachment "Lead sheet" of "X" could not be loaded.'),
        findsOneWidget,
      );
      await app.dispose(tester);
    });

    testWidgets('the web client downloads the file first', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _ann,
        web: true,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      final (id, pdfId) = (await tester.runAsync(() async {
        final songs = TestApp.songsIn(app, 'o1');
        final id = await songs.createSong(source: '{title: X}\n[G]One');
        final pdfId = await songs.addAttachment(
          id,
          name: 'Lead sheet',
          bytes: bytes,
          pages: 1,
        );
        return (id, pdfId);
      }))!;
      await tester.runAsync(() async {
        final a = await (app.db.select(
          app.db.attachments,
        )..where((t) => t.id.equals(pdfId))).getSingle();
        await app.storage.delete(a.fileName);
        await (app.db.update(app.db.attachments)
              ..where((t) => t.id.equals(pdfId)))
            .write(const AttachmentsCompanion(remoteFile: Value('srv.pdf')));
        app.backend.files['srv.pdf'] = bytes;
      });
      await tester.pumpWidget(build(app, id));
      await tester.pumpAndSettle();

      await save(tester, pdfId);
      expect(saved.single.$1, 'Lead sheet.pdf');
      expect(saved.single.$2, bytes);
      await app.dispose(tester);
    });
  });
}
