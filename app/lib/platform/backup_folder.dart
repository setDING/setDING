/// Writing backups into a folder the person chose (ADR-0054): a folder of a
/// document provider on Android (Storage Access Framework), a folder of the
/// Files app on iOS (security-scoped bookmark), any folder on the desktop.
library;

import 'dart:typed_data';

export 'backup_folder_io.dart'
    if (dart.library.js_interop) 'backup_folder_web.dart';

/// A folder chosen with the operating system's folder picker: [location]
/// is what the platform needs to reach it again (a path, a tree URI or a
/// bookmark), [name] what the person sees.
typedef BackupFolderChoice = ({String location, String name});

/// Why a folder could not be used.
enum BackupFolderError {
  /// The folder is gone or not reachable (e.g. the provider is offline).
  unavailable,

  /// The permission to the folder was lost; it has to be chosen again.
  permission,

  /// Another error, e.g. the storage is full.
  failed,
}

class BackupFolderException implements Exception {
  const BackupFolderException(this.error, [this.detail]);

  final BackupFolderError error;
  final String? detail;

  @override
  String toString() => 'BackupFolderException($error, $detail)';
}

/// Access to a backup folder. Every method except [pick] and [deviceName]
/// throws a [BackupFolderException] when the folder cannot be used.
abstract class BackupFolder {
  /// Whether this platform can write automatic backups (not the web client).
  bool get supported;

  /// Lets the person choose a folder; null when cancelled.
  Future<BackupFolderChoice?> pick();

  /// The names of the files directly in the folder.
  Future<List<String>> list(String location);

  /// Writes [bytes] as [name] into the folder: under a temporary name first,
  /// renamed when complete, so a sync client never uploads half a file. An
  /// existing file [name] is replaced.
  Future<void> write(String location, String name, Uint8List bytes);

  /// Deletes the file [name] in the folder, if it is there.
  Future<void> delete(String location, String name);

  /// The operating system's name of this device.
  Future<String> deviceName();
}

/// The suffix of a file while it is written.
const backupPartSuffix = '.part';
