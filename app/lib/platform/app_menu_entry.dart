/// The application menu entry of the Linux AppImage (#1006; ADR-0018: no
/// `dart:io` in shared code).
library;

export 'app_menu_entry_web.dart' if (dart.library.io) 'app_menu_entry_io.dart';
