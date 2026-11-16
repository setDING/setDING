import 'dart:async';
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

/// One attachment file in an [AttachmentStorage].
///
/// Platform-neutral (ADR-0018): the native apps keep the file on disk
/// (`attachment_storage_io.dart`), the web client in memory
/// (`attachment_storage_memory.dart`).
abstract interface class StoredFile {
  /// File name inside the storage.
  String get name;

  /// Identifies the file across storages, e.g. as a cache key.
  String get id;

  bool existsSync();

  Future<bool> exists();

  Future<Uint8List> readAsBytes();

  /// The first [maxBytes] bytes (or fewer), read synchronously for layout;
  /// null if the file does not exist or cannot be read.
  Uint8List? readStartSync(int maxBytes);
}

/// Stores attachment files on the device (ADR-0001, ADR-0009).
abstract interface class AttachmentStorage {
  StoredFile file(String fileName);

  Future<void> write(String fileName, Uint8List bytes);

  /// Writes [fileName] from what [fill] adds to its sink. A failed or
  /// interrupted write never leaves a partial file.
  Future<void> writeWith(
    String fileName,
    Future<void> Function(StreamSink<List<int>> sink) fill,
  );

  /// Copies [from] to [to]; does nothing if [from] does not exist.
  Future<void> copy(String from, String to);

  Future<bool> exists(String fileName);

  Future<void> delete(String fileName);

  /// Total size of all stored files in bytes.
  Future<int> usedBytes();

  /// Deletes all stored files (web sign-out, ADR-0018).
  Future<void> deleteAll();
}
