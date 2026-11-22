import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/backup_folder.dart';
import 'backup.dart';
import 'database.dart' show localBandId;
import 'import_export.dart' show safeFileName;

// Automatic backup of the local library (ADR-0054 section 1): the backup
// archive of the local library (ADR-0043, format version 1) into a folder
// the person chose, at most once a day and only after changes; the newest
// backups of this device are kept. A device setting, kept in the shared
// preferences and not in the settings: a folder of one device means nothing
// on another one, so it is not in a full backup either.

/// The fewest and most automatic backups of this device kept in the folder.
const autoBackupMinKeep = 1, autoBackupMaxKeep = 10;

/// What went wrong at the last automatic backup.
enum AutoBackupError {
  /// The folder is not reachable.
  unavailable,

  /// The permission to the folder was lost.
  permission,

  /// Writing failed otherwise (e.g. the storage is full).
  failed,
}

/// The setting and the state of the automatic backup.
@immutable
class AutoBackupState {
  const AutoBackupState({
    this.enabled = false,
    this.location,
    this.folderName,
    this.deviceName,
    this.systemDeviceName = '',
    this.keep = autoBackupMaxKeep,
    this.lastAt,
    this.lastFile,
    this.error,
    this.errorAt,
    this.running = false,
  });

  final bool enabled;

  /// What the platform needs to reach the folder; null when none is chosen.
  final String? location;

  /// The name of the folder as the person sees it.
  final String? folderName;

  /// The device name the person entered; null: [systemDeviceName].
  final String? deviceName;

  /// The operating system's name of this device.
  final String systemDeviceName;

  /// How many automatic backups of this device stay in the folder.
  final int keep;

  /// The last successful automatic backup and its file.
  final DateTime? lastAt;
  final String? lastFile;

  /// The error of the last attempt, null after a success.
  final AutoBackupError? error;
  final DateTime? errorAt;

  /// A backup is being written.
  final bool running;

  /// The device name in the file names.
  String get device {
    final name = deviceName ?? systemDeviceName;
    return name.trim().isEmpty ? 'setDING' : safeFileName(name);
  }

  /// On and with a folder: backups are written.
  bool get active => enabled && location != null;

  AutoBackupState copyWith({
    bool? enabled,
    String? Function()? location,
    String? Function()? folderName,
    String? Function()? deviceName,
    String? systemDeviceName,
    int? keep,
    DateTime? Function()? lastAt,
    String? Function()? lastFile,
    AutoBackupError? Function()? error,
    DateTime? Function()? errorAt,
    bool? running,
  }) => AutoBackupState(
    enabled: enabled ?? this.enabled,
    location: location == null ? this.location : location(),
    folderName: folderName == null ? this.folderName : folderName(),
    deviceName: deviceName == null ? this.deviceName : deviceName(),
    systemDeviceName: systemDeviceName ?? this.systemDeviceName,
    keep: keep ?? this.keep,
    lastAt: lastAt == null ? this.lastAt : lastAt(),
    lastFile: lastFile == null ? this.lastFile : lastFile(),
    error: error == null ? this.error : error(),
    errorAt: errorAt == null ? this.errorAt : errorAt(),
    running: running ?? this.running,
  );
}

/// The file name of an automatic backup of [device] at [time]:
/// `setDING-Backup <device> <yyyy-mm-dd HHmm>.zip`.
String autoBackupFileName(String device, DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}${two(time.minute)}';
  return '${safeFileName('setDING-Backup $device')} $stamp.zip';
}

/// The automatic backups of [device] among [names], newest first. Files of
/// other devices and other files are not in it.
List<String> autoBackupsOf(String device, Iterable<String> names) {
  final pattern = RegExp(
    '^${RegExp.escape(safeFileName('setDING-Backup $device'))} '
    r'\d{4}-\d{2}-\d{2} \d{4}\.zip$',
  );
  return [
    for (final n in names)
      if (pattern.hasMatch(n)) n,
  ]..sort((a, b) => b.compareTo(a));
}

