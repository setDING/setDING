import 'dart:io';

import 'package:path/path.dart' as p;

/// File name of the local database.
const databaseFileName = 'setding.sqlite';

/// Returns the database file inside the app's private [supportDir] and
/// creates the directory if needed.
Future<File> resolveDatabaseFile(Directory supportDir) async {
  await supportDir.create(recursive: true);
  return File(p.join(supportDir.path, databaseFileName));
}
