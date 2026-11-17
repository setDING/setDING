import 'package:web/web.dart' as web;

/// Whether the app can load a newer version of itself: the web client is
/// served by the server, so a reload fetches the current build (ADR-0018).
const canReload = true;

/// Loads the web client again from the server.
void reloadApp() => web.window.location.reload();
