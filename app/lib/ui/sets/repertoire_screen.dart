import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/band_view.dart';
import '../../data/play_history.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../bands/bands_screen.dart' show runBandAction;
import '../songs/song_screen.dart';
import '../widgets/dialogs.dart';
import 'sets_screen.dart' show formatGigDate;

/// The thresholds offered for "not played for a while", in months.
const staleAfterChoices = [1, 2, 3, 4, 6, 9, 12, 18, 24, 36];

/// The repertoire of [band] (ADR-0046): the songs it played most, the songs
/// it has not played for a while and the songs of its library it never
/// played, from the past sets. Opened from the sets tab.
class RepertoireScreen extends ConsumerStatefulWidget {
  const RepertoireScreen({super.key, required this.band});

  final BandView band;

  @override
  ConsumerState<RepertoireScreen> createState() => _RepertoireScreenState();
}

class _RepertoireScreenState extends ConsumerState<RepertoireScreen> {
  bool _lastYear = true;

  /// The band as it is now, e.g. after its threshold changed.
  BandView get _band {
    final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
    return bands.where((b) => b.id == widget.band.id).firstOrNull ??
        widget.band;
  }

  Future<void> _chooseThreshold(BandView band) async {
    final l10n = AppLocalizations.of(context);
    final months = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.repertoireThreshold),
        children: [
          for (final value in [0, ...staleAfterChoices])
            SimpleDialogOption(
              key: ValueKey('stale-after-$value'),
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: value == band.staleAfterSetting
                        ? const Icon(Icons.check, size: 20)
                        : null,
                  ),
                  Text(
                    value == 0
                        ? l10n.repertoireDefault(
                            BandView.defaultStaleAfterMonths,
                          )
                        : l10n.repertoireMonths(value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (months == null || months == band.staleAfterSetting || !mounted) return;
    await runBandAction(
      context,
      () => ref.read(bandServiceProvider).setStaleAfterMonths(band.id, months),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final band = _band;
    final repertoire = ref.watch(
      repertoireProvider((band: band.id, library: band.libraryId)),
    );
    final months = band.staleAfterMonths;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          band.isLocal ? l10n.repertoire : l10n.repertoireOf(band.name),
        ),
        actions: [
          if (band.canSetStaleAfter)
            IconButton(
              key: const Key('repertoire-threshold'),
              tooltip: l10n.repertoireThreshold,
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => _chooseThreshold(band),
            ),
        ],
      ),
      body: AsyncBody(
        value: repertoire,
        data: (r) {
          final most = r.mostPlayed(lastYear: _lastYear);
          final stale = r.notPlayedFor(months);
          final never = r.neverPlayed;
          final played = r.songs.any((s) => s.total > 0);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (!played)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l10n.repertoireEmpty,
                        key: const Key('repertoire-empty'),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  _Section(
                    key: const Key('repertoire-most-played'),
                    title: l10n.repertoireMostPlayed,
                    trailing: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.repertoireLastYear),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.repertoireAllTime),
                        ),
                      ],
                      selected: {_lastYear},
                      onSelectionChanged: (v) =>
                          setState(() => _lastYear = v.single),
                    ),
                    children: [
                      if (most.isEmpty) _None(l10n.repertoireNone),
                      for (final s in most)
                        _MostPlayedTile(
                          song: s,
                          count: _lastYear ? s.lastYear : s.total,
                          max: _lastYear
                              ? most.first.lastYear
                              : most.first.total,
                        ),
                    ],
                  ),
                  _Section(
                    key: const Key('repertoire-stale'),
                    title: l10n.repertoireStale,
                    subtitle: l10n.repertoireStaleHint(months),
                    children: [
                      if (stale.isEmpty) _None(l10n.repertoireNone),
                      for (final s in stale)
                        _SongTile(
                          song: s,
                          detail: l10n.songLastPlayed(
                            formatGigDate(context, s.last!),
                          ),
                        ),
                    ],
                  ),
                  _Section(
                    key: const Key('repertoire-never'),
                    title: '${l10n.repertoireNeverPlayed} (${never.length})',
                    subtitle: l10n.repertoireNeverPlayedHint,
                    children: [
                      if (never.isEmpty) _None(l10n.repertoireNone),
                      for (final s in never) _SongTile(song: s),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A titled part of the repertoire.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              ?trailing,
            ],
          ),
          if (subtitle case final text?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _None extends StatelessWidget {
  const _None(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

void _open(BuildContext context, String songId) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => SongScreen(songId: songId)),
);

/// A song with a bar for how often it was played.
class _MostPlayedTile extends StatelessWidget {
  const _MostPlayedTile({
    required this.song,
    required this.count,
    required this.max,
  });

  final SongPlayStats song;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('most-played-${song.songId}'),
      onTap: () => _open(context, song.songId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(song.title, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : count / max,
                  minHeight: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text(
                l10n.repertoirePlays(count),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A song with an optional detail line, e.g. when it was played last.
class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, this.detail});

  final SongPlayStats song;
  final String? detail;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('repertoire-song-${song.songId}'),
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(song.title),
    subtitle: switch ((song.artist, detail)) {
      (null, null) => null,
      (final artist, final detail) => Text([?artist, ?detail].join(' · ')),
    },
    onTap: () => _open(context, song.songId),
  );
}
