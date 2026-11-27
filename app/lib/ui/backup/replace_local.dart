import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/auto_backup.dart';
import '../../data/import_export.dart' show archiveExtension;
import '../../data/backup.dart';
import '../../data/backup_providers.dart';
import '../../data/database.dart' show localBandId;
import '../../l10n/generated/app_localizations.dart';
import '../widgets/dialogs.dart';
import '../widgets/export_file.dart';
import 'auto_backup_tiles.dart' show formatBackupTime;
import 'full_backup.dart' show backupReminderProvider;

// Restoring by replacing the local library (ADR-0054 section 2): a preview
// of what is replaced, a safety backup of the current library first (into
// the automatic backup folder when there is one, otherwise where the person
// chooses; it can be skipped), then the archive's records with their IDs.

/// The file name of the safety backup: like an automatic backup, but never
/// counted (and deleted) as one.
String safetyBackupFileName(String device, DateTime time) {
  final name = autoBackupFileName(device, time);
  return '${name.substring(0, name.length - archiveExtension.length)}'
      ' before restore$archiveExtension';
}

/// Shows the preview of replacing the local library by [contents] and, once
/// confirmed, saves the safety backup unless the person skipped it. True
/// when the library may be replaced now.
Future<bool> confirmLocalReplace(
  BuildContext context,
  BackupContents contents,
) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  final now = await ref.read(backupServiceProvider).localCounts();
  if (!context.mounted) return false;
  final safety = await showDialog<bool>(
    context: context,
    builder: (_) => _ReplaceDialog(contents: contents, now: now),
  );
  if (safety == null || !context.mounted) return false;
  if (!safety) return true;
  return _saveSafetyBackup(context, ref);
}

/// Saves the current local library before it is replaced; false when it
/// was not saved (cancelled or failed), then nothing is replaced.
Future<bool> _saveSafetyBackup(
  BuildContext context,
  ProviderContainer ref,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final auto = ref.read(autoBackupProvider);
  final folder = ref.read(backupFolderProvider);
  try {
    final time = DateTime.now();
    final bytes = await ref
        .read(backupServiceProvider)
        .export(
          localBandId,
          libraryName: l10n.bandLocal,
          now: time,
          device: auto.device,
        );
    final name = safetyBackupFileName(auto.device, time);
    if (auto.active) {
      await folder.write(auto.location!, name, bytes);
      return true;
    }
    return await ref.read(saveFileProvider)(
      name,
      bytes,
      mimeType: 'application/zip',
    );
  } catch (e) {
    showMessageOn(messenger, l10n.backupReplaceSafetyFailed('$e'));
    return false;
  }
}

/// Replaces the local library by [contents] after [confirmLocalReplace],
/// with a progress dialog and a message; null when it did not happen.
Future<BackupImportResult?> replaceLocalLibrary(
  BuildContext context,
  BackupContents contents,
) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  if (!await confirmLocalReplace(context, contents)) return null;
  if (!context.mounted) return null;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // The dialog is on the root navigator, above the tabs' own (ADR-0065).
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('backup-replace-progress'),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.backupReplaceRunning)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final result = await ref.read(backupServiceProvider).replaceLocal(contents);
    ref.invalidate(backupReminderProvider);
    showMessageOn(
      messenger,
      l10n.backupReplaceDone(result.imported, result.sets),
    );
    return result;
  } catch (e) {
    showMessageOn(messenger, l10n.errorGeneric('$e'));
    return null;
  } finally {
    navigator.pop();
  }
}

/// The preview: the backup, what is replaced, the safety backup. Pops with
/// whether to save the safety backup, or null when cancelled.
class _ReplaceDialog extends ConsumerStatefulWidget {
  const _ReplaceDialog({required this.contents, required this.now});

  final BackupContents contents;
  final ({int songs, int sets}) now;

  @override
  ConsumerState<_ReplaceDialog> createState() => _ReplaceDialogState();
}

class _ReplaceDialogState extends ConsumerState<_ReplaceDialog> {
  bool _safety = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final contents = widget.contents;
    final auto = ref.watch(autoBackupProvider);
    final created = contents.createdAt;
    final date = created == null ? '' : formatBackupTime(context, created);
    final songs = contents.songs.length, sets = contents.sets.length;
    return AlertDialog(
      key: const Key('backup-replace'),
      title: Text(l10n.backupReplaceTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contents.device != null
                    ? l10n.backupReplaceFromDevice(
                        contents.device!,
                        date,
                        songs,
                        sets,
                      )
                    : l10n.backupReplaceFrom(date, songs, sets),
              ),
              const SizedBox(height: 12),
              Text(l10n.backupReplaceNow(widget.now.songs, widget.now.sets)),
              const SizedBox(height: 8),
              Text(l10n.backupReplaceKeeps, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('backup-replace-safety'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _safety,
                onChanged: (v) => setState(() => _safety = v ?? false),
                title: Text(l10n.backupReplaceSafety),
                subtitle: Text(
                  _safety
                      ? auto.active
                            ? l10n.backupReplaceSafetyFolder(
                                auto.folderLabel ?? '',
                              )
                            : l10n.backupReplaceSafetyChoose
                      : l10n.backupReplaceSafetySkip,
                  style: _safety
                      ? null
                      : TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('backup-replace-start'),
          style: destructiveButtonStyle(context),
          onPressed: () => Navigator.pop(context, _safety),
          child: Text(l10n.backupReplaceAction),
        ),
      ],
    );
  }
}
