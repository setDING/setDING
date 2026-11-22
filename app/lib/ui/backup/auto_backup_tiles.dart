import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/auto_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../settings/settings_layout.dart';
import '../widgets/dialogs.dart';
import 'folder_path_text.dart';
import 'full_backup.dart' show backupReminderProvider;

// The automatic backup of the local library, its own section of *Storage &
// info* (ADR-0054, #891): on or off, the folder, *Back up to the folder now*
// with the last backup or error, how many backups stay, and the device name
// in the file names.

/// [time] as date and time in the app's language.
String formatBackupTime(BuildContext context, DateTime time) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .add_Hm()
        .format(time);

/// What went wrong, for the person.
String autoBackupErrorText(AppLocalizations l10n, AutoBackupError error) =>
    switch (error) {
      AutoBackupError.unavailable => l10n.autoBackupErrorUnavailable,
      AutoBackupError.permission => l10n.autoBackupErrorPermission,
      AutoBackupError.failed => l10n.autoBackupErrorFailed,
    };

/// Lets the person choose the folder and writes the first backup into it.
Future<void> chooseAutoBackupFolder(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final controller = ref.read(autoBackupProvider.notifier).controller;
  if (!await controller.chooseFolder()) return;
  if (!controller.state.enabled) await controller.setEnabled(true);
  if (!context.mounted) return;
  await runAutoBackupNow(context, ref, libraryName: l10n.bandLocal);
}

/// *Back up now*, with a message when it is saved.
Future<void> runAutoBackupNow(
  BuildContext context,
  WidgetRef ref, {
  required String libraryName,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(autoBackupProvider.notifier).controller;
  final saved = await controller.runNow(libraryName: libraryName);
  ref.invalidate(backupReminderProvider);
  final state = controller.state;
  if (saved) {
    showMessageOn(messenger, l10n.autoBackupSaved(state.lastFile ?? ''));
  } else if (state.error case final error?) {
    showMessageOn(
      messenger,
      l10n.autoBackupHintFailed(autoBackupErrorText(l10n, error)),
    );
  }
}

/// The tiles of the automatic backup.
class AutoBackupTiles extends ConsumerWidget {
  const AutoBackupTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(autoBackupProvider);
    final controller = ref.read(autoBackupProvider.notifier).controller;
    final theme = Theme.of(context);
    final status = [
      if (s.lastAt case final at?)
        l10n.autoBackupLast(formatBackupTime(context, at))
      else
        l10n.autoBackupNever,
      if ((s.error, s.errorAt) case (final error?, final at?))
        l10n.autoBackupFailed(
          formatBackupTime(context, at),
          autoBackupErrorText(l10n, error),
        ),
    ];
    return Column(
      children: [
        SettingsSwitch(
          tileKey: const Key('auto-backup'),
          icon: Icons.cloud_sync_outlined,
          title: l10n.autoBackupSwitch,
          value: s.enabled,
          onChanged: (on) async {
            if (on && s.location == null) {
              // A folder first; without one it stays off.
              await chooseAutoBackupFolder(context, ref);
            } else {
              await controller.setEnabled(on);
              ref.invalidate(backupReminderProvider);
            }
          },
        ),
        if (s.enabled) ...[
          ListTile(
            key: const Key('auto-backup-folder'),
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.autoBackupFolder),
            // The storage or app, then the path (#889).
            subtitle: switch (s.folderName) {
              null => Text(l10n.autoBackupFolderNone),
              final path => Column(
                key: const Key('auto-backup-folder-path'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.folderPlace case final place?) Text(place),
                  FolderPathText(path),
                ],
              ),
            },
            trailing: TextButton(
              key: const Key('auto-backup-choose'),
              onPressed: () => chooseAutoBackupFolder(context, ref),
              child: Text(l10n.autoBackupChooseFolder),
            ),
          ),
          ListTile(
            key: const Key('auto-backup-now'),
            leading: s.running
                ? const SizedBox.square(
                    dimension: 24,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    s.error == null
                        ? Icons.drive_folder_upload_outlined
                        : Icons.warning_amber_rounded,
                    color: s.error == null ? null : theme.colorScheme.error,
                  ),
            title: Text(
              s.running ? l10n.autoBackupRunning : l10n.autoBackupNow,
            ),
            subtitle: Text(status.join('\n')),
            enabled: s.active && !s.running,
            onTap: () =>
                runAutoBackupNow(context, ref, libraryName: l10n.bandLocal),
          ),
          ListTile(
            key: const Key('auto-backup-keep'),
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.autoBackupKeep),
            subtitle: Text(l10n.autoBackupKeepHint),
            trailing: DropdownButton<int>(
              key: const Key('auto-backup-keep-value'),
              value: s.keep,
              underline: const SizedBox.shrink(),
              items: [
                for (var n = autoBackupMinKeep; n <= autoBackupMaxKeep; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (n) {
                if (n != null) controller.setKeep(n);
              },
            ),
          ),
          ListTile(
            key: const Key('auto-backup-device'),
            leading: const Icon(Icons.tablet_android_outlined),
            title: Text(l10n.autoBackupDevice),
            subtitle: Text('${s.device}\n${l10n.autoBackupDeviceHint}'),
            onTap: () async {
              final name = await askText(
                context,
                title: l10n.autoBackupDeviceTitle,
                initial: s.device,
                label: l10n.autoBackupDevice,
                allowEmpty: true,
              );
              if (name != null) await controller.setDeviceName(name);
            },
          ),
        ],
      ],
    );
  }
}
