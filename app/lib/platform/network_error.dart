/// Platform-specific network errors (ADR-0018: no `dart:io` in shared code).
library;

export 'network_error_web.dart' if (dart.library.io) 'network_error_io.dart';
