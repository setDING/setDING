import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../bands/band_switcher.dart';
import '../widgets/dialogs.dart';
import 'set_screen.dart';

/// List of sets (setlists).
class SetsScreen extends ConsumerWidget {
  const SetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sets = ref.watch(setsProvider);
    final band = ref.watch(currentBandProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSets),
        actions: const [BandSwitcher()],
      ),
      floatingActionButton: !band.canManageSets
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () async {
                final id = await showSetDialog(context, ref);
                if (id != null && context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SetScreen(setId: id),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.newSet),
            ),
      body: AsyncBody(
        value: sets,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(icon: Icons.queue_music, message: l10n.setsEmpty);
          }
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final groups = groupSets(list, today);
          final pastCollapsed = ref.watch(pastSetsCollapsedProvider);
          final rows = <Widget>[
            if (groups.upcoming.isNotEmpty) ...[
              _SectionHeader(l10n.setsUpcoming),
              for (final (i, s) in groups.upcoming.indexed)
                _SetCard(summary: s, nextGigFrom: i == 0 ? today : null),
            ],
            if (groups.undated.isNotEmpty) ...[
              _SectionHeader(l10n.setsUndated),
              for (final s in groups.undated) _SetCard(summary: s),
            ],
            if (groups.past.isNotEmpty) ...[
              _SectionHeader(
                l10n.setsPast(groups.past.length),
                collapsed: pastCollapsed,
                onToggle: () =>
                    ref.read(pastSetsCollapsedProvider.notifier).toggle(),
              ),
              if (!pastCollapsed)
                for (final s in groups.past) _SetCard(summary: s),
            ],
          ];
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i],
          );
        },
      ),
    );
  }
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
    final text = Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
    final onToggle = this.onToggle;
    if (onToggle == null) {
      return Semantics(
        header: true,
        child: Padding(
          key: const ValueKey('set-section-header'),
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: text,
        ),
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
  const _SetCard({required this.summary, this.nextGigFrom});

  final SetSummary summary;

  /// Set for the next gig, highlighted with the days from this day on.
  final DateTime? nextGigFrom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final set = summary.set;
    final ready = ref.watch(offlineReadyProvider(set.id)).value;
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
      child: ListTile(
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
        trailing: ready == null ? null : OfflineBadge(ready: ready),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => SetScreen(setId: set.id)),
        ),
      ),
    );
  }
}

/// "Offline ready" indicator (ADR-0001): an icon, its meaning in the
/// tooltip.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = ready ? l10n.offlineReady : l10n.notOfflineReady;
    final icon = Icon(
      ready ? Icons.offline_pin : Icons.cloud_off,
      color: ready ? Colors.green.shade600 : colors.error,
    );
    return Tooltip(message: label, child: icon);
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
