import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../account/sync_refresh.dart';
import '../bands/band_switcher.dart';
import '../songs/chordpro_problems_badge.dart';
import '../songs/songs_screen.dart' show songListTwoColumnWidth;
import '../theme.dart';
import '../trash/trash_screen.dart';
import '../widgets/breakpoint_builder.dart';
import '../widgets/dialogs.dart';
import 'repertoire_screen.dart';
import 'set_archive_dialogs.dart';
import 'set_screen.dart';
import '../widgets/section_header.dart';
import 'sync_stale_banner.dart';
import '../widgets/menu_action.dart';

/// Minimum width for showing the list of sets and the selected set side by
/// side (#266); the same as for the song list's two columns.
const setsMasterDetailWidth = songListTwoColumnWidth;

/// Width of the list of sets next to the selected set.
const _listPaneWidth = 400.0;

/// List of sets (setlists), grouped by gig date (#265).
///
/// From [setsMasterDetailWidth] on, the selected set ([selectedSetProvider],
/// by default the next gig) is shown next to the list; narrower screens open
/// a set as its own page.
///
/// The past sets start collapsed ([pastSetsCollapsedProvider], #282).
/// Collapsing only hides their cards: a selected past set stays shown next
/// to the list, and selecting one (e.g. a new set with a past date) does not
/// expand the section, so the stored choice always wins.
class SetsScreen extends ConsumerWidget {
  const SetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(setsProvider).value ?? const <SetSummary>[];
    final selected = ref.watch(selectedSetProvider);
    return BreakpointBuilder(
      select: (constraints) => constraints.maxWidth >= setsMasterDetailWidth,
      builder: (context, wide) {
        final shown = wide ? shownSetId(list, selected, today: _today()) : null;
        if (shown == null) return const _SetsPane();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _listPaneWidth,
              child: _SetsPane(shown: shown),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SetScreen(
                key: ValueKey(shown),
                setId: shown,
                embedded: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// The set shown next to the list: [selected] while it is in [sets],
/// otherwise the next gig, or the first set in the order of the list; null
/// without sets.
String? shownSetId(
  List<SetSummary> sets,
  String? selected, {
  required DateTime today,
}) {
  if (selected != null && sets.any((s) => s.set.id == selected)) {
    return selected;
  }
  final groups = groupSets(sets, today);
  return [
    ...groups.upcoming,
    ...groups.undated,
    ...groups.past,
  ].firstOrNull?.set.id;
}

/// The list of sets with its app bar; [shown] is the set shown next to it
/// on wide screens (null on narrow screens, where a set opens as a page).
class _SetsPane extends ConsumerWidget {
  const _SetsPane({this.shown});

  final String? shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sets = ref.watch(setsProvider);
    final band = ref.watch(currentBandProvider);
    final wide = shown != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSets),
        actions: [
          // The band's repertoire from its past sets (ADR-0046).
          IconButton(
            key: const Key('sets-repertoire'),
            tooltip: l10n.repertoire,
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RepertoireScreen(band: band),
              ),
            ),
          ),
          const BandSwitcher(),
          // ADR-0043: whoever may delete sets may restore them, and import
          // an exported set (§1b).
          if (band.canManageSets)
            PopupMenuButton<String>(
              key: const Key('sets-menu'),
              onSelected: (value) => value == 'import'
                  ? pickSetArchive(context, bandId: band.id)
                  : Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => TrashScreen.sets(bandId: band.id),
                      ),
                    ),
              itemBuilder: (_) => [
                MenuAction(
                  key: const Key('sets-import'),
                  value: 'import',
                  icon: Icons.file_open_outlined,
                  label: l10n.setImport,
                ),
                MenuAction(
                  key: const Key('sets-trash'),
                  value: 'trash',
                  icon: Icons.restore_from_trash_outlined,
                  label: l10n.trash,
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: !band.canManageSets
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () async {
                final id = await showSetDialog(context, ref);
                if (id != null && context.mounted) {
                  await openSet(context, ref, id, wide: wide);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.newSet),
            ),
      body: AsyncBody(
        value: sets,
        data: (list) {
          if (list.isEmpty) {
            return SyncRefresh(
              scrollable: false,
              child: EmptyState(
                icon: Icons.queue_music,
                message: l10n.setsEmpty,
              ),
            );
          }
          final today = _today();
          final groups = groupSets(list, today);
          final pastCollapsed = ref.watch(pastSetsCollapsedProvider);
          Widget card(SetSummary s, {DateTime? nextGigFrom}) => _SetCard(
            summary: s,
            nextGigFrom: nextGigFrom,
            selected: s.set.id == shown,
            onTap: () => openSet(context, ref, s.set.id, wide: wide),
          );
          final rows = <Widget>[
            const SyncStaleBanner(),
            if (groups.upcoming.isNotEmpty) ...[
              _SectionHeader(l10n.setsUpcoming),
              for (final (i, s) in groups.upcoming.indexed)
                card(s, nextGigFrom: i == 0 ? today : null),
            ],
            if (groups.undated.isNotEmpty) ...[
              _SectionHeader(l10n.setsUndated),
              for (final s in groups.undated) card(s),
            ],
            if (groups.past.isNotEmpty) ...[
              _SectionHeader(
                l10n.setsPast(groups.past.length),
                collapsed: pastCollapsed,
                onToggle: () =>
                    ref.read(pastSetsCollapsedProvider.notifier).toggle(),
              ),
              if (!pastCollapsed)
                for (final s in groups.past) card(s),
            ],
          ];
          return SyncRefresh(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          );
        },
      ),
    );
  }
}

/// Selects the set [setId]; on narrow screens (not [wide]) it also opens as
/// its own page.
Future<void> openSet(
  BuildContext context,
  WidgetRef ref,
  String setId, {
  required bool wide,
}) async {
  ref.read(selectedSetProvider.notifier).select(setId);
  if (wide) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => SetScreen(setId: setId)),
  );
}

