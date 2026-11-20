import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';
import 'song_screen.dart';

/// The songs of an organization's library that no band played (ADR-0046),
/// from the summary of the last sync, for organization admins and
/// librarians: what no band needs any more can go to the trash
/// (ADR-0043).
class LibraryUsageScreen extends ConsumerWidget {
  const LibraryUsageScreen({super.key, required this.library});

  final LibraryView library;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SongEntry song,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSongTitle,
      message: l10n.deleteSongMessage(song.title),
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(songRepositoryProvider);
    final deleted = await repo.deleteSong(song.id);
    showUndo(
      messenger,
      l10n.songDeleted(song.title.isEmpty ? l10n.untitled : song.title),
      undoLabel: l10n.undo,
      onUndo: () => repo.restoreSong(deleted),
      onGone: () => repo.purgeFiles(deleted.attachments),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final usage = ref.watch(libraryUsageProvider(library.id));
    final fetched = ref.watch(orgPlaysFetchedProvider(library.id));
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryUsage)),
      body: AsyncBody(
        value: usage,
        data: (usage) {
          final loaded = fetched.value != null;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (!loaded)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l10n.libraryUsageNotLoaded,
                        key: const Key('library-usage-not-loaded'),
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  else ...[
                    Text(
                      l10n.libraryUsageSummary(
                        usage.unplayed.length,
                        usage.total,
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.libraryUsageHint, style: secondary),
                    Text(
                      l10n.playHistoryFetched(
                        formatGigDate(context, fetched.value!),
                      ),
                      style: secondary,
                    ),
                    const SizedBox(height: 8),
                    if (usage.unplayed.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(l10n.libraryUsageAllPlayed),
                      ),
                    for (final song in usage.unplayed)
                      ListTile(
                        key: ValueKey('library-usage-${song.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          song.title.isEmpty ? l10n.untitled : song.title,
                        ),
                        subtitle: song.artist == null
                            ? null
                            : Text(song.artist!),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SongScreen(songId: song.id),
                          ),
                        ),
                        trailing: IconButton(
                          key: ValueKey('library-usage-delete-${song.id}'),
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, song),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
