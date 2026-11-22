import 'dart:typed_data';

import 'backup_folder.dart';

/// The web client has no local library (ADR-0018), so no automatic backup.
BackupFolder createBackupFolder() => const _NoBackupFolder();

class _NoBackupFolder implements BackupFolder {
  const _NoBackupFolder();

  @override
  bool get supported => false;

  @override
  Future<BackupFolderChoice?> pick() async => null;

  @override
  Future<List<String>> list(String location) =>
      throw const BackupFolderException(BackupFolderError.unavailable);

  @override
  Future<void> write(String location, String name, Uint8List bytes) =>
      throw const BackupFolderException(BackupFolderError.unavailable);

  @override
  Future<void> delete(String location, String name) =>
      throw const BackupFolderException(BackupFolderError.unavailable);

  @override
  Future<String> deviceName() async => '';
}
