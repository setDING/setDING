import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/band_view.dart';
import '../../data/change_log.dart' show RecentChange;
import '../../data/play_history.dart' show SongPlayStats;
import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../util/app_version.dart';
import '../account/sync_refresh.dart';
import '../bands/band_switcher.dart';
import '../bands/no_band_hint.dart';
import '../home_tab.dart';
import '../live/live_screen.dart';
import '../sets/repertoire_screen.dart';
import '../sets/sets_screen.dart' show daysBetween, formatGigDate, openSet;
import '../songs/song_attention.dart';
import '../songs/song_screen.dart';
import '../widgets/app_info.dart';
import '../../midi/midi_connection.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_controller.dart';
import '../live/page_turner.dart';
import '../settings_screen.dart' show settingsJumpProvider;
import '../theme.dart' show StatusColors;
import 'readiness.dart';
import 'recent_changes.dart';

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

/// The most upcoming sets the overview lists after the next one (#868).
const moreSetsOnCard = 3;

/// The most songs the overview lists as newest songs and as songs not
/// played for a while (#868).
const songsOnCard = 5;

/// The upcoming sets of the band after the next one, at most
/// [moreSetsOnCard] (*More sets*, #868).
List<SetSummary> moreSets(List<SetSummary> sets, DateTime today) =>
    groupSets(sets, today).upcoming.skip(1).take(moreSetsOnCard).toList();

