import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trash.dart';
import '../../data/trash_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../theme.dart';
import '../widgets/app_shortcuts.dart';
import '../widgets/dialogs.dart';
import '../widgets/menu_action.dart';
import '../widgets/page_width.dart';
import '../widgets/section_header.dart';

/// What a trash shows.
enum TrashKind { songs, sets }

/// Days left from which the badge of an entry is drawn in the warning
/// colour.
const _lastDays = 3;

/// Deleted songs of a library or sets of a band that can still be restored
/// (ADR-0043): deleted less than 30 days ago, most recent first, grouped by
/// when they were deleted. Each entry can be restored or deleted
/// permanently (#866) from its menu; a long press selects several, and the
/// app bar empties the whole trash.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen.songs({super.key, required String libraryId})
    : kind = TrashKind.songs,
      id = libraryId;

  const TrashScreen.sets({super.key, required String bandId})
    : kind = TrashKind.sets,
      id = bandId;

  final TrashKind kind;

  /// The library ([TrashKind.songs]) or band ([TrashKind.sets]).
  final String id;

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  /// Selected entries, or null outside selection mode.
  Set<String>? _selected;

  TrashRepository get _repo => ref.read(trashRepositoryProvider);

  Future<void> _restore(Iterable<String> ids) => switch (widget.kind) {
    TrashKind.songs => Future.wait(ids.map(_repo.restoreSong)),
    TrashKind.sets => Future.wait(ids.map(_repo.restoreSet)),
  };

  Future<void> _purge(Iterable<String> ids) => switch (widget.kind) {
    TrashKind.songs => _repo.purgeSongs(ids),
    TrashKind.sets => _repo.purgeSets(ids),
  };

  Future<void> _restoreOne(_TrashEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await _restore([entry.id]);
    showMessageOn(messenger, l10n.trashRestored(entry.title));
  }

  Future<void> _purgeOne(_TrashEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: l10n.trashPurgeTitle,
      message: l10n.trashPurgeOne(entry.title),
      action: l10n.trashPurge,
    );
    if (!ok) return;
    await _purge([entry.id]);
    showMessageOn(messenger, l10n.trashPurged(entry.title));
  }

  Future<void> _restoreMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await _restore(ids);
    if (mounted) setState(() => _selected = null);
    showMessageOn(messenger, l10n.trashRestoredMany(ids.length));
  }

  /// Deletes [ids] permanently after a confirmation; [title] names the
  /// action (deleting the selection or emptying the trash).
  Future<void> _purgeMany(Set<String> ids, {required String title}) async {
    if (ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: title,
      message: l10n.trashPurgeMany(ids.length),
      action: l10n.trashPurge,
    );
    if (!ok) return;
    await _purge(ids);
    if (mounted) setState(() => _selected = null);
    showMessageOn(messenger, l10n.trashPurgedMany(ids.length));
  }

  void _toggle(String id) => setState(() {
    final selected = {...?_selected};
    if (!selected.remove(id)) selected.add(id);
    _selected = selected.isEmpty ? null : selected;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AsyncValue<List<_TrashEntry>> entries = switch (widget.kind) {
      TrashKind.songs =>
        ref
            .watch(trashedSongsProvider(widget.id))
            .whenData(
              (songs) => [
                for (final s in songs)
                  _TrashEntry(s.id, s.title, s.artist, s.deletedAt!),
              ],
            ),
      TrashKind.sets =>
        ref
            .watch(trashedSetsProvider(widget.id))
            .whenData(
              (sets) => [
                for (final s in sets)
                  _TrashEntry(
                    s.id,
                    s.name,
                    s.gigDate == null
                        ? null
                        : formatGigDate(context, s.gigDate!),
                    s.deletedAt!,
                  ),
              ],
            ),
    };
    final list = entries.value ?? const <_TrashEntry>[];
    final all = {for (final e in list) e.id};
    // Entries restored or purged elsewhere leave the selection.
    final selected = _selected?.intersection(all);

    return PageShortcuts(
      bindings: {
        closeSelectionShortcut: selected == null
            ? null
            : () => setState(() => _selected = null),
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selected == null
              ? null
              : IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selected = null),
                ),
          title: Text(
            selected != null
                ? l10n.songsSelected(selected.length)
                : widget.kind == TrashKind.songs
                ? l10n.trashSongsTitle
                : l10n.trashSetsTitle,
          ),
          actions: selected != null
              ? [
                  IconButton(
                    tooltip: l10n.selectAll,
                    icon: const Icon(Icons.select_all),
                    onPressed: () => setState(() => _selected = all),
                  ),
                  IconButton(
                    key: const Key('trash-restore-selected'),
                    tooltip: l10n.trashRestore,
                    icon: const Icon(Icons.restore_from_trash_outlined),
                    onPressed: () => _restoreMany(selected),
                  ),
                  IconButton(
                    key: const Key('trash-purge-selected'),
                    tooltip: l10n.trashPurge,
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: () =>
                        _purgeMany(selected, title: l10n.trashPurgeTitle),
                  ),
                ]
              : [
                  if (list.isNotEmpty)
                    PopupMenuButton<String>(
                      key: const Key('trash-menu'),
                      onSelected: (value) => switch (value) {
                        'empty' => _purgeMany(all, title: l10n.trashEmptyTitle),
                        _ => setState(() => _selected = {}),
                      },
                      itemBuilder: (_) => [
                        MenuAction(
                          value: 'select',
                          icon: Icons.checklist,
                          label: l10n.selectMode,
                        ),
                        const PopupMenuDivider(),
                        MenuAction(
                          key: const Key('trash-empty'),
                          value: 'empty',
                          icon: Icons.delete_forever_outlined,
                          label: l10n.trashEmptyAction,
                          destructive: true,
                        ),
                      ],
                    ),
                ],
        ),
        body: AsyncBody(
          value: entries,
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.delete_outline,
                  message: l10n.trashEmpty(trashRetention.inDays),
                )
              : PageWidth(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          l10n.trashHint(trashRetention.inDays),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      for (final (group, items) in _groups(list)) ...[
                        SectionHeader(switch (group) {
                          _Group.today => l10n.trashGroupToday,
                          _Group.week => l10n.trashGroupWeek,
                          _Group.older => l10n.trashGroupOlder,
                        }),
                        for (final e in items)
                          _TrashTile(
                            entry: e,
                            kind: widget.kind,
                            selected: selected?.contains(e.id),
                            onToggle: () => _toggle(e.id),
                            onRestore: () => _restoreOne(e),
                            onPurge: () => _purgeOne(e),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

enum _Group { today, week, older }

/// [entries] (most recently deleted first) by when they were deleted.
List<(_Group, List<_TrashEntry>)> _groups(List<_TrashEntry> entries) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final week = today.subtract(const Duration(days: 6));
  final groups = <_Group, List<_TrashEntry>>{};
  for (final e in entries) {
    final at = e.deletedAt.toLocal();
    final group = !at.isBefore(today)
        ? _Group.today
        : !at.isBefore(week)
        ? _Group.week
        : _Group.older;
    groups.putIfAbsent(group, () => []).add(e);
  }
  return [
    for (final g in _Group.values)
      if (groups[g] case final items?) (g, items),
  ];
}

class _TrashEntry {
  const _TrashEntry(this.id, this.title, this.detail, this.deletedAt);

  final String id;
  final String title;
  final String? detail;
  final DateTime deletedAt;
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry,
    required this.kind,
    required this.selected,
    required this.onToggle,
    required this.onRestore,
    required this.onPurge,
  });

  final _TrashEntry entry;
  final TrashKind kind;

  /// Whether the entry is selected, or null outside selection mode.
  final bool? selected;
  final VoidCallback onToggle;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selecting = selected != null;
    return ListTile(
      key: ValueKey('trash-${entry.id}'),
      // In selection mode the checkbox takes the icon's place, leading like
      // in the other multi-select lists.
      leading: selecting
          ? Checkbox(
              key: ValueKey('trash-check-${entry.id}'),
              value: selected,
              onChanged: (_) => onToggle(),
            )
          : Icon(
              kind == TrashKind.songs
                  ? Icons.music_note_outlined
                  : Icons.queue_music_outlined,
            ),
      title: Text(entry.title),
      subtitle: Text(
        [
          ?entry.detail,
          l10n.trashDeletedOn(formatGigDate(context, entry.deletedAt)),
        ].join(' · '),
      ),
      selected: selected ?? false,
      onTap: selecting ? onToggle : null,
      onLongPress: selecting ? null : onToggle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DaysLeft(deletedAt: entry.deletedAt),
          if (!selecting)
            PopupMenuButton<String>(
              key: ValueKey('trash-menu-${entry.id}'),
              tooltip: l10n.trashMenu(entry.title),
              onSelected: (value) => value == 'purge' ? onPurge() : onRestore(),
              itemBuilder: (_) => [
                MenuAction(
                  key: ValueKey('trash-restore-${entry.id}'),
                  value: 'restore',
                  icon: Icons.restore_from_trash_outlined,
                  label: l10n.trashRestore,
                ),
                const PopupMenuDivider(),
                MenuAction(
                  key: ValueKey('trash-purge-${entry.id}'),
                  value: 'purge',
                  icon: Icons.delete_forever_outlined,
                  label: l10n.trashPurge,
                  destructive: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The days an entry can still be restored, as a small badge; in the
/// warning colour on the last days.
class _DaysLeft extends StatelessWidget {
  const _DaysLeft({required this.deletedAt});

  final DateTime deletedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final until = TrashRepository.restorableUntil(deletedAt);
    // Started days count: deleted just now is "30 days left".
    final left = until.difference(DateTime.now());
    final days = left.isNegative ? 0 : (left.inMinutes / (24 * 60)).ceil();
    final warning = days <= _lastDays;
    final color = warning
        ? StatusColors.of(context).warning
        : theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          l10n.trashDaysLeft(days),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: warning ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
