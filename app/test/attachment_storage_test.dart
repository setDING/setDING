import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/attachment_storage_io.dart';
import 'package:realchord/data/attachment_storage_memory.dart';

/// The native (files) and web (memory) storages behave the same (ADR-0018).
void main() {
  final variants = <String, AttachmentStorage Function()>{
    'FileAttachmentStorage': () {
      final dir = Directory.systemTemp.createTempSync('realchord_storage');
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
}