/// Whether an automatic backup is due: never one before, or the last one on
/// an earlier day (at most once a day).
bool autoBackupDayDue(DateTime? last, DateTime now) =>
    last == null ||
    DateTime(
      now.year,
      now.month,
      now.day,
    ).isAfter(DateTime(last.year, last.month, last.day));

/// Writes the automatic backups and keeps their setting.
class AutoBackupController {
  AutoBackupController({
    required this.prefs,
    required this.folder,
    required this.backups,
    required this.onChanged,
    this.now = DateTime.now,
  }) {
    _state = _load();
  }

  final SharedPreferences prefs;
  final BackupFolder folder;

  /// The backup service of the moment (it depends on the signed-in user).
  final BackupService Function() backups;

  /// Called with every new state.
  final void Function(AutoBackupState state) onChanged;
  final DateTime Function() now;

  late AutoBackupState _state;
  AutoBackupState get state => _state;

  /// The keys in the shared preferences.
  static const enabledKey = 'autoBackupEnabled',
      locationKey = 'autoBackupLocation',
      folderNameKey = 'autoBackupFolderName',
      deviceKey = 'autoBackupDevice',
      keepKey = 'autoBackupKeep',
      lastAtKey = 'autoBackupAt',
      lastFileKey = 'autoBackupFile',
      fingerprintKey = 'autoBackupFingerprint',
      errorKey = 'autoBackupError',
      errorAtKey = 'autoBackupErrorAt',
      hintAtKey = 'autoBackupHintAt';

  AutoBackupState _load() {
    DateTime? date(String key) => DateTime.tryParse(prefs.getString(key) ?? '');
    final error = prefs.getString(errorKey);
    return AutoBackupState(
      enabled: prefs.getBool(enabledKey) ?? false,
      location: prefs.getString(locationKey),
      folderName: prefs.getString(folderNameKey),
      deviceName: prefs.getString(deviceKey),
      keep: (prefs.getInt(keepKey) ?? autoBackupMaxKeep).clamp(
        autoBackupMinKeep,
        autoBackupMaxKeep,
      ),
      lastAt: date(lastAtKey),
      lastFile: prefs.getString(lastFileKey),
      error: AutoBackupError.values.where((e) => e.name == error).firstOrNull,
      errorAt: date(errorAtKey),
    );
  }

  void _set(AutoBackupState state) {
    _state = state;
    onChanged(state);
  }

  Future<void> _put(String key, Object? value) => switch (value) {
    null => prefs.remove(key),
    final bool v => prefs.setBool(key, v),
    final int v => prefs.setInt(key, v),
    final DateTime v => prefs.setString(key, v.toIso8601String()),
    _ => prefs.setString(key, '$value'),
  };

  /// Reads the operating system's device name once.
  Future<void> loadSystemDeviceName() async {
    if (_state.systemDeviceName.isNotEmpty) return;
    final name = await folder.deviceName();
    _set(_state.copyWith(systemDeviceName: name));
  }

  /// Lets the person choose the folder; true when one was chosen. The error
  /// of the last attempt goes away with it.
  Future<bool> chooseFolder() async {
    final choice = await folder.pick();
    if (choice == null) return false;
    await _put(locationKey, choice.location);
    await _put(folderNameKey, choice.name);
    await _put(errorKey, null);
    await _put(errorAtKey, null);
    // A new folder gets a backup, also when nothing changed.
    await _put(fingerprintKey, null);
    _set(
      _state.copyWith(
        location: () => choice.location,
        folderName: () => choice.name,
        error: () => null,
        errorAt: () => null,
      ),
    );
    return true;
  }

  Future<void> setEnabled(bool enabled) async {
    await _put(enabledKey, enabled);
    if (!enabled) {
      await _put(errorKey, null);
      await _put(errorAtKey, null);
    }
    _set(
      _state.copyWith(
        enabled: enabled,
        error: enabled ? null : () => null,
        errorAt: enabled ? null : () => null,
      ),
    );
  }

