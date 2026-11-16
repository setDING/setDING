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
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.queue_music, message: l10n.setsEmpty)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                itemCount: list.length,
                itemBuilder: (context, i) => _SetCard(summary: list[i]),
              ),
      ),
    );
  }
}

class _SetCard extends ConsumerWidget {
  const _SetCard({required this.summary});

  final SetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final set = summary.set;
    final ready = ref.watch(offlineReadyProvider(set.id)).value;
    final details = [
      if (set.gigDate != null) formatGigDate(context, set.gigDate!),
      if (set.venue != null) set.venue!,
      l10n.itemCount(summary.itemCount),
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const CircleAvatar(child: Icon(Icons.queue_music)),
        title: Text(set.name),
        subtitle: Text(details),
        trailing: ready == null
            ? null
            : OfflineBadge(ready: ready, compact: true),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => SetScreen(setId: set.id)),
        ),
      ),
    );
  }
}

/// "Offline ready" indicator (ADR-0001).
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, required this.ready, this.compact = false});

  final bool ready;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = ready ? l10n.offlineReady : l10n.notOfflineReady;
    final icon = Icon(
      ready ? Icons.offline_pin : Icons.cloud_off,
      color: ready ? Colors.green.shade600 : colors.error,
    );
    if (compact) return Tooltip(message: label, child: icon);
    return Chip(avatar: icon, label: Text(label));
  }
}

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
