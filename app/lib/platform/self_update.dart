/// Installing app updates (ADR-0035; ADR-0018: no `dart:io` in shared code).
library;

export 'self_update_web.dart' if (dart.library.io) 'self_update_io.dart';
