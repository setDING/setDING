import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/backup_folder.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import 'auto_backup.dart';
import 'backup.dart';
import 'import_export.dart';
import 'set_archive.dart';
import 'set_providers.dart';
import 'song_archive.dart';
import 'song_providers.dart';
import 'storage_providers.dart';

/// Backup archive of a library (ADR-0043).
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    userId: ref.watch(authProvider.select((u) => u?.id)),
    appVersion: ref.watch(clientVersionProvider) ?? '',
  ),
);

/// The folder of the automatic backup (ADR-0054).
final backupFolderProvider = Provider<BackupFolder>(
  (ref) => createBackupFolder(),
);

/// The setting and state of the automatic backup of the local library
/// (ADR-0054).
final autoBackupProvider =
    NotifierProvider<AutoBackupNotifier, AutoBackupState>(
      AutoBackupNotifier.new,
    );

class AutoBackupNotifier extends Notifier<AutoBackupState> {
  late AutoBackupController controller;

  @override
  AutoBackupState build() {
    controller = AutoBackupController(
      prefs: ref.watch(sharedPreferencesProvider),
      folder: ref.watch(backupFolderProvider),
      backups: () => ref.read(backupServiceProvider),
      onChanged: (s) {
        if (ref.mounted) state = s;
      },
    );
    if (controller.folder.supported) {
      unawaited(controller.loadSystemDeviceName());
      unawaited(controller.describeFolder());
    }
    return controller.state;
  }
}

final setArchiveServiceProvider = Provider<SetArchiveService>(
  (ref) => SetArchiveService(ref.watch(backupServiceProvider)),
);

final songArchiveServiceProvider = Provider<SongArchiveService>(
  (ref) => SongArchiveService(ref.watch(backupServiceProvider)),
);

final importExportProvider = Provider<ImportExportService>(
  (ref) => ImportExportService(
    ref.watch(songRepositoryProvider),
    ref.watch(setRepositoryProvider),
  ),
);
