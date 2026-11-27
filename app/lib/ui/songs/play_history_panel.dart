import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/arrangement_providers.dart';
import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/play_history.dart';
import '../../data/play_history_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/scope_info.dart';
import '../widgets/side_panel.dart';
import 'band_arrangement_panel.dart' show ArrangementBandChoice;

/// How often and how [band] played [song] (ADR-0046), in a side panel of the
/// song screen: the plays in total and in the last 12 months, the last play
/// and the latest plays with date, set, key, tempo and sequence. A key other
/// than the band's key today is highlighted.
class PlayHistoryPanel extends ConsumerStatefulWidget {
  const PlayHistoryPanel({
    super.key,
    required this.band,
    required this.song,
    required this.parsed,
  });

  final BandView band;
  final SongEntry song;
  final cp.Song parsed;

  /// Plays shown before *Show all*.
  static const latest = 5;

  @override
  ConsumerState<PlayHistoryPanel> createState() => _PlayHistoryPanelState();
}

class _PlayHistoryPanelState extends ConsumerState<PlayHistoryPanel> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final key = (band: widget.band.id, song: widget.song.id);
    final plays = ref.watch(songPlaysProvider(key)).value ?? SongPlays.empty;
    final arrangement = ref.watch(arrangementProvider(key)).value;
    final bandKey = widget.parsed.key?.transpose(arrangement?.transpose ?? 0);
    final shown = _all
        ? plays.plays
        : plays.plays.take(PlayHistoryPanel.latest).toList();
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    bool differs(SongPlay p) {
      final played = p.values.parsedKey;
      return played != null && bandKey != null && played != bandKey;
    }

    return SidePanel(
      key: const Key('play-history'),
      icon: Icons.history,
      title: widget.band.isLocal
          ? l10n.playHistory
          : l10n.playHistoryOf(widget.band.name),
      scope: SettingScope.band,
      children: [
        ArrangementBandChoice(band: widget.band, song: widget.song),
        if (plays.total == 0)
          Text(
            l10n.playHistoryNone(widget.band.name),
            key: const Key('play-history-none'),
            style: theme.textTheme.bodyMedium,
          )
        else ...[
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Figure('${plays.total}', l10n.playHistoryTotal),
              _Figure('${plays.lastYear}', l10n.playHistoryLastYear),
              _Figure(
                formatGigDate(context, plays.last!.date),
                l10n.playHistoryLast,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final play in shown)
            _PlayTile(play: play, notation: notation, highlight: differs(play)),
          if (shown.length < plays.total)
            TextButton(
              key: const Key('play-history-all'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: AlignmentDirectional.centerStart,
              ),
              onPressed: () => setState(() => _all = true),
              child: Text(l10n.playHistoryShowAll(plays.total)),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.playHistoryFirst(formatGigDate(context, plays.first!.date)),
            style: secondary,
          ),
          if (bandKey != null && shown.any(differs))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.playHistoryDiffers(bandKey.format(notation)),
                style: secondary,
              ),
            ),
          if (shown.any((p) => p.approximate))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.playHistoryApproximate, style: secondary),
            ),
        ],
        // The other bands of the organization (ADR-0046), as the server
        // summed them up at the last sync.
        if (!widget.band.isLocal)
          _OtherBands(band: widget.band, song: widget.song),
      ],
    );
  }
}

/// How the other bands of the organization played the song: band, last
/// date, key and how often; never their sets.
class _OtherBands extends ConsumerWidget {
  const _OtherBands({required this.band, required this.song});

  final BandView band;
  final SongEntry song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final others =
        ref
            .watch(otherBandPlaysProvider((song: song.id, exceptBand: band.id)))
            .value ??
        const <OrgPlay>[];
    if (others.isEmpty) return const SizedBox.shrink();
    final fetched = ref.watch(orgPlaysFetchedProvider(song.libraryId)).value;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: const Key('play-history-other-bands'),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.playHistoryOtherBands, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(p.bandName, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    formatGigDate(context, p.lastPlayed),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (p.playedKey case final key?)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cp.Key.tryParse(key)?.format(notation) ?? key,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      l10n.repertoirePlays(p.playCount),
                      textAlign: TextAlign.end,
                      style: secondary,
                    ),
                  ),
                ],
              ),
            ),
          if (fetched != null)
            Text(
              l10n.playHistoryFetched(formatGigDate(context, fetched)),
              style: secondary,
            ),
        ],
      ),
    );
  }
}

/// A number with its label, e.g. "14" over "in total".
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One play: date, set, key and tempo, the sequence below.
class _PlayTile extends StatelessWidget {
  const _PlayTile({
    required this.play,
    required this.notation,
    required this.highlight,
  });

  final SongPlay play;
  final cp.ChordNotation notation;

  /// The key differs from the band's key today.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = play.values;
    final key = values.parsedKey?.format(notation) ?? values.key;
    final sequence = values.sequence;
    return Padding(
      key: ValueKey('play-${play.setId}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  formatGigDate(context, play.date),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  play.setName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (key != null)
                Container(
                  key: highlight ? const Key('play-key-differs') : null,
                  margin: const EdgeInsetsDirectional.only(start: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: highlight
                        ? scheme.tertiaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    play.approximate ? '≈ $key' : key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: highlight
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
              if (values.tempo case final tempo?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text(
                    '$tempo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          if (sequence != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 96, top: 4),
              child: SongSequenceView(
                cp.parseSequence(sequence),
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// The hint of a set's key picker (ADR-0046): "Last D on 12 Oct 2026 ·
/// mostly D (12 of 14)"; null when the band never played the song in a key.
String? keyHistoryHint(
  AppLocalizations l10n,
  SongPlays? plays, {
  required cp.ChordNotation notation,
  required String Function(DateTime date) formatDate,
}) {
  if (plays == null) return null;
  final last = plays.plays.where((p) => p.values.parsedKey != null).firstOrNull;
  if (last == null) return null;
  final text = l10n.keyHistoryLast(
    last.values.parsedKey!.format(notation),
    formatDate(last.date),
  );
  final most = plays.mostPlayedKey;
  if (most == null || plays.total < 2) return text;
  final mostly = l10n.keyHistoryMostly(
    most.key.format(notation),
    most.count,
    plays.total,
  );
  return '$text · $mostly';
}
