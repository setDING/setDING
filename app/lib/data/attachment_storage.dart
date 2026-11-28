import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Upper bound for reading an attachment kept on the device: files from
/// before the limit of ADR-0070 (#1227) may be up to 20 MB.
const maxAttachmentBytes = 20 * 1024 * 1024;

/// Maximum size of a PDF attachment, the server's limit (ADR-0070).
const maxPdfBytes = 1024 * 1024;

/// Maximum size of an image attachment for `{image}`: synced like PDFs, so
/// the server's limit applies too (ADR-0070, #1227).
const maxImageBytes = maxPdfBytes;

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

/// Whether an attachment file of this type is synced with the server: PDFs
/// (ADR-0009) and images for `{image}` (#1227).
bool isSyncedFile(String fileName) =>
    isPdfFile(fileName) || isImageFile(fileName);

/// The maximum size of the attachment file [fileName]: 1 MB for a PDF or an
/// image (ADR-0070), [maxAttachmentBytes] for anything else.
int maxAttachmentBytesFor(String fileName) => isPdfFile(fileName)
    ? maxPdfBytes
    : isImageFile(fileName)
    ? maxImageBytes
    : maxAttachmentBytes;

/// The type of an attachment file by its content (magic bytes), as an
/// extension ('pdf', 'png', 'jpg', 'gif', 'webp', 'svg'); null for anything
/// else. The server detects the type the same way and refuses other files
/// (#1227), so the app checks it before a file is attached.
String? attachmentTypeOf(List<int> bytes) {
  bool starts(List<int> magic, [int offset = 0]) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (starts('%PDF-'.codeUnits)) return 'pdf';
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'png';
  }
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) return 'gif';
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) return 'webp';
  if (_isSvg(bytes)) return 'svg';
  return null;
}

/// How many bytes the server looks at to detect an SVG (#1244).
const _svgHead = 4096;

/// Whitespace as the server's type detection sees it (no vertical tab, no
/// non-breaking space).
const _ws = r'[ \t\n\r\f]';

final _comment = RegExp(r'<!--[\s\S]*?-->');
final _svgStart = RegExp('<svg$_ws');
final _svgElement = RegExp('<svg(?:$_ws|/|>)');
final _attribute = RegExp(
  '([^\\s=/>]+)$_ws*=$_ws*("[^"]*"|\'[^\']*\'|[^\\s>]+)',
);
final _declaration = RegExp('<\\?xml$_ws(?:[^?]|\\?(?!>))*\\?>');
final _prolog = RegExp(
  '(?:$_ws+|<!--[\\s\\S]*?-->|<\\?(?:[^?]|\\?(?!>))*\\?>'
  '|<!DOCTYPE$_ws[^\\[>]*(?:\\[[^\\]]*\\])?$_ws*>)*',
);

/// Whether [bytes] are an SVG document that the server also detects as one
/// (#1227): text without control characters whose first element is `<svg`,
/// within the first [_svgHead] bytes, and either
///
/// - after an XML declaration with a `version` (and optional comments,
///   processing instructions and a doctype, also with an internal subset),
///   or
/// - without one, after only whitespace and comments right before it, with
///   the SVG namespace (`xmlns="http://www.w3.org/2000/svg"`).
///
/// The server refuses a byte order mark, upper-case tags, whitespace after a
/// leading comment and an SVG without namespace or declaration, so the app
/// refuses them too, instead of a file that never syncs (#1244).
bool _isSvg(List<int> bytes) {
  final head = bytes.length > _svgHead ? bytes.sublist(0, _svgHead) : bytes;
  // Binary content is never an SVG; the server allows these controls only.
  for (final b in head) {
    if (b < 0x20 && b != 0x09 && b != 0x0A && b != 0x0C && b != 0x0D) {
      return false;
    }
  }
  final text = String.fromCharCodes(head);
  var at = RegExp('^$_ws*').firstMatch(text)!.end;
  final declaration = _declaration.matchAsPrefix(text, at);
  if (declaration != null) {
    final attributes = text.substring(at + 5, declaration.end - 2);
    if (!_attribute
        .allMatches(attributes)
        .any((m) => m.group(1) == 'version')) {
      return false;
    }
    at = _prolog.matchAsPrefix(text, declaration.end)!.end;
    return _svgElement.matchAsPrefix(text, at) != null;
  }
  for (Match? m; (m = _comment.matchAsPrefix(text, at)) != null;) {
    at = m!.end;
  }
  if (_svgStart.matchAsPrefix(text, at) == null) return false;
  final tagEnd = _startTagEnd(text, at + 4);
  if (tagEnd == null) return false;
  return _attribute
      .allMatches(text.substring(at + 4, tagEnd))
      .any(
        (m) =>
            m.group(1) == 'xmlns' &&
            _unquote(m.group(2)!) == 'http://www.w3.org/2000/svg',
      );
}

/// The offset of the `>` that ends the start tag whose attributes begin at
/// [from] (a `>` inside a quoted value does not count); null if it is not
/// in [text].
int? _startTagEnd(String text, int from) {
  String? quote;
  for (var i = from; i < text.length; i++) {
    final c = text[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == '"' || c == "'") {
      quote = c;
    } else if (c == '>') {
      return i;
    }
  }
  return null;
}

String _unquote(String value) =>
    value.length >= 2 && (value[0] == '"' || value[0] == "'")
    ? value.substring(1, value.length - 1)
    : value;

/// Whether the content of [bytes] is the type that the extension of
/// [fileName] says (`jpeg` and `jpg` are the same).
bool contentMatchesType(String fileName, List<int> bytes) {
  final ext = _extension(fileName);
  final type = attachmentTypeOf(bytes);
  return type != null && type == (ext == 'jpeg' ? 'jpg' : ext);
}

/// Thrown when the content of an attachment is not the type its extension
/// says ([contentMatchesType]); the server would refuse it.
class AttachmentTypeMismatchException implements Exception {
  const AttachmentTypeMismatchException(this.extension);
  final String extension;

  @override
  String toString() => 'Attachment content is not a $extension file';
}

/// The media type of an attachment file.
String attachmentMimeType(String fileName) => switch (_extension(fileName)) {
  'pdf' => 'application/pdf',
  'png' => 'image/png',
  'jpg' || 'jpeg' => 'image/jpeg',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  'svg' => 'image/svg+xml',
  _ => 'application/octet-stream',
};

/// Thrown when an attachment exceeds [maxAttachmentBytesFor] its type.
class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException(this.sizeBytes, {required this.limitBytes});
  final int sizeBytes;
  final int limitBytes;

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
