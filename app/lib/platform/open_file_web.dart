import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens [bytes] in a new browser tab, where the browser shows it with its
/// own viewer (ADR-0048). Returns false if the browser blocked the tab.
Future<bool> openFileInDefaultApp(
  String fileName,
  Uint8List bytes, {
  required String mimeType,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  // The tab keeps its own reference; the URL is released once it loaded.
  Future.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
  return tab != null;
}
