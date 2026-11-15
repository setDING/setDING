import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Maximum size of an attachment (ADR-0009).
const maxAttachmentBytes = 20 * 1024 * 1024;

/// File extensions of image attachments for `{image}` (ADR-0012).
const imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'];

String _extension(String fileName) =>
    p.extension(fileName).replaceFirst('.', '').toLowerCase();

/// Whether a stored attachment file is a PDF.
bool isPdfFile(String fileName) => _extension(fileName) == 'pdf';

/// Whether a stored attachment file is an image.
bool isImageFile(String fileName) =>
    imageExtensions.contains(_extension(fileName));

/// Whether a stored attachment file is an SVG image.
bool isSvgFile(String fileName) => _extension(fileName) == 'svg';

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

  /// Writes [fileName] through a temporary file that [fill] writes, so a
  /// failed or interrupted write never leaves a partial file.
  Future<void> writeWith(
    String fileName,
    Future<void> Function(File temp) fill,
  ) async {
    await directory.create(recursive: true);
    final temp = file('$fileName.part');
    try {
      await fill(temp);
      await temp.rename(file(fileName).path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
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