/// Header of a section of the sets list; the past sets can be collapsed
/// with a tap ([onToggle]).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.collapsed = false, this.onToggle});

  final String label;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = Text(label, style: SectionHeader.style(context));
    final onToggle = this.onToggle;
    if (onToggle == null) {
      return SectionHeader(
        label,
        key: const ValueKey('set-section-header'),
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      );
    }
    return Semantics(
      header: true,
      child: InkWell(
        key: const ValueKey('set-section-past'),
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Row(
            children: [
              Expanded(child: text),
              Tooltip(
                message: collapsed ? l10n.showPastSets : l10n.hidePastSets,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetCard extends ConsumerWidget {
  const _SetCard({
    required this.summary,
    required this.onTap,
    this.nextGigFrom,
    this.selected = false,
  });

  final SetSummary summary;
  final VoidCallback onTap;

  /// Set for the next gig, highlighted with the days from this day on.
  final DateTime? nextGigFrom;

  /// Shown next to the list (wide screens).
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final set = summary.set;
    final missing = ref.watch(offlineMissingProvider(set.id)).value ?? 0;
    // Songs with ChordPro problems, for who prepares the sets (#314).
    final problems = ref.watch(currentBandProvider).canManageSets
        ? (ref.watch(problemSongCountsProvider).value?[set.id] ?? 0)
        : 0;
    final details = [
      if (set.gigDate != null) formatGigDate(context, set.gigDate!),
      if (set.venue != null) set.venue!,
      l10n.itemCount(summary.itemCount),
    ].join(' · ');
    final next = nextGigFrom;
    final date = set.gigDate;

    return Card(
      key: next == null ? null : const ValueKey('next-gig'),
      color: next == null ? null : colors.primaryContainer,
      shape: !selected
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.primary, width: 2),
            ),
      child: ListTile(
        key: ValueKey('set-${set.id}'),
        selected: selected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: next == null ? null : colors.onPrimaryContainer,
        leading: CircleAvatar(
          backgroundColor: next == null ? null : colors.primary,
          foregroundColor: next == null ? null : colors.onPrimary,
          child: Icon(next == null ? Icons.queue_music : Icons.event),
        ),
        title: next == null || date == null
            ? Text(set.name)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.nextGig} · ${l10n.gigInDays(daysBetween(next, date))}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(set.name),
                ],
              ),
        subtitle: Text(details),
        trailing: missing == 0 && problems == 0
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (problems > 0)
                    ChordProProblemsBadge(
                      key: const ValueKey('set-problems'),
                      message: l10n.setChordProProblemsTooltip(problems),
                    ),
                  if (missing > 0) OfflineMissingBadge(missing: missing),
                ],
              ),
        onTap: onTap,
      ),
    );
  }
}

/// Shown on a set whose songs are not all available offline (ADR-0001):
/// an icon and a short text, so it is understood without a tooltip. Offline
/// ready sets show nothing: a mark that is almost always there is not
/// noticed (#744).
class OfflineMissingBadge extends StatelessWidget {
  const OfflineMissingBadge({super.key, required this.missing});

  /// Song items of the set that are not available offline.
  final int missing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A warning, not an error (ui-design.md §2), like ChordPro problems.
    final color = StatusColors.of(context).warning;
    return Tooltip(
      key: const ValueKey('offline-missing'),
      message: l10n.offlineMissingTooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(Icons.cloud_off_outlined, color: color, size: 20),
          Text(
            l10n.offlineMissing(missing),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Calendar days from [from] to [to] (0 for the same day), independent of
/// the time of day and daylight saving time.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String formatGigDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(date);

/// Creates or edits a set. Returns the set ID, or null if cancelled.
Future<String?> showSetDialog(
  BuildContext context,
  WidgetRef ref, {
  SetlistEntry? existing,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SetDialog(existing: existing),
);

class _SetDialog extends ConsumerStatefulWidget {
  const _SetDialog({this.existing});

  final SetlistEntry? existing;

  @override
  ConsumerState<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends ConsumerState<_SetDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _venue = TextEditingController(text: widget.existing?.venue ?? '');
  late DateTime? _date = widget.existing?.gigDate;

  @override
  void dispose() {
    _name.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(setRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      final id = await repo.createSet(
        name: name,
        gigDate: _date,
        venue: _venue.text,
      );
      if (mounted) Navigator.pop(context, id);
    } else {
      await repo.updateSet(
        existing.id,
        name: name,
        gigDate: _date,
        venue: _venue.text,
      );
      if (mounted) Navigator.pop(context, existing.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.newSet : l10n.editSet),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.setName),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _venue,
              decoration: InputDecoration(labelText: l10n.venue),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _date == null ? l10n.noDate : formatGigDate(context, _date!),
              ),
              trailing: _date == null
                  ? null
                  : IconButton(
                      tooltip: l10n.clearDate,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _date = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: DateTime(now.year - 10),
                  lastDate: DateTime(now.year + 10),
                  helpText: l10n.pickDate,
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
