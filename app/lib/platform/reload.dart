/// Reloading the web client (ADR-0018: no `dart:html` in shared code).
library;

export 'reload_io.dart' if (dart.library.js_interop) 'reload_web.dart';
