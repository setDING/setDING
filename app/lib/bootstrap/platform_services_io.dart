import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/attachment_storage_io.dart';
import '../data/data_location_io.dart';
import '../data/database.dart';
import '../sync/session_store.dart';
import '../sync/session_store_io.dart';
import 'platform_services.dart';

/// Opens the services of the native apps.
Future<PlatformServices> openPlatformServices() async {
  final appSupportDir = await getApplicationSupportDirectory();
  // All data lives in the app's private directory (ADR-0001). On desktop
  // the documents directory is the user's visible "Documents" folder.
  // SETDING_DATA_DIR (development only, see Makefile) runs an isolated
  // test instance and never touches existing data.
  final override = Platform.environment['SETDING_DATA_DIR'];
  final isolated = override != null && override.isNotEmpty;
  final supportDir = isolated ? Directory(override) : appSupportDir;
  final dbFile = await resolveDatabaseFile(supportDir);
  final db = AppDatabase(
    driftDatabase(
      name: 'setding',
      native: DriftNativeOptions(databasePath: () async => dbFile.path),
    ),
  );
  final storage = FileAttachmentStorage(
    Directory(p.join(supportDir.path, 'attachments')),
  );
  // The session (sign-in) is kept in the platform's secure storage; an
  // isolated test instance keeps its own session in its data directory.
  final SessionStore sessionStore = isolated
      ? FileSessionStore(File(p.join(supportDir.path, 'session.json')))
      : SecureSessionStore();
  return (db: db, storage: storage, sessionStore: sessionStore);
}
