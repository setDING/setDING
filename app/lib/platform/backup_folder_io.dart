import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'backup_folder.dart';

/// The platform's backup folder: the native channel on Android and iOS,
/// plain files on the desktop.
BackupFolder createBackupFolder() => Platform.isAndroid || Platform.isIOS
    ? ChannelBackupFolder()
    : DirectoryBackupFolder(
        pickDirectory: () async =>
            (await FilePicker.pickDirectory())?.toFilePath(),
        // On Windows a path starts with the drive, never with "~".
        home: Platform.isWindows ? null : Platform.environment['HOME'],
      );

/// [path] as the person sees it (#889): in the home folder [home] with
/// "~" in front instead of the home folder, otherwise unchanged.
String desktopFolderPath(String path, {String? home}) {
  if (home == null || home.isEmpty) return path;
  final base = p.normalize(home);
  if (p.equals(base, path)) return '~';
  if (!p.isWithin(base, path)) return path;
  return p.join('~', p.relative(path, from: base));
}

/// A folder on a desktop: a path, e.g. one that the OneDrive, Dropbox or
/// Nextcloud client syncs.
class DirectoryBackupFolder implements BackupFolder {
  DirectoryBackupFolder({
    required this.pickDirectory,
    this.hostName,
    this.home,
  });

  final Future<String?> Function() pickDirectory;

  /// The home folder, shown as "~" in the path of the folder.
  final String? home;

  /// The device name; default: the host name.
  final String? hostName;

  @override
  bool get supported => true;

  @override
  Future<BackupFolderChoice?> pick() async {
    final path = await pickDirectory();
    if (path == null) return null;
    return describe(path);
  }

  @override
  Future<BackupFolderChoice> describe(String location) async => (
    location: location,
    name: desktopFolderPath(location, home: home),
    place: null,
  );

  Directory _dir(String location) {
    final dir = Directory(location);
    if (!dir.existsSync()) {
      throw BackupFolderException(BackupFolderError.unavailable, location);
    }
    return dir;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on BackupFolderException {
      rethrow;
    } on FileSystemException catch (e) {
      // EACCES / EPERM: no permission to the folder.
      final code = e.osError?.errorCode;
      throw BackupFolderException(
        code == 13 || code == 1 || code == 5
            ? BackupFolderError.permission
            : BackupFolderError.failed,
        e.message,
      );
    }
  }

  @override
  Future<List<String>> list(String location) => _guard(() async {
    return [
      for (final e in _dir(location).listSync())
        if (e is File) p.basename(e.path),
    ];
  });

  @override
  Future<void> write(String location, String name, Uint8List bytes) =>
      _guard(() async {
        final dir = _dir(location);
        final part = File(p.join(dir.path, '$name$backupPartSuffix'));
        await part.writeAsBytes(bytes, flush: true);
        await part.rename(p.join(dir.path, name));
      });

  @override
  Future<void> delete(String location, String name) => _guard(() async {
    final file = File(p.join(_dir(location).path, name));
    if (file.existsSync()) await file.delete();
  });

  @override
  Future<String> deviceName() async => hostName ?? Platform.localHostname;
}

/// The folder through the native code of the app (`MainActivity` on
/// Android, `AppDelegate` on iOS): a document provider's tree URI with a
/// persisted permission, or a security-scoped bookmark.
class ChannelBackupFolder implements BackupFolder {
  ChannelBackupFolder([
    this._channel = const MethodChannel('app.setding/backup_folder'),
  ]);

  final MethodChannel _channel;

  @override
  bool get supported => true;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw BackupFolderException(switch (e.code) {
        'permission' => BackupFolderError.permission,
        'unavailable' => BackupFolderError.unavailable,
        _ => BackupFolderError.failed,
      }, e.message);
    }
  }

  @override
  Future<BackupFolderChoice?> pick() async {
    final result = await _call<Map<Object?, Object?>>('pick');
    if (result == null) return null;
    return _choice(result['location'] as String, result);
  }

  static BackupFolderChoice _choice(
    String location,
    Map<Object?, Object?> result,
  ) => (
    location: location,
    name: result['name'] as String? ?? '',
    place: switch (result['place']) {
      final String place when place.trim().isNotEmpty => place.trim(),
      _ => null,
    },
  );

  @override
  Future<BackupFolderChoice?> describe(String location) async {
    try {
      final result = await _call<Map<Object?, Object?>>('describe', {
        'location': location,
      });
      return result == null ? null : _choice(location, result);
    } on BackupFolderException {
      return null;
    } on MissingPluginException {
      // iOS does not describe its folders.
      return null;
    }
  }

  @override
  Future<List<String>> list(String location) async => [
    ...?(await _call<List<Object?>>('list', {
      'location': location,
    }))?.cast<String>(),
  ];

  /// Writes under the temporary name first. A folder that rejects that
  /// name (a Nextcloud server forbids ".part" files, #1106) gets the file
  /// written directly under [name]; a lost permission is not retried.
  @override
  Future<void> write(String location, String name, Uint8List bytes) async {
    final args = {'location': location, 'name': name, 'bytes': bytes};
    try {
      await _call<void>('write', {...args, 'part': '$name$backupPartSuffix'});
    } on BackupFolderException catch (e) {
      if (e.error == BackupFolderError.permission) rethrow;
      await _call<void>('write', args);
    }
  }

  @override
  Future<void> delete(String location, String name) =>
      _call<void>('delete', {'location': location, 'name': name});

  @override
  Future<String> deviceName() async {
    try {
      return await _call<String>('deviceName') ?? '';
    } on BackupFolderException {
      return '';
    }
  }
}
