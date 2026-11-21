/// Opening an exported file in the system's default app (ADR-0048).
library;

export 'open_file_io.dart' if (dart.library.js_interop) 'open_file_web.dart';