  /// [name] empty: the operating system's device name again.
  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    final value = trimmed.isEmpty || trimmed == _state.systemDeviceName
        ? null
        : trimmed;
    await _put(deviceKey, value);
    _set(_state.copyWith(deviceName: () => value));
  }

  Future<void> setKeep(int keep) async {
    final value = keep.clamp(autoBackupMinKeep, autoBackupMaxKeep);
    await _put(keepKey, value);
    _set(_state.copyWith(keep: value));
  }

  /// Writes a backup when one is due: on, a folder, not today yet, and the
  /// local library changed since the last one. Returns whether it wrote one.
  Future<bool> runIfDue({required String libraryName}) async {
    if (!_state.active || _state.running) return false;
    if (!autoBackupDayDue(_state.lastAt, now())) return false;
    return _run(libraryName: libraryName, force: false);
  }

  /// *Back up now*: writes a backup at once, also when nothing changed.
  Future<bool> runNow({required String libraryName}) async {
    if (!_state.active || _state.running) return false;
    return _run(libraryName: libraryName, force: true);
  }

  Future<bool> _run({required String libraryName, required bool force}) async {
    final location = _state.location!;
    _set(_state.copyWith(running: true));
    try {
      final service = backups();
      final fingerprint = await service.fingerprint(localBandId);
      if (!force && fingerprint == prefs.getString(fingerprintKey)) {
        _set(_state.copyWith(running: false));
        return false;
      }
      final time = now();
      final bytes = await service.export(
        localBandId,
        libraryName: libraryName,
        now: time,
        device: _state.device,
      );
      final device = _state.device;
      final name = autoBackupFileName(device, time);
      await folder.write(location, name, bytes);
      // The newest backups of this device stay; its leftovers of an
      // interrupted write go too. Other files are never touched.
      final files = await folder.list(location);
      final own = autoBackupsOf(device, files);
      final remove = [
        ...own.skip(_state.keep),
        for (final f in files)
          if (f.endsWith(backupPartSuffix) &&
              autoBackupsOf(device, [
                f.substring(0, f.length - backupPartSuffix.length),
              ]).isNotEmpty)
            f,
      ];
      for (final f in remove) {
        if (f != name) await folder.delete(location, f);
      }
      await _put(lastAtKey, time);
      await _put(lastFileKey, name);
      await _put(fingerprintKey, fingerprint);
      await _put(errorKey, null);
      await _put(errorAtKey, null);
      // An automatic backup counts as the last backup of the local library
      // (the reminder of ADR-0043).
      await _put(lastBackupKey, time);
      _set(
        _state.copyWith(
          running: false,
          lastAt: () => time,
          lastFile: () => name,
          error: () => null,
          errorAt: () => null,
        ),
      );
      return true;
    } catch (e) {
      final error = switch (e) {
        BackupFolderException(error: BackupFolderError.permission) =>
          AutoBackupError.permission,
        BackupFolderException(error: BackupFolderError.unavailable) =>
          AutoBackupError.unavailable,
        _ => AutoBackupError.failed,
      };
      final time = now();
      await _put(errorKey, error.name);
      await _put(errorAtKey, time);
      _set(
        _state.copyWith(
          running: false,
          error: () => error,
          errorAt: () => time,
        ),
      );
      return false;
    }
  }

  /// Whether the hint about a failed automatic backup may be shown now (at
  /// most once a day); marks it shown.
  bool takeErrorHint() {
    if (!_state.enabled || _state.error == null) return false;
    final shown = DateTime.tryParse(prefs.getString(hintAtKey) ?? '');
    if (!autoBackupDayDue(shown, now())) return false;
    unawaited(_put(hintAtKey, now()));
    return true;
  }
}

/// When this device last saved a backup of the local library (ISO 8601);
/// manual, full or automatic.
const lastBackupKey = 'lastBackupAt';
