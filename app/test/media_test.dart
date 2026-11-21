import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_lookup.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/ui/live/live_screen.dart';
import 'package:setding/ui/render/abc_view.dart';
import 'package:setding/ui/render/song_image.dart';
import 'package:setding/ui/render/song_view.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:drift/native.dart';
import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// A valid 1×1 PNG.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// PNG header with the given size (enough for [imageBytesSize]).
Uint8List pngHeader(int width, int height) {
  final b = Uint8List(24);
  b.setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(b);
  data.setUint32(16, width);
  data.setUint32(20, height);
  return b;
}

AttachmentEntry attachment(String name, String fileName) => AttachmentEntry(
  id: name,
  songId: 's',
  name: name,
  fileName: fileName,
  sizeBytes: 1,
  revision: 0,
  updatedAt: DateTime(2026),
  deleted: false,
  purged: false,
);

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">'
    '<rect width="200" height="100" fill="#3f51b5"/></svg>';

void main() {
  abcGroup();
  group('image sizes', () {
    test('raster headers', () {
      expect(imageBytesSize(pngHeader(640, 480)), const Size(640, 480));
      final gif = Uint8List.fromList([
        ...ascii.encode('GIF89a'),
        0x20, 0x01, 0x10, 0x00, // 288 x 16
      ]);
      expect(imageBytesSize(gif), const Size(288, 16));
      expect(imageBytesSize(onePixelPng), const Size(1, 1));
    });

    test('svg sizes', () {
      expect(svgSize(_svg), const Size(200, 100));
      expect(
        svgSize('<svg width="10pt" height="20pt"></svg>'),
        Size(40 / 3, 80 / 3),
      );
      expect(
        svgSize('<svg width="300" viewBox="0 0 100 50"></svg>'),
        const Size(300, 150),
      );
      expect(svgSize('<svg></svg>'), const Size(300, 150));
    });
  });

  group('ImageBox', () {
    test('natural size, points, percentages, scale and align', () {
      final natural = ImageBox.fromAttributes({}, const Size(400, 200));
      expect(natural.widthUnits, 20); // 400 px / 20
      expect(natural.aspect, 2);
      expect(natural.alignment, Alignment.center);

      final points = ImageBox.fromAttributes({
        'width': '120',
      }, const Size(400, 200));
      expect(points.widthUnits, 10); // 120 pt / 12

      final percent = ImageBox.fromAttributes({
        'width': '50%',
        'align': 'right',
      }, const Size(400, 200));
      expect(percent.width(20, 600), 300);
      expect(percent.alignment, Alignment.centerRight);

      final scaled = ImageBox.fromAttributes({
        'scale': '50%',
      }, const Size(400, 200));
      expect(scaled.widthUnits, 10);

      final byHeight = ImageBox.fromAttributes({
        'height': '60',
      }, const Size(400, 200));
      expect(byHeight.widthUnits, 10); // 5 units high × aspect 2
    });

    test('never wider than the column', () {
      final box = ImageBox.fromAttributes({}, const Size(4000, 1000));
      expect(box.width(20, 500), 500);
      expect(box.height(20, 500), 125);
    });
  });

  test('image attachments are found by file name', () {
    final list = [
      attachment('Score.PNG', 'a.png'),
      attachment('notes', 'b.pdf'),
      attachment('logo', 'c.svg'),
    ];
    expect(imageAttachmentFor(list, 'score.png')?.id, 'Score.PNG');
    expect(imageAttachmentFor(list, 'images/score.png')?.id, 'Score.PNG');
    expect(imageAttachmentFor(list, 'logo.svg')?.id, 'logo');
    expect(imageAttachmentFor(list, 'notes.pdf'), isNull);
    expect(imageAttachmentFor(list, 'missing.png'), isNull);
  });

  test('ZIP import attaches referenced images', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dir = Directory.systemTemp.createTempSync('setding_zip');
    final storage = FileAttachmentStorage(dir);
    final songs = SongRepository(db, storage);
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'song.cho',
          utf8.encode('{title: Pic}\n{image: src="score.png"}\n[C]x'),
        ),
      )
      ..addFile(ArchiveFile.bytes('score.png', onePixelPng))
      ..addFile(ArchiveFile.bytes('unused.png', onePixelPng));
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));
    final result = await ImportExportService(
      songs,
      SetRepository(db, storage),
    ).importFiles([ImportFile('songs.zip', zip)]);
    expect(result.imported, 1);
    final song = (await songs.watchSongs().first).single;
    final attachments = await songs.getAttachments(song.id);
    expect(attachments.single.name, 'score.png');
    expect(isImageFile(attachments.single.fileName), isTrue);
    await db.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('song shows attached images, SVG, textblock and Lilypond', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(() async {
      final id = await app.songs.createSong(
        source:
            '{title: Media}\n{image: src="dot.png" width=60}\n'
            '{image: src="missing.png"}\n'
            '{start_of_svg}\n$_svg\n{end_of_svg}\n'
            '{start_of_textblock flush=right}\nShe died of the fever\n{end_of_textblock}\n'
            '{start_of_ly label="Score"}\n\\relative c\' { c d e }\n{end_of_ly}\n'
            '{start_of_ly}\n\\relative c\' { << { c d } \\\\ { e f } >> }\n{end_of_ly}\n',
      );
      await app.songs.addAttachment(
        id,
        name: 'dot.png',
        bytes: onePixelPng,
        extension: 'png',
      );
      return id;
    });
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    // Image sizes scale with the font size (fitted to the screen).
    final fontSize = tester
        .widget<SongBody>(find.byType(SongBody))
        .options
        .fontSize;
    expect(
      tester.getSize(find.byType(Image)).width,
      closeTo(60 / 12 * fontSize, 0.01),
    );
    expect(find.text('missing.png'), findsOneWidget); // placeholder
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('She died of the fever'), findsOneWidget);
    // Lilypond within the subset is drawn; two voices show the source.
    expect(find.byType(AbcView), findsOneWidget);
    expect(
      find.textContaining('uses features setDING cannot draw'),
      findsOneWidget,
    );
    expect(find.text('SCORE'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('live mode fits a song with images exactly', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final song = await tester.runAsync(() async {
      final source = StringBuffer('{title: Pics}\n');
      for (var i = 0; i < 3; i++) {
        source.writeln(
          '{start_of_verse}\n[C]Line with chords [G]here\n{end_of_verse}',
        );
        source.writeln('{image: src="wide.png"}');
      }
      source.writeln('{start_of_svg}\n$_svg\n{end_of_svg}');
      final id = await app.songs.createSong(source: source.toString());
      final storage = FileAttachmentStorage(app.dir);
      final attId = await app.songs.addAttachment(
        id,
        name: 'wide.png',
        bytes: onePixelPng,
        extension: 'png',
      );
      // Pretend the image is 800 × 200 px by writing a matching header.
      await storage.write(
        (await app.songs.getAttachments(id)).single.fileName,
        pngHeader(800, 200),
      );
      expect(attId, isNotEmpty);
      return app.songs.getSong(id);
    });
    await tester.pumpWidget(
      app.build(home: LiveScreen(items: [LiveItem.song(song!)])),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsNothing);
    final body = tester.getSize(find.byType(SongBody));
    // The outermost FittedBox is the live-mode safety net (SVGs use one too).
    final box = tester.getSize(find.byType(FittedBox).first);
    expect(body.height, lessThanOrEqualTo(box.height + 0.5));
    await tester.pumpWidget(const SizedBox());
    await app.dispose(tester);
  });
}

