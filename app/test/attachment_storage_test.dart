import 'dart:io';
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
      expect(attachmentTypeOf(text('<svg xmlns="x"/>')), 'svg');
      expect(attachmentTypeOf(text('  \n<SVG width="1">')), 'svg');
      expect(
        attachmentTypeOf(
          text(
            '\u00EF\u00BB\u00BF<?xml version="1.0"?>\n<!-- by hand -->\n'
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
