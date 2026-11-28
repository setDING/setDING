import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_storage_memory.dart';

/// The native (files) and web (memory) storages behave the same (ADR-0018).
void main() {
  final variants = <String, AttachmentStorage Function()>{
    'FileAttachmentStorage': () {
      final dir = Directory.systemTemp.createTempSync('setding_storage');
      addTearDown(() => dir.deleteSync(recursive: true));
      return FileAttachmentStorage(Directory('${dir.path}/attachments'));
    },
    'MemoryAttachmentStorage': MemoryAttachmentStorage.new,
  };

  for (final MapEntry(key: name, value: create) in variants.entries) {
    group(name, () {
      late AttachmentStorage storage;
      setUp(() => storage = create());

      test('writes, reads, copies and deletes files', () async {
        expect(await storage.usedBytes(), 0);
        expect(storage.file('a.pdf').existsSync(), isFalse);
        expect(storage.file('a.pdf').readStartSync(10), isNull);

        await storage.write('a.pdf', Uint8List.fromList([1, 2, 3, 4]));
        final file = storage.file('a.pdf');
        expect(file.name, 'a.pdf');
        expect(file.existsSync(), isTrue);
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), [1, 2, 3, 4]);
        expect(file.readStartSync(2), [1, 2]);
        expect(file.readStartSync(10), [1, 2, 3, 4]);

        await storage.copy('a.pdf', 'b.pdf');
        await storage.copy('missing.pdf', 'c.pdf');
        expect(await storage.file('b.pdf').readAsBytes(), [1, 2, 3, 4]);
        expect(await storage.exists('c.pdf'), isFalse);
        expect(await storage.usedBytes(), 8);

        await storage.delete('a.pdf');
        await storage.delete('missing.pdf');
        expect(await storage.exists('a.pdf'), isFalse);
        expect(await storage.usedBytes(), 4);
      });

      test('writeWith stores what is added to the sink', () async {
        await storage.writeWith('s.pdf', (sink) async {
          sink.add([1, 2]);
          await sink.addStream(
            Stream.fromIterable([
              [3],
              [4, 5],
            ]),
          );
        });
        expect(await storage.file('s.pdf').readAsBytes(), [1, 2, 3, 4, 5]);
        expect(await storage.usedBytes(), 5);
      });

      test('a failed writeWith leaves no file behind', () async {
        await expectLater(
          storage.writeWith('f.pdf', (sink) async {
            sink.add([1, 2]);
            throw const SocketException('offline');
          }),
          throwsA(isA<SocketException>()),
        );
        expect(await storage.exists('f.pdf'), isFalse);
        expect(await storage.usedBytes(), 0);
      });

      test('ids differ between storages', () {
        expect(storage.file('x.png').id, isNot(create().file('x.png').id));
      });
    });
  }

  // The server detects the type by content and refuses other files
  // (#1227); the app checks the same before attaching.
  group('attachmentTypeOf', () {
    List<int> text(String s) => s.codeUnits;

    test('detects the synced types by their content', () {
      expect(attachmentTypeOf(text('%PDF-1.7\n')), 'pdf');
      expect(
        attachmentTypeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
        'png',
      );
      expect(attachmentTypeOf([0xFF, 0xD8, 0xFF, 0xE1, 0]), 'jpg');
      expect(attachmentTypeOf(text('GIF87a..')), 'gif');
      expect(attachmentTypeOf(text('GIF89a..')), 'gif');
      expect(attachmentTypeOf(text('RIFF\x00\x00\x00\x00WEBPVP8 ')), 'webp');
      expect(attachmentTypeOf(text('RIFF\x00\x00\x00\x00WAVEfmt ')), isNull);
      expect(attachmentTypeOf(const []), isNull);
      expect(attachmentTypeOf(text('just text')), isNull);
    });

    test('an SVG is text whose first element is <svg', () {
      expect(
        attachmentTypeOf(text('<svg xmlns="http://www.w3.org/2000/svg"/>')),
        'svg',
      );
      expect(
        attachmentTypeOf(
          text('  \n<svg width="1" xmlns="http://www.w3.org/2000/svg">'),
        ),
        'svg',
      );
      expect(
        attachmentTypeOf(
          text(
            '<?xml version="1.0"?>\n<!-- by hand -->\n'
            '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "x.dtd">\n'
            '<svg viewBox="0 0 1 1"></svg>',
          ),
        ),
        'svg',
      );
      // HTML with an SVG inside is no SVG, nor is a binary file.
      expect(attachmentTypeOf(text('<html><svg/></html>')), isNull);
      expect(attachmentTypeOf(text('<svgfoo/>')), isNull);
      expect(attachmentTypeOf([...text('<svg '), 0, 1]), isNull);
    });

    // #1244: the app took SVGs that the server refuses (a byte order mark,
    // upper-case tags, no namespace or declaration, whitespace after a
    // leading comment, a doctype without declaration), so they never
    // synced; and it refused an SVG with a doctype with an internal subset
    // (Adobe Illustrator) that the server takes. What the server does was
    // probed against PocketBase; the app accepts no SVG the server refuses.
    group('SVGs as the server detects them (#1244)', () {
      const ns = 'xmlns="http://www.w3.org/2000/svg"';
      const decl = '<?xml version="1.0"?>\n';
      final cases = <String, (List<int>, bool)>{
        'plain': (text('<svg $ns/>'), true),
        'leading whitespace': (text(' \n\t\r\n\f<svg $ns/>'), true),
        'tab after the name': (text('<svg\t$ns/>'), true),
        'newline after the name': (text('<svg\n$ns/>'), true),
        'namespace in single quotes': (
          text("<svg xmlns='http://www.w3.org/2000/svg'/>"),
          true,
        ),
        'namespace not first': (text('<svg width="1" $ns/>'), true),
        'namespace with spaces': (
          text('<svg xmlns = "http://www.w3.org/2000/svg"/>'),
          true,
        ),
        'unquoted namespace': (
          text('<svg xmlns=http://www.w3.org/2000/svg />'),
          true,
        ),
        '> in a value before the namespace': (text('<svg a=">" $ns/>'), true),
        'comment right before': (text('<!--a--><!--b--><svg $ns/>'), true),
        'declaration': (text('$decl<svg/>'), true),
        'declaration in single quotes': (
          text("<?xml version='1.0'?><svg/>"),
          true,
        ),
        'declaration with encoding first': (
          text('<?xml encoding="UTF-8" version="1.0"?><svg/>'),
          true,
        ),
        'declaration and doctype': (
          text(
            '$decl<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" '
            '"x.dtd">\n<svg $ns/>',
          ),
          true,
        ),
        'doctype with internal subset (Illustrator)': (
          text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Generator: Adobe Illustrator -->\n'
            '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "svg11.dtd" [\n'
            '\t<!ENTITY ns_svg "http://www.w3.org/2000/svg">\n]>\n'
            '<svg xmlns="&ns_svg;"/>',
          ),
          true,
        ),
        'stylesheet instruction': (
          text('$decl<?xml-stylesheet href="a.css"?>\n<svg $ns/>'),
          true,
        ),
        'Latin-1 text': (
          [...text('<svg $ns><text>'), 0xE9, 0xFF, ...text('</text></svg>')],
          true,
        ),
        'byte order mark': ([0xEF, 0xBB, 0xBF, ...text('<svg $ns/>')], false),
        'byte order mark and declaration': (
          [0xEF, 0xBB, 0xBF, ...text('$decl<svg/>')],
          false,
        ),
        'UTF-16': (
          [
            0xFF,
            0xFE,
            for (final c in '<svg/>'.codeUnits) ...[c, 0],
          ],
          false,
        ),
        'upper-case tag': (text('<SVG $ns/>'), false),
        'upper-case tag after declaration': (text('$decl<SVG $ns/>'), false),
        'upper-case declaration': (text('<?XML version="1.0"?><svg/>'), false),
        'declaration without version': (
          text('<?xml encoding="utf-8"?>\n<svg $ns/>'),
          false,
        ),
        'no namespace': (text('<svg width="1"/>'), false),
        'no attribute': (text('<svg>'), false),
        'other namespace': (text('<svg xmlns="http://example.com"/>'), false),
        'https namespace': (
          text('<svg xmlns="https://www.w3.org/2000/svg"/>'),
          false,
        ),
        'upper-case XMLNS': (
          text('<svg XMLNS="http://www.w3.org/2000/svg"/>'),
          false,
        ),
        'namespace on a child': (text('<svg><g $ns/></svg>'), false),
        'slash after the name': (text('<svg/ $ns>'), false),
        'whitespace after a comment': (text('<!-- hi -->\n<svg $ns/>'), false),
        'doctype without declaration': (
          text('<!DOCTYPE svg>\n<svg $ns/>'),
          false,
        ),
        'HTML doctype': (text('<!DOCTYPE html>\n<svg $ns/>'), false),
        'HTML around': (text('<html><svg $ns/></html>'), false),
        'HTML after declaration': (text('$decl<html><svg/></html>'), false),
        'text before': (text('hello <svg $ns/>'), false),
        'vertical tab before': (text('\v<svg $ns/>'), false),
        'non-breaking space before': (text(' <svg $ns/>'), false),
        'control character inside': (text('<svg $ns>\u0001</svg>'), false),
        'NUL at the end': (text('<svg $ns/>\u0000'), false),
        'svg element past 4 KB': (
          text('$decl<!--${'x' * 4100}--><svg/>'),
          false,
        ),
        'whitespace past 4 KB': (text('${' ' * 4096}<svg $ns/>'), false),
      };
      for (final MapEntry(key: name, value: (bytes, svg)) in cases.entries) {
        test(name, () {
          expect(attachmentTypeOf(bytes), svg ? 'svg' : isNull);
          expect(contentMatchesType('a.svg', bytes), svg);
        });
      }
    });

    // #1244: truncated, mutated and polyglot content never throws, and a
    // type is only reported for content that starts like that type.
    test('fuzzed content never throws and keeps its type', () {
      final random = Random(1244);
      final iterations =
          int.tryParse(Platform.environment['FUZZ_ITERATIONS'] ?? '') ?? 2000;
      final samples = <String, List<int>>{
        'pdf': text('%PDF-1.7\n%âãÏÓ\n1 0 obj'),
        'png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13],
        'jpg': [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46],
        'gif': text('GIF89a\x01\x00\x01\x00'),
        'webp': text('RIFF\x1a\x00\x00\x00WEBPVP8L'),
        'svg': text(
          '<?xml version="1.0"?>\n<!DOCTYPE svg [<!ENTITY a "b">]>\n'
          '<svg xmlns="http://www.w3.org/2000/svg"><!-- x --></svg>',
        ),
      };
      final pieces = [
        for (final s in samples.values) s,
        text('<!--'),
        text('-->'),
        text('<?xml '),
        text('?>'),
        text('<!DOCTYPE '),
        text('['),
        text(']>'),
        text('<svg '),
        text('<SVG'),
        text('<html>'),
        text('xmlns="http://www.w3.org/2000/svg"'),
        text('"'),
        text("'"),
        text('>'),
        [0xEF, 0xBB, 0xBF],
        [0],
        [0xFF],
        text(' ' * 300),
        text('\n'),
      ];
      // Every cut of a type's start is no type: no truncated magic.
      for (final MapEntry(key: type, value: bytes) in samples.entries) {
        if (type == 'svg') continue;
        final magic = switch (type) {
          'pdf' => 5,
          'png' => 8,
          'jpg' => 3,
          'gif' => 6,
          _ => 12,
        };
        for (var k = 0; k < magic; k++) {
          expect(
            attachmentTypeOf(bytes.sublist(0, k)),
            isNull,
            reason: '$type cut at $k',
          );
        }
      }
      for (var i = 0; i < iterations; i++) {
        final bytes = <int>[];
        for (var k = random.nextInt(8); k >= 0; k--) {
          final piece = pieces[random.nextInt(pieces.length)];
          bytes.addAll(
            random.nextBool()
                ? piece
                : piece.sublist(0, random.nextInt(piece.length + 1)),
          );
          if (random.nextInt(4) == 0) bytes.add(random.nextInt(256));
        }
        final type = attachmentTypeOf(bytes);
        // A polyglot is the type of its first bytes, never two at once.
        if (type != null && type != 'svg') {
          expect(
            contentMatchesType('a.$type', bytes),
            isTrue,
            reason: '$bytes',
          );
          expect(contentMatchesType('a.svg', bytes), isFalse);
        }
        if (type == 'svg') {
          expect(bytes.take(4096), isNot(contains(0)), reason: '$bytes');
          expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]), reason: '$bytes');
        }
      }
    });

    test('contentMatchesType compares with the extension', () {
      final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      expect(contentMatchesType('a.png', png), isTrue);
      expect(contentMatchesType('a.PNG', png), isTrue);
      expect(contentMatchesType('a.svg', png), isFalse);
      expect(contentMatchesType('a.jpeg', [0xFF, 0xD8, 0xFF, 0xE0]), isTrue);
      expect(contentMatchesType('a.jpg', [0xFF, 0xD8, 0xFF, 0xE0]), isTrue);
      expect(contentMatchesType('a.png', text('<svg/>')), isFalse);
      expect(contentMatchesType('a.bin', png), isFalse);
    });

    test('images have the server limit of 1 MB (ADR-0070)', () {
      expect(maxAttachmentBytesFor('a.png'), 1024 * 1024);
      expect(maxAttachmentBytesFor('a.svg'), 1024 * 1024);
      expect(maxAttachmentBytesFor('a.pdf'), 1024 * 1024);
      expect(isSyncedFile('a.webp'), isTrue);
      expect(isSyncedFile('a.pdf'), isTrue);
      expect(isSyncedFile('a.bin'), isFalse);
    });
  });
}
