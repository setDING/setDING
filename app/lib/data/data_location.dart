import 'dart:io';

import 'package:path/path.dart' as p;

/// File name of the local database.
const databaseFileName = 'bandchords.sqlite';

/// Returns the database file inside the app's private [supportDir].
///
/// Earlier versions stored the database in the documents directory, which on
/// desktop platforms is the user's visible "Documents" folder. If a database
/// exists there and none in [supportDir] yet, it is moved over (including
/// SQLite's `-wal`/`-shm` side files).
Future<File> resolveDatabaseFile(
  Directory supportDir, {
  Directory? legacyDir,
}) async {
  await supportDir.create(recursive: true);
  final target = File(p.join(supportDir.path, databaseFileName));
  if (legacyDir == null || await target.exists()) return target;

  final legacy = File(p.join(legacyDir.path, databaseFileName));
  if (!await legacy.exists()) return target;
  for (final suffix in ['', '-wal', '-shm']) {
    final source = File('${legacy.path}$suffix');
    if (await source.exists()) await _move(source, '${target.path}$suffix');
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
