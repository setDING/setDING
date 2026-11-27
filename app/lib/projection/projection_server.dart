/// The local web server of the lyrics projection (ADR-0068): native apps
/// only, the web client has a stub whose `start` fails.
library;

export 'projection_server_io.dart'
    if (dart.library.js_interop) 'projection_server_web.dart';
