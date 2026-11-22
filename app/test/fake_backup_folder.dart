import 'dart:typed_data';

import 'package:setding/platform/backup_folder.dart';

/// A backup folder in memory (ADR-0054): [files] by name; [choice] is what
/// the folder picker returns; [error] makes every access fail.
class FakeBackupFolder implements BackupFolder {
  FakeBackupFolder({this.device = 'Test tablet', this.choice});

  final String device;
  BackupFolderChoice? choice;
  BackupFolderError? error;
  final files = <String, Uint8List>{};

  /// Every write and rename, in order (to see the temporary name).
  final log = <String>[];

  @override
  bool get supported => true;

  @override
  Future<BackupFolderChoice?> pick() async => choice;

  void _check() {
    if (error case final error?) throw BackupFolderException(error);
  }

  @override
  Future<List<String>> list(String location) async {
    _check();
    return files.keys.toList();
  }

  @override
  Future<void> write(String location, String name, Uint8List bytes) async {
    _check();
    final part = '$name$backupPartSuffix';
    files[part] = bytes;
    log.add('write $part');
    files[name] = files.remove(part)!;
    log.add('rename $name');
  }

  @override
  Future<void> delete(String location, String name) async {
    _check();
    files.remove(name);
  }

  @override
  Future<String> deviceName() async => device;
}
