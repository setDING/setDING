import 'package:drift_flutter/drift_flutter.dart';

import '../data/attachment_storage_memory.dart';
import '../data/database.dart';
import '../platform/browser_storage_web.dart';
import '../sync/browser_session_store.dart';
import 'platform_services.dart';

/// Opens the services of the web client (ADR-0018): the database runs in
/// the browser with drift's WASM backend (`web/sqlite3.wasm`,
/// `web/drift_worker.js`); attachments are kept in memory, not preloaded.
Future<PlatformServices> openPlatformServices() async {
  final db = AppDatabase(
    driftDatabase(
      name: 'realchord',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
  // The session lasts as long as a tab is open, or until signing out with
  // "Stay signed in" (ADR-0018).
  final sessionStore = BrowserSessionStore(
    tab: BrowserKeyValueStorage.session(),
    persistent: BrowserKeyValueStorage.local(),
    channel: BroadcastTabChannel('realchord.session'),
    onSignedOutElsewhere: reloadPage,
  );
  return (
    db: db,
    storage: MemoryAttachmentStorage(),
    sessionStore: sessionStore,
  );
}
