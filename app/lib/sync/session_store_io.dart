import 'dart:io';

import 'session_store.dart';

/// Session in a plain file. Only for isolated test instances
/// (`REALCHORD_DATA_DIR`, see Makefile), which must not touch the session
/// of a normally installed app.
class FileSessionStore implements SessionStore {
  FileSessionStore(this.file);

  final File file;
  String? _current;

  @override
  String? get current => _current;

  @override
  Future<void> load() async {
    _current = await file.exists() ? await file.readAsString() : null;
  }

  @override
  Future<void> write(String value) async {
    _current = value;
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  }

  @override
  Future<void> delete() async {
    _current = null;
    if (await file.exists()) await file.delete();
  }
}
