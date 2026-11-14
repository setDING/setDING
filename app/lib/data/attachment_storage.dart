import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Maximum size of a PDF attachment (ADR-0009).
const maxAttachmentBytes = 20 * 1024 * 1024;

/// Thrown when an attachment exceeds [maxAttachmentBytes].
class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException(this.sizeBytes);
  final int sizeBytes;

  @override
  String toString() => 'Attachment too large: $sizeBytes bytes';
}

/// Stores attachment files in the app's private directory (ADR-0001).
class AttachmentStorage {
  AttachmentStorage(this.directory);

  final Directory directory;

  File file(String fileName) => File(p.join(directory.path, fileName));

  Future<void> write(String fileName, Uint8List bytes) async {
    await directory.create(recursive: true);
    await file(fileName).writeAsBytes(bytes, flush: true);
  }

  Future<bool> exists(String fileName) => file(fileName).exists();

  Future<void> delete(String fileName) async {
    final f = file(fileName);
    if (await f.exists()) await f.delete();
  }

  /// Total size of all stored files in bytes.
  Future<int> usedBytes() async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
