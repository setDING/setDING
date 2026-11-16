import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/attachment_storage_io.dart';
import '../data/data_location_io.dart';
import '../data/database.dart';
import '../sync/session_store.dart';
import '../sync/session_store_io.dart';
import '../util/log.dart';
import 'platform_services.dart';

const _log = Log('app');

/// Opens the services of the native apps. Runs before the settings are read
/// because data from before the rename to RealChord is moved first, and
/// shared_preferences lives in the same directory on desktop platforms.
Future<PlatformServices> openPlatformServices() async {
  final appSupportDir = await getApplicationSupportDirectory();
  await _migrateLegacySupportDir(appSupportDir);
  // All data lives in the app's private directory (ADR-0001). On desktop
  // the documents directory is the user's visible "Documents" folder.
  // REALCHORD_DATA_DIR (development only, see Makefile) runs an isolated
  // test instance and never touches existing data.
  final override = Platform.environment['REALCHORD_DATA_DIR'];
  final isolated = override != null && override.isNotEmpty;
  final supportDir = isolated ? Directory(override) : appSupportDir;
  final dbFile = await resolveDatabaseFile(
    supportDir,
    legacyDir: isolated ? null : await _legacyDocumentsDir(),
  );
  final db = AppDatabase(
    driftDatabase(
      name: 'realchord',
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

/// Where earlier versions stored the database, or null if unavailable.
Future<Directory?> _legacyDocumentsDir() async {
  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    return null;
  }
}

/// Moves the app directory from before the rename; never blocks the start.
Future<void> _migrateLegacySupportDir(Directory supportDir) async {
  try {
    await migrateLegacySupportDir(supportDir);
  } on FileSystemException catch (e) {
    _log.warning('Could not move data from before the rename', e);
  }
}
