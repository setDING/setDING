import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'attachment_storage.dart';

/// Attachment files in the app's private directory (native apps, ADR-0001).
class FileAttachmentStorage implements AttachmentStorage {
  FileAttachmentStorage(this.directory);

  final Directory directory;

  File _file(String fileName) => File(p.join(directory.path, fileName));

  @override
  IoStoredFile file(String fileName) => IoStoredFile(_file(fileName));

  @override
  Future<void> write(String fileName, Uint8List bytes) async {
    await directory.create(recursive: true);
    await _file(fileName).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> writeWith(
    String fileName,
    Future<void> Function(StreamSink<List<int>> sink) fill,
  ) async {
    await directory.create(recursive: true);
    final temp = _file('$fileName.part');
    try {
      final sink = temp.openWrite();
      try {
        await fill(sink);
      } finally {
        await sink.close();
      }
      await temp.rename(_file(fileName).path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  @override
  Future<void> copy(String from, String to) async {
    final source = _file(from);
    if (!await source.exists()) return;
    await directory.create(recursive: true);
    await source.copy(_file(to).path);
  }

  @override
  Future<bool> exists(String fileName) => _file(fileName).exists();

  @override
  Future<void> delete(String fileName) async {
    final f = _file(fileName);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteAll() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<int> usedBytes() async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}

/// An attachment file on disk; [file] lets native viewers open it directly.
class IoStoredFile implements StoredFile {
  IoStoredFile(this.file);

  final File file;

  @override
  String get name => p.basename(file.path);

  @override
  String get id => file.path;

  @override
  bool existsSync() => file.existsSync();

  @override
  Future<bool> exists() => file.exists();

  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  Uint8List? readStartSync(int maxBytes) {
    try {
      final raf = file.openSync();
      try {
        return raf.readSync(maxBytes);
      } finally {
        raf.closeSync();
      }
    } on FileSystemException {
      return null;
    }
  }
}
