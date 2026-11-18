/// The HTTP client of the app (ADR-0018: no `dart:io` in shared code).
library;

export 'http_client_web.dart' if (dart.library.io) 'http_client_io.dart';
