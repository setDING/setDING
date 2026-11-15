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

/// The app-private directory used before the rename to RealChord, derived
/// from the current [supportDir], or null if the platform needs no move.
///
/// The directory name comes from the application ID on Linux
/// (`ch.bandchords.bandchords`) and from company and product name on Windows
/// (`ch.bandchords\BandChords`). Android and iOS installs with the old
/// application ID are separate apps; the MVP was never installed there.
Directory? legacySupportDir(Directory supportDir) {
  final name = p.basename(supportDir.path);
  final parent = p.dirname(supportDir.path);
  if (name == 'ch.realchord.realchord') {
    return Directory(p.join(parent, 'ch.bandchords.bandchords'));
  }
  if (name == 'RealChord' && p.basename(parent) == 'ch.realchord') {
    return Directory(p.join(p.dirname(parent), 'ch.bandchords', 'BandChords'));
  }
  return null;
}

/// Moves the directory from before the rename to RealChord (database,
/// attachments, settings) to [supportDir], unless [supportDir] already has
/// content. An empty [supportDir] is replaced: `path_provider` creates the
/// directory when it is first asked for it. Returns true if something was
/// moved.
Future<bool> migrateLegacySupportDir(Directory supportDir) async {
  final legacy = legacySupportDir(supportDir);
  if (legacy == null || !await legacy.exists()) return false;
  if (await supportDir.exists()) {
    if (!await supportDir.list().isEmpty) return false;
    await supportDir.delete();
  }
  await supportDir.parent.create(recursive: true);
  await legacy.rename(supportDir.path);
  return true;
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
