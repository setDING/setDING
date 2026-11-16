import 'package:drift_flutter/drift_flutter.dart';

import '../data/attachment_storage_memory.dart';
import '../data/database.dart';
import '../sync/session_store.dart';
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
  // Session handling for the web follows in its own step of issue #27; until
  // then the session lasts as long as the page.
  return (
    db: db,
    storage: MemoryAttachmentStorage(),
    sessionStore: MemorySessionStore(),
  );
}