/// The start screen (ADR-0045): cards with the next set, whether this
/// device is ready to play it (#911), the sets after it, what needs to be
/// done, the recent changes by other people, the
/// newest songs, the songs not played for a while (#868) and the version.
/// A card with
/// nothing to show is left out. One column on phones, two from
/// [navigationRailWidth]. Everything comes from the local database and
/// updates live during a sync.
///
/// The overview counts as shown when it is left: when another tab is
/// selected or the app is hidden while it is on the overview. Until then
/// the recent changes stay, also when the person opens one of them and
/// comes back.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    ref.listenManual(homeTabProvider, (previous, next) {
      if (previous == HomeTab.overview && next != HomeTab.overview) {
        ref.read(overviewLastShownProvider.notifier).markShown();
      }
    });
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (ref.read(homeTabProvider) == HomeTab.overview) {
          ref.read(overviewLastShownProvider.notifier).markShown();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sets = ref.watch(setsProvider).value ?? const <SetSummary>[];
    final shown = overviewSet(sets, today);
    final counts = ref.watch(songAttentionCountsProvider);
    final changes =
        ref.watch(recentChangesProvider(false)).value ?? const <RecentChange>[];
    final more = moreSets(sets, today);
    final newest = ref.watch(newestSongsProvider).value ?? const <SongEntry>[];
    final band = ref.watch(currentBandProvider);
    final hasBand = ref.watch(hasCurrentBandProvider);
    final stale = hasBand
        ? ref
                  .watch(
                    repertoireProvider((
                      band: band.id,
                      library: band.libraryId,
                    )),
                  )
                  .value
                  ?.notPlayedFor(band.staleAfterMonths) ??
              const <SongPlayStats>[]
        : const <SongPlayStats>[];
    final cards = <Widget>[
      if (!hasBand) const NoBandHint(),
      if (shown != null)
        _SetCard(
          key: ValueKey('overview-set-${shown.summary.set.id}'),
          set: shown.summary.set,
          upcoming: shown.upcoming,
          today: today,
        ),
      _ReadinessCard(
        nextSet: shown != null && shown.upcoming ? shown.summary.set : null,
      ),
      if (more.isNotEmpty) _MoreSetsCard(sets: more, today: today),
      if (counts != null && counts.values.any((c) => c > 0))
        _TodoCard(counts: counts),
      if (changes.isNotEmpty) _RecentChangesCard(changes: changes),
      if (newest.isNotEmpty) _NewestSongsCard(songs: newest),
      if (stale.isNotEmpty) _NotPlayedCard(songs: stale, band: band),
    ];
    final twoColumns = MediaQuery.sizeOf(context).width >= navigationRailWidth;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navOverview),
        actions: const [BandSwitcher()],
      ),
      body: SyncRefresh(
        // The footer sits at the bottom of the screen while the cards leave
        // room, and at the end of the list once they do not (#896).
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              sliver: SliverList.list(
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
                ],
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _Footer(),
                ),
              ),
            ),
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
    this.onTap,
  });

  final String title;
  final List<Widget> children;

  /// Makes the whole card tappable; buttons on it keep their own action.
  final VoidCallback? onTap;

  /// In the colours of the next gig on the sets tab.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = Padding(
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
    );
    return Card(
      color: highlight ? colors.primaryContainer : null,
      clipBehavior: onTap == null ? null : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// The next set, or the most recently edited one, with *Start live* on its
/// first song and *Open set*; a tap anywhere else on the card opens the set
/// too (#693).
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
    void open() => openSet(context, ref, set.id, wide: false);
    return _OverviewCard(
      key: const Key('overview-next-set'),
      title: upcoming ? l10n.overviewNextSet : l10n.overviewLastEditedSet,
      highlight: upcoming,
      onTap: open,
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
                onPressed: open,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether this device is ready to play (#911): one line per check of
/// `readiness.dart`, each leading to the setting that fixes it (or to the
/// next set). Lines that are ok are folded into one summary line until
/// *Show details*; warnings are always shown.
///
/// While the overview is shown, a page-turn key marks the page turner as
/// responding: the quick test before a gig, without opening a set.
class _ReadinessCard extends ConsumerStatefulWidget {
  const _ReadinessCard({required this.nextSet});

  /// The next set with a gig date, for the summary and the offline check.
  final SetlistEntry? nextSet;

  @override
  ConsumerState<_ReadinessCard> createState() => _ReadinessCardState();
}

class _ReadinessCardState extends ConsumerState<_ReadinessCard> {
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    super.dispose();
  }

  /// Page Up / Page Down are taken: their default page scroll finds the
  /// scroll views of every tab and fails. Arrows and Space keep their
  /// focus and activate actions.
  KeyEventResult _onKey(KeyEvent event) {
    final key = event.logicalKey;
    if (!isPageTurnKey(key) ||
        !mounted ||
        ref.read(homeTabProvider) != HomeTab.overview ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      ref.read(pageTurnerProvider.notifier).tested();
    }
    return key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.pageUp
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    String time(DateTime t) =>
        '${localizations.formatShortDate(t)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
    final settings = ref.watch(settingsProvider);
    final web = ref.watch(webClientProvider);
    final next = widget.nextSet;
    final backupSupported = !web && ref.watch(backupFolderProvider).supported;
    final items = [
      musicianReadiness(l10n, settings),
      ?midiReadiness(l10n, settings, ref.watch(midiConnectionProvider)),
      ?offlineReadiness(
        l10n,
        nextSetId: next?.id,
        missing: next == null
            ? null
            : ref.watch(offlineMissingProvider(next.id)).value,
      ),
      ?syncReadiness(
        l10n,
        time,
        synced: !web && ref.watch(authProvider) != null,
        mode: settings.syncMode,
        lastSync: ref.watch(syncControllerProvider.select((s) => s.lastSync)),
        staleness: ref.watch(syncStalenessProvider),
      ),
      pageTurnerReadiness(
        l10n,
        time,
        mode: settings.pageTurn,
        state: ref.watch(pageTurnerProvider),
      ),
      ?backupReadiness(
        l10n,
        time,
        backupSupported ? ref.watch(autoBackupProvider) : null,
      ),
    ];
    final shown = _expanded
        ? items
        : items.where((i) => i.level == ReadinessLevel.warning).toList();
    final status = StatusColors.of(context);
    Color levelColor(ReadinessLevel level) => switch (level) {
      ReadinessLevel.ok => status.success,
      ReadinessLevel.info => theme.colorScheme.onSurfaceVariant,
      ReadinessLevel.warning => status.warning,
    };
    void open(ReadinessItem item) {
      if (item.setId case final id?) {
        openSet(context, ref, id, wide: false);
      } else if (item.category case final category?) {
        ref.read(settingsJumpProvider.notifier).open(category);
        ref.read(homeTabProvider.notifier).select(HomeTab.settings);
      }
    }

    return _OverviewCard(
      key: const Key('overview-readiness'),
      title: l10n.overviewReadiness,
      children: [
        if (shown.isEmpty)
          ListTile(
            key: const Key('overview-readiness-all-set'),
            leading: Icon(Icons.check_circle_outline, color: status.success),
            title: Text(
              next == null
                  ? l10n.readinessAllSetNoSet
                  : l10n.readinessAllSet(next.name),
            ),
          ),
        for (final item in shown)
          ListTile(
            key: ValueKey('overview-readiness-${item.check.name}'),
            leading: Icon(
              _readinessIcon(item.check),
              color: levelColor(item.level),
            ),
            title: Text(item.title),
            subtitle: item.detail == null ? null : Text(item.detail!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(item),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('overview-readiness-details'),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? l10n.readinessHideDetails
                    : l10n.readinessShowDetails,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _readinessIcon(ReadinessCheck check) => switch (check) {
  ReadinessCheck.musician => Icons.music_note_outlined,
  ReadinessCheck.midi => Icons.piano_outlined,
  ReadinessCheck.offline => Icons.offline_pin_outlined,
  ReadinessCheck.sync => Icons.sync,
  ReadinessCheck.pageTurner => Icons.keyboard_outlined,
  ReadinessCheck.backup => Icons.backup_outlined,
};

/// What needs attention by the person, only songs they may edit
/// (ADR-0023); each line opens the song list filtered to its songs.
class _TodoCard extends ConsumerWidget {
  const _TodoCard({required this.counts});

  final Map<SongAttention, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget line(SongAttention kind, String text) => ListTile(
      key: ValueKey('overview-todo-${kind.name}'),
      leading: songAttentionIcon(context, kind),
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
            line(kind, switch (kind) {
              SongAttention.problems => l10n.overviewTodoProblems(count),
              SongAttention.conversions => l10n.overviewTodoConversions(count),
              SongAttention.conflicts => l10n.overviewTodoConflicts(count),
              SongAttention.sheetMusicOnly => l10n.overviewTodoSheetMusicOnly(
                count,
              ),
            }),
      ],
    );
  }
}

/// What other people changed since the overview was last shown
/// (ADR-0045): the newest [recentChangesOnCard], with *Show all*.
class _RecentChangesCard extends StatelessWidget {
  const _RecentChangesCard({required this.changes});

  final List<RecentChange> changes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _OverviewCard(
      key: const Key('overview-recent-changes'),
      title: l10n.overviewRecentChanges,
      children: [
        for (final change in changes.take(recentChangesOnCard))
          RecentChangeTile(change),
        _ShowAll(
          buttonKey: const Key('overview-recent-changes-all'),
          builder: (_) => const RecentChangesScreen(),
        ),
      ],
    );
  }
}

/// *Show all* at the end of a card, opening the page of [builder].
class _ShowAll extends StatelessWidget {
  const _ShowAll({required this.buttonKey, required this.builder});

  final Key buttonKey;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton(
        key: buttonKey,
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute<void>(builder: builder)),
        child: Text(AppLocalizations.of(context).overviewShowAll),
      ),
    ),
  );
}

void _openSong(BuildContext context, String songId) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => SongScreen(songId: songId)),
);

