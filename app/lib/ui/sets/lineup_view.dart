import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/lineup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import 'lineup_dialog.dart';

/// The names of a lineup in one line, substitutes (ADR-0061) and people
/// without an account (ADR-0064) marked; without [markContacts] (the
/// printed set list), people without an account are not marked.
String lineupNames(
  AppLocalizations l10n,
  SetLineup lineup, {
  bool markContacts = true,
}) {
  if (lineup.people.isEmpty && lineup.contacts.isEmpty) {
    return l10n.lineupNobody;
  }
  return [
    for (final p in lineup.people)
      p.substitute ? '${p.name} (${l10n.lineupSubstitute})' : p.name,
    for (final c in lineup.contacts)
      markContacts ? '${c.name} (${l10n.lineupNoAccount})' : c.name,
  ].join(', ');
}

/// The lineup of a set in the set view (ADR-0061): who plays it, whether it
/// is the whole band, and *Not planned for you*. Who may edit the set taps
/// it to choose the lineup. Nothing in the local library.
class SetLineupRow extends ConsumerWidget {
  const SetLineupRow({super.key, required this.set, required this.canEdit});

  final SetlistEntry set;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineup = ref.watch(setLineupProvider(set.id));
    if (lineup == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final label = lineup.custom
        ? l10n.lineup
        : '${l10n.lineup} · ${l10n.lineupWholeBand}';
    return InkWell(
      key: const Key('set-lineup'),
      onTap: canEdit ? () => showLineupDialog(context, ref, set) : null,
      child: Padding(
        // Right: in line with the drag handles of the rows.
        padding: const EdgeInsets.fromLTRB(16, 0, 32, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_outlined, size: 18, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  Text(lineupNames(l10n, lineup)),
                  if (!lineup.plannedForMe)
                    NotPlannedLabel(key: const Key('set-not-planned')),
                ],
              ),
            ),
            if (canEdit) Icon(Icons.edit_outlined, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

/// *Not planned for you* (ADR-0061), on a set the user does not play.
class NotPlannedLabel extends StatelessWidget {
  const NotPlannedLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_busy_outlined, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            l10n.lineupNotPlanned,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
