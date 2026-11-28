import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'svg_viewer_page.dart';

/// Opens [bytes] in a new browser tab, where the browser shows it with its
/// own viewer (ADR-0048); an SVG as an image on a page without scripts
/// ([svgViewerPage]). Returns false if the browser blocked the tab.
Future<bool> openFileInDefaultApp(
  String fileName,
  Uint8List bytes, {
  required String mimeType,
}) async {
  // An SVG is never opened as a document, where its scripts would run in
  // the app's origin; a page shows it as an image instead (#1227).
  final svg = mimeType == svgMimeType;
  final content = svg
      ? Uint8List.fromList(utf8.encode(svgViewerPage(bytes)))
      : bytes;
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: svg ? 'text/html' : mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  // The tab keeps its own reference; the URL is released once it loaded.
  Future.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
  return tab != null;
}
