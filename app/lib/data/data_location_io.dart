import 'dart:io';

import 'package:path/path.dart' as p;

/// File name of the local database.
const databaseFileName = 'realchord.sqlite';

/// File name of the database before the app was renamed from its working
/// title BandChords to RealChord.
const legacyDatabaseFileName = 'bandchords.sqlite';

/// Returns the database file inside the app's private [supportDir].
///
/// Older databases are moved to the current location (including SQLite's
/// `-wal`/`-shm` side files) if none exists there yet:
/// - `bandchords.sqlite` in [supportDir] (before the rename to RealChord);
/// - `bandchords.sqlite` in [legacyDir]: earlier versions stored the database
///   in the documents directory, which on desktop platforms is the user's
///   visible "Documents" folder.
Future<File> resolveDatabaseFile(
  Directory supportDir, {
  Directory? legacyDir,
}) async {
  await supportDir.create(recursive: true);
  final target = File(p.join(supportDir.path, databaseFileName));
  if (await target.exists()) return target;

  final candidates = [
    File(p.join(supportDir.path, legacyDatabaseFileName)),
    if (legacyDir != null) File(p.join(legacyDir.path, legacyDatabaseFileName)),
  ];
  for (final legacy in candidates) {
    if (!await legacy.exists()) continue;
    for (final suffix in ['', '-wal', '-shm']) {
      final source = File('${legacy.path}$suffix');
      if (await source.exists()) await _move(source, '${target.path}$suffix');
    }
    break;
  }
  return target;
}

Future<void> _move(File source, String targetPath) async {
  try {
    await source.rename(targetPath);
  } on FileSystemException {
    // Different file systems: copy, then delete.
    await source.copy(targetPath);
    await source.delete();
  }
}
