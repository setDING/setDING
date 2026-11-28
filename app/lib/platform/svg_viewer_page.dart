import 'dart:convert';
import 'dart:typed_data';

/// The media type of an SVG image.
const svgMimeType = 'image/svg+xml';

/// An HTML page that shows the SVG [bytes] as an image, for opening an SVG
/// attachment in a browser tab (web client, ADR-0048, #1227).
///
/// An SVG opened as a document runs its scripts, and a `blob:` URL has the
/// origin of the app, so an SVG from a bandmate could act as the signed-in
/// person. This page shows it only as an `<img>` (browsers never run
/// scripts or load resources of an SVG drawn as an image) and forbids every
/// script with its Content-Security-Policy.
String svgViewerPage(Uint8List bytes) {
  final data = base64Encode(bytes);
  return '<!doctype html>'
      '<html><head><meta charset="utf-8">'
      '<meta http-equiv="Content-Security-Policy" '
      "content=\"default-src 'none'; img-src data:; style-src 'unsafe-inline'\">"
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<style>html,body{margin:0;height:100%;background:#fff}'
      'body{display:flex;align-items:center;justify-content:center}'
      'img{max-width:100%;max-height:100%}</style>'
      '</head><body>'
      '<img alt="" src="data:$svgMimeType;base64,$data">'
      '</body></html>';
}
