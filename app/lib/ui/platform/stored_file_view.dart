/// Widgets that show stored attachment files (ADR-0018: no `dart:io` in
/// shared code). Native apps open the file on disk; the web client shows the
/// bytes it holds in memory.
library;

export 'stored_file_view_web.dart'
    if (dart.library.io) 'stored_file_view_io.dart';
