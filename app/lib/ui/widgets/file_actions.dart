import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/import_export.dart';

/// Lets the user pick files; returns them with their content.
Future<List<ImportFile>> pickFiles({List<String>? extensions}) async {
  final files = await FilePicker.pickFiles(
    type: extensions == null ? FileType.any : FileType.custom,
    allowedExtensions: extensions,
  );
  return [for (final f in files) ImportFile(f.name, await f.readAsBytes())];
}

/// Saves [bytes] via the platform's save dialog. Returns false if cancelled.
Future<bool> saveFile(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return uri != null;
}

/// Counts the pages of a PDF, or null if it cannot be read.
Future<int?> countPdfPages(Uint8List bytes) async {
  try {
    final doc = await PdfDocument.openData(bytes);
    final count = doc.pages.length;
    await doc.dispose();
    return count;
  } catch (_) {
    return null;
  }
}
