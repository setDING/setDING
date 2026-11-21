import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trash.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';
import '../widgets/page_width.dart';

/// What a trash shows.
enum TrashKind { songs, sets }

/// Deleted songs of a library or sets of a band that can still be restored
/// (ADR-0043): deleted less than 30 days ago, most recent first.
class TrashScreen extends ConsumerWidget {
  const TrashScreen.songs({super.key, required String libraryId})
    : kind = TrashKind.songs,
      id = libraryId;

  const TrashScreen.sets({super.key, required String bandId})
    : kind = TrashKind.sets,
      id = bandId;

  final TrashKind kind;

  /// The library ([TrashKind.songs]) or band ([TrashKind.sets]).
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(trashRepositoryProvider);
    final AsyncValue<List<_TrashEntry>> entries = switch (kind) {
      TrashKind.songs =>
        ref
            .watch(trashedSongsProvider(id))
            .whenData(
              (songs) => [
                for (final s in songs)
                  _TrashEntry(
                    s.id,
                    s.title,
                    s.artist,
                    s.deletedAt!,
                    () => repo.restoreSong(s.id),
                  ),
              ],
            ),
      TrashKind.sets =>
        ref
            .watch(trashedSetsProvider(id))
            .whenData(
              (sets) => [
                for (final s in sets)
                  _TrashEntry(
                    s.id,
                    s.name,
                    s.gigDate == null
                        ? null
                        : formatGigDate(context, s.gigDate!),
                    s.deletedAt!,
                    () => repo.restoreSet(s.id),
                  ),
              ],
            ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          kind == TrashKind.songs ? l10n.trashSongsTitle : l10n.trashSetsTitle,
        ),
      ),
      body: AsyncBody(
        value: entries,
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.delete_outline,
                message: l10n.trashEmpty(trashRetention.inDays),
              )
            : PageWidth(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.trashHint(trashRetention.inDays),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    for (final e in list) _TrashTile(entry: e),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TrashEntry {
  const _TrashEntry(
    this.id,
    this.title,
    this.detail,
    this.deletedAt,
    this.restore,
  );

  final String id;
  final String title;
  final String? detail;
  final DateTime deletedAt;
  final Future<void> Function() restore;
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({required this.entry});

  final _TrashEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final until = TrashRepository.restorableUntil(entry.deletedAt);
    // Started days count: deleted just now is "30 days left".
    final left = until.difference(DateTime.now());
    final daysLeft = left.isNegative ? 0 : (left.inMinutes / (24 * 60)).ceil();
    return ListTile(
      key: ValueKey('trash-${entry.id}'),
      title: Text(entry.title),
      subtitle: Text(
        [
          ?entry.detail,
          l10n.trashDeletedOn(formatGigDate(context, entry.deletedAt)),
          l10n.trashDaysLeft(daysLeft),
        ].join(' · '),
      ),
      trailing: TextButton(
        key: ValueKey('trash-restore-${entry.id}'),
        onPressed: () async {
          await entry.restore();
          if (context.mounted) {
            showMessage(context, l10n.trashRestored(entry.title));
          }
        },
        child: Text(l10n.trashRestore),
      ),
    );
  }
}
