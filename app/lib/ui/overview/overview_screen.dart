import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../util/app_version.dart';
import '../account/sync_refresh.dart';
import '../bands/band_switcher.dart';
import '../home_tab.dart';
import '../live/live_screen.dart';
import '../sets/sets_screen.dart' show daysBetween, formatGigDate, openSet;
import '../songs/chordpro_problems_badge.dart';
import '../songs/song_attention.dart';
import '../widgets/app_info.dart';

/// The set the overview shows (ADR-0045): the next set of the current band
/// with a gig date from [today] on, the one the song list's status icon
/// uses ([upcoming]); otherwise the most recently edited set. Null without
/// sets.
({SetSummary summary, bool upcoming})? overviewSet(
  List<SetSummary> sets,
  DateTime today,
) {
  if (groupSets(sets, today).upcoming.firstOrNull case final next?) {
    return (summary: next, upcoming: true);
  }
  if (sets.isEmpty) return null;
  final recent = sets.reduce(
    (a, b) => b.set.updatedAt.isAfter(a.set.updatedAt) ? b : a,
  );
  return (summary: recent, upcoming: false);
}

/// The start screen (ADR-0045): cards with the next set, what needs to be
/// done and the version. A card with nothing to show is left out. One
/// column on phones, two from [navigationRailWidth]. Everything comes from
/// the local database and updates live during a sync.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sets = ref.watch(setsProvider).value ?? const <SetSummary>[];
    final shown = overviewSet(sets, today);
    final counts = ref.watch(songAttentionCountsProvider);
    final cards = <Widget>[
      if (shown != null)
        _SetCard(
          key: ValueKey('overview-set-${shown.summary.set.id}'),
          set: shown.summary.set,
          upcoming: shown.upcoming,
          today: today,
        ),
      if (counts != null && counts.values.any((c) => c > 0))
        _TodoCard(counts: counts),
      // Recent changes (#667) follows here.
    ];
    final twoColumns = MediaQuery.sizeOf(context).width >= navigationRailWidth;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navOverview),
        actions: const [BandSwitcher()],
      ),
      body: SyncRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            if (twoColumns && cards.length > 1)
              Row(
                key: const Key('overview-two-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  for (final column in [0, 1])
                    Expanded(
                      child: Column(
                        children: [
                          for (final (i, card) in cards.indexed)
                            if (i % 2 == column) card,
                        ],
                      ),
                    ),
                ],
              )
            else
              ...cards,
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

/// A card of the overview with a [title] above its content.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    super.key,
    required this.title,
    required this.children,
    this.highlight = false,
  });

  final String title;
  final List<Widget> children;

  /// In the colours of the next gig on the sets tab.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: highlight ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The next set, or the most recently edited one, with *Start live* on its
/// first song and *Open set*.
class _SetCard extends ConsumerWidget {
  const _SetCard({
    super.key,
    required this.set,
    required this.upcoming,
    required this.today,
  });

  final SetlistEntry set;
  final bool upcoming;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = ref.watch(setItemsProvider(set.id)).value;
    final songs = items
        ?.where((v) => v.item.type == SetItemType.song && v.song != null)
        .length;
    final date = set.gigDate;
    final details = [
      if (date != null) formatGigDate(context, date),
      if (upcoming && date != null) l10n.gigInDays(daysBetween(today, date)),
      ?set.venue,
      if (songs != null) l10n.overviewSongCount(songs),
    ].join(' · ');
    return _OverviewCard(
      key: const Key('overview-next-set'),
      title: upcoming ? l10n.overviewNextSet : l10n.overviewLastEditedSet,
      highlight: upcoming,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            set.name,
            style: theme.textTheme.titleLarge?.copyWith(
              color: upcoming ? colors.onPrimaryContainer : null,
            ),
          ),
        ),
        if (details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              details,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: upcoming ? colors.onPrimaryContainer : null,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('overview-start-live'),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.overviewStartLive),
                onPressed: songs == null || songs == 0
                    ? null
                    : () =>
                          LiveScreen.openSet(context, set.id, firstSong: true),
              ),
              OutlinedButton.icon(
                key: const Key('overview-open-set'),
                icon: const Icon(Icons.queue_music),
                label: Text(l10n.overviewOpenSet),
                onPressed: () => openSet(context, ref, set.id, wide: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What needs attention by the person, only songs they may edit
/// (ADR-0023); each line opens the song list filtered to its songs.
class _TodoCard extends ConsumerWidget {
  const _TodoCard({required this.counts});

  final Map<SongAttention, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    Widget line(SongAttention kind, Widget icon, String text) => ListTile(
      key: ValueKey('overview-todo-${kind.name}'),
      leading: icon,
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ref.read(songAttentionFilterProvider.notifier).select(kind);
        ref.read(homeTabProvider.notifier).select(HomeTab.songs);
      },
    );
    return _OverviewCard(
      key: const Key('overview-todo'),
      title: l10n.overviewTodo,
      children: [
        for (final kind in SongAttention.values)
          if ((counts[kind] ?? 0) case final count when count > 0)
            switch (kind) {
              SongAttention.problems => line(
                kind,
                Icon(
                  Icons.warning_amber_rounded,
                  color: chordProProblemColor(context),
                ),
                l10n.overviewTodoProblems(count),
              ),
              SongAttention.conflicts => line(
                kind,
                Icon(Icons.sync_problem, color: colors.error),
                l10n.overviewTodoConflicts(count),
              ),
              SongAttention.sheetMusicOnly => line(
                kind,
                const Icon(Icons.picture_as_pdf),
                l10n.overviewTodoSheetMusicOnly(count),
              ),
            },
      ],
    );
  }
}

/// The version, the update hint (ADR-0036) and *What's new* (ADR-0041);
/// all of them stay under *Storage & info* too.
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value;
    return Padding(
      key: const Key('overview-footer'),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          const UpdateAvailableTile(
            key: Key('overview-update'),
            installKey: Key('overview-update-install'),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (version != null)
                Text(
                  l10n.settingsVersion(version),
                  key: const Key('overview-version'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const WhatsNewButton(key: Key('overview-whats-new')),
            ],
          ),
        ],
      ),
    );
  }
}
