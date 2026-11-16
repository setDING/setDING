import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_controller.dart';
import '../widgets/dialogs.dart';

/// Shown on a song changed here and on the server (ADR-0004): the user
/// keeps their version, takes the server version, or keeps both.
class ConflictBanner extends ConsumerWidget {
  const ConflictBanner({super.key, required this.conflict});

  final SongConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final engine = ref.read(syncEngineProvider);
    final theme = Theme.of(context);

    Future<void> resolve(Future<void> Function() action) async {
      await action();
      // Pushes the decision; the banner does not wait for it.
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }

    return Card(
      key: const Key('conflict-banner'),
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_problem,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    conflict.deleted
                        ? l10n.conflictBannerDeleted
                        : l10n.conflictBanner,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!conflict.deleted)
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.conflictServerVersion),
                        content: SizedBox(
                          width: 560,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              conflict.chordproSource,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l10n.close),
                          ),
                        ],
                      ),
                    ),
                    child: Text(l10n.conflictCompare),
                  ),
                OutlinedButton(
                  key: const Key('conflict-keep-mine'),
                  onPressed: () =>
                      resolve(() => engine.keepLocal(conflict.songId)),
                  child: Text(l10n.conflictKeepMine),
                ),
                OutlinedButton(
                  key: const Key('conflict-take-server'),
                  onPressed: () =>
                      resolve(() => engine.takeServer(conflict.songId)),
                  child: Text(l10n.conflictTakeServer),
                ),
                if (!conflict.deleted)
                  OutlinedButton(
                    key: const Key('conflict-keep-both'),
                    onPressed: () => resolve(() async {
                      await engine.keepBoth(conflict.songId);
                      if (context.mounted) {
                        showMessage(context, l10n.conflictKeptBoth);
                      }
                    }),
                    child: Text(l10n.conflictKeepBoth),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
