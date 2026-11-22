import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart' show sharedPreferencesProvider;
import '../widgets/dialogs.dart';
import 'language_versions.dart';

/// Songs whose offer to copy adjustments was dismissed on this device
/// (ADR-0053): a device setting, never synced; the offer does not come back
/// for them.
class AdjustmentOfferDismissedNotifier extends Notifier<Set<String>> {
  static const key = 'adjustmentOfferDismissed';

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(key) ?? const [])
          .toSet();

  Future<void> dismiss(String songId) async {
    state = {...state, songId};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(key, state.toList()..sort());
  }
}

final adjustmentOfferDismissedProvider =
    NotifierProvider<AdjustmentOfferDismissedNotifier, Set<String>>(
      AdjustmentOfferDismissedNotifier.new,
    );

/// The other language versions of a song with musical adjustments of the
/// current person (ADR-0053).
final adjustmentSourcesProvider = FutureProvider.autoDispose
    .family<List<(SongEntry, SongOverlay)>, String>((ref, songId) {
      // Again when the versions change.
      ref.watch(languageVersionsProvider(songId));
      return ref.watch(songRepositoryProvider).musicalAdjustmentSources(songId);
    });

/// What musical adjustments [overlay] has, e.g. "key, capo".
String musicalAdjustmentNames(AppLocalizations l10n, SongOverlay overlay) => [
  if (overlay.transpose != 0) l10n.adjustmentKindTranspose,
  if (overlay.capoFret != null) l10n.adjustmentKindCapo,
  if (!(overlay.midiPrograms?.isEmpty ?? overlay.midi == null))
    l10n.adjustmentKindMidi,
  if (overlay.clickGrouping != null || overlay.clickSubdivision != null)
    l10n.adjustmentKindClick,
].join(', ');

/// Offers to copy the musical adjustments of another language version to
/// [song] (ADR-0053), shown while [overlay] (the person's adjustments of
/// [song]) has none, another version has some and the offer was not
/// dismissed on this device. Nothing is copied without a tap.
class AdjustmentOfferBanner extends ConsumerWidget {
  const AdjustmentOfferBanner({
    super.key,
    required this.song,
    required this.overlay,
  });

  final SongEntry song;
  final SongOverlay overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (SongRepository.hasMusicalAdjustments(overlay)) {
      return const SizedBox.shrink();
    }
    if (ref.watch(adjustmentOfferDismissedProvider).contains(song.id)) {
      return const SizedBox.shrink();
    }
    final sources =
        ref.watch(adjustmentSourcesProvider(song.id)).value ?? const [];
    if (sources.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final versions = [song, for (final (v, _) in sources) v];
    String name(SongEntry v) => languageVersionLabel(l10n, v, versions);
    final message = sources.length == 1
        ? l10n.adjustmentOfferOne(
            name(sources.single.$1),
            musicalAdjustmentNames(l10n, sources.single.$2),
          )
        : l10n.adjustmentOfferMany;

    Future<void> copy() async {
      final messenger = ScaffoldMessenger.of(context);
      final source = sources.length == 1
          ? sources.single.$1
          : await showDialog<SongEntry>(
              context: context,
              builder: (context) => SimpleDialog(
                title: Text(l10n.adjustmentOfferPick),
                children: [
                  for (final (v, o) in sources)
                    SimpleDialogOption(
                      key: ValueKey('adjustment-source-${v.id}'),
                      onPressed: () => Navigator.pop(context, v),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name(v)),
                          Text(
                            musicalAdjustmentNames(l10n, o),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
      if (source == null) return;
      final repo = ref.read(songRepositoryProvider);
      final before = await repo.copyMusicalAdjustments(
        from: source.id,
        to: song.id,
      );
      showUndo(
        messenger,
        l10n.adjustmentsCopied(name(source)),
        undoLabel: l10n.undo,
        onUndo: () => repo.saveOverlay(before),
      );
    }

    return Card(
      key: const Key('adjustment-offer'),
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('adjustment-offer-copy'),
                  onPressed: copy,
                  child: Text(l10n.adjustmentOfferCopy),
                ),
                TextButton(
                  key: const Key('adjustment-offer-dismiss'),
                  onPressed: () => ref
                      .read(adjustmentOfferDismissedProvider.notifier)
                      .dismiss(song.id),
                  child: Text(l10n.adjustmentOfferDismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