const _abc = """X:1
T:Tune
M:4/4
L:1/8
K:D
|:"D"A2 F d2 A B c|"G"B>cd "A7"e2 c d e|(3fed ^c2 =c A B c|1 [DFA]4 d4:|2 "D"d8|]
w:one two three four
""";

void abcGroup() {
  group('ABC notation', () {
    test('lines break at bar lines to fit the width', () {
      final tune = parseAbc(_abc);
      final natural = layoutAbc(tune);
      expect(natural, hasLength(1));
      final narrow = layoutAbc(tune, maxWidth: natural.single.width / 2.5);
      expect(narrow.length, greaterThan(2));
      for (final row in narrow) {
        // Every row fits unless it is a single measure.
        expect(
          row.width <= natural.single.width / 2.5 ||
              row.line.elements.whereType<AbcBar>().length <= 2,
          isTrue,
        );
      }
      // The volta starts a row's measure, never ends a row.
      for (final row in narrow) {
        final last = row.line.elements.last;
        expect(last is AbcBar && last.volta != null, isFalse);
      }
      // A leading repeat sign stays with the first measure.
      expect(narrow.first.line.elements.whereType<AbcNote>(), isNotEmpty);
    });

    test('exact height follows the line breaks', () {
      final tune = parseAbc(_abc);
      final wide = abcHeight(tune, 20, 4000);
      final narrow = abcHeight(tune, 20, 400);
      expect(narrow, greaterThan(wide * 2));
    });

    testWidgets('renders ABC with transposition and fits in live mode', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final source =
          '{title: ABC}\n{start_of_abc}\n$_abc{end_of_abc}\n[C]After';
      final song = await tester.runAsync(() async {
        final id = await app.songs.createSong(source: source);
        return app.songs.getSong(id);
      });
      await tester.pumpWidget(
        app.build(
          home: LiveScreen(items: [LiveItem.song(song!, setTranspose: 2)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AbcView), findsOneWidget);
      expect(find.text('TUNE'), findsOneWidget); // T: as label
      expect(find.byType(SingleChildScrollView), findsNothing);
      final body = tester.getSize(find.byType(SongBody));
      final box = tester.getSize(find.byType(FittedBox).first);
      expect(body.height, lessThanOrEqualTo(box.height + 0.5));
      // Transposed by the set item: D major becomes E major.
      final tune = notationTuneOf(
        parseChordPro(source).elements.whereType<DelegateSection>().single,
        2,
      )!;
      expect(tune.key.name, 'E');
      await app.dispose(tester);
    });
  });
}
