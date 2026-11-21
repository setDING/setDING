import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_controller.dart';

/// Above the sets: the data on this device may not be up to date, because
/// the last sync is too long ago or local changes did not reach the server
/// (ADR-0001, #744). Nothing when the data is up to date.
class SyncStaleBanner extends ConsumerWidget {
  const SyncStaleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staleness = ref.watch(syncStalenessProvider);
    if (staleness == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final last = staleness.lastSync;
    final lines = [
      if (staleness.stale)
        last == null
            ? l10n.syncStaleNever
            : l10n.syncStale(
                '${localizations.formatShortDate(last)} '
                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(last))}',
              ),
      if (staleness.unsent > 0) l10n.syncUnsent(staleness.unsent),
    ];

    return Card(
      key: const Key('sync-stale-banner'),
      color: colors.errorContainer,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sync_problem_outlined,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lines.join('\n'),
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('sync-stale-now'),
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
                child: Text(l10n.syncNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