/// The upcoming sets after the next one (#868); a tap opens the set.
class _MoreSetsCard extends ConsumerWidget {
  const _MoreSetsCard({required this.sets, required this.today});

  final List<SetSummary> sets;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _OverviewCard(
      key: const Key('overview-more-sets'),
      title: l10n.overviewMoreSets,
      children: [
        for (final summary in sets)
          ListTile(
            key: ValueKey('overview-more-set-${summary.set.id}'),
            leading: const Icon(Icons.event),
            title: Text(
              summary.set.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                formatGigDate(context, summary.set.gigDate!),
                l10n.gigInDays(daysBetween(today, summary.set.gigDate!)),
                ?summary.set.venue,
              ].join(' · '),
            ),
            onTap: () => openSet(context, ref, summary.set.id, wide: false),
          ),
      ],
    );
  }
}

/// The songs of the band's library created last (#868), with artist, key
/// and the day they were added; a tap opens the song.
class _NewestSongsCard extends StatelessWidget {
  const _NewestSongsCard({required this.songs});

  final List<SongEntry> songs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    String subtitle(SongEntry song) =>
        [?song.artist, ?song.songKey].join(' · ');
    return _OverviewCard(
      key: const Key('overview-newest-songs'),
      title: l10n.overviewNewestSongs,
      children: [
        for (final song in songs)
          ListTile(
            key: ValueKey('overview-newest-${song.id}'),
            leading: const Icon(Icons.library_music_outlined),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitle(song).isEmpty ? null : Text(subtitle(song)),
            // The day it was added, with the year when it is not this one.
            trailing: Text(
              song.createdAt!.year == DateTime.now().year
                  ? dates.formatShortMonthDay(song.createdAt!)
                  : dates.formatShortDate(song.createdAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: () => _openSong(context, song.id),
          ),
      ],
    );
  }
}

/// The songs the band has not played for longer than its threshold
/// (ADR-0046, #868), longest ago first; *Show all* opens the repertoire.
class _NotPlayedCard extends StatelessWidget {
  const _NotPlayedCard({required this.songs, required this.band});

  final List<SongPlayStats> songs;
  final BandView band;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _OverviewCard(
      key: const Key('overview-not-played'),
      title: l10n.repertoireStale,
      children: [
        for (final song in songs.take(songsOnCard))
          ListTile(
            key: ValueKey('overview-not-played-${song.songId}'),
            leading: const Icon(Icons.history),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              l10n.songLastPlayed(formatGigDate(context, song.last!)),
            ),
            onTap: () => _openSong(context, song.songId),
          ),
        _ShowAll(
          buttonKey: const Key('overview-not-played-all'),
          builder: (_) => RepertoireScreen(band: band),
        ),
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
        mainAxisSize: MainAxisSize.min,
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
