import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_backend.dart';
import '../../sync/sync_controller.dart';
import 'sign_in_screen.dart';

/// Sync state in the settings: last sync, pending changes, conflicts, and
/// "Sync now".
class SyncTile extends ConsumerWidget {
  const SyncTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final conflicts = ref.watch(conflictsProvider).value?.length ?? 0;
    final missing = ref.watch(missingFilesProvider).value ?? 0;
    final error = status.lastReport?.error;
    final last = status.lastSync;
    final localizations = MaterialLocalizations.of(context);

    final lines = [
      if (status.running)
        l10n.syncRunning
      else if (last != null)
        l10n.syncLast(
          '${localizations.formatShortDate(last)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(last))}',
        )
      else
        l10n.syncNever,
      l10n.syncPending(pending),
      if (error == BackendErrorKind.network)
        l10n.syncOffline
      else if (error != null)
        backendErrorText(l10n, error),
      if (missing > 0) l10n.syncMissingFiles(missing),
      if (conflicts > 0) l10n.syncConflicts(conflicts),
    ];

    return ListTile(
      key: const Key('sync-tile'),
      leading: Icon(
        conflicts > 0
            ? Icons.sync_problem
            : (error != null
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_done_outlined),
      ),
      title: Text(l10n.syncTitle),
      subtitle: Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: IconButton(
        key: const Key('sync-now'),
        tooltip: l10n.syncNow,
        icon: status.running
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        onPressed: status.running
            ? null
            : () => ref.read(syncControllerProvider.notifier).syncNow(),
      ),
    );
  }
}
