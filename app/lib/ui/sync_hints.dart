import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_engine.dart';
import 'overview/recent_changes.dart';

/// Hints after a sync (#691): when someone else changed or deleted the song
/// or set on the screen, the person is told; a deleted one closes its
/// screen. Not in live mode (the sync is paused there, ADR-0007): the run
/// that catches up afterwards sums everything up once
/// ([listenForLiveSummary]).
///
/// Call from the screen's `build`. [onDeleted] closes the screen; it also
/// runs after live mode, without a hint of its own.
void listenForSyncHints(
  BuildContext context,
  WidgetRef ref, {
  required String recordId,
  required bool isSet,
  VoidCallback? onDeleted,
}) {
  // Keeps the names loaded for the hint, without rebuilding the screen.
  ref.listen(personNamesProvider, (_, _) {});
  ref.listen(syncControllerProvider, (previous, next) {
    final report = next.lastReport;
    if (report == null || identical(report, previous?.lastReport)) return;
    final change = report.changes
        .where((c) => c.recordId == recordId && c.kind.isSet == isSet)
        // A deletion wins over a change in the same run.
        .fold<SyncChange?>(
          null,
          (found, c) => found != null && found.kind.isDeletion ? found : c,
        );
    if (change == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = syncHintText(
      AppLocalizations.of(context),
      change,
      ref.read(personNamesProvider)[change.userId],
    );
    if (change.kind.isDeletion) onDeleted?.call();
    if (next.afterLive || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: Key('sync-hint-${change.kind.name}'),
          content: Text(message),
        ),
      );
  });
}

/// After live mode: one hint sums up what others changed during the
/// performance, with a way to *Recent changes* (ADR-0045). Call from the
/// home screen's `build`.
void listenForLiveSummary(BuildContext context, WidgetRef ref) {
  ref.listen(syncControllerProvider, (previous, next) {
    final report = next.lastReport;
    if (!next.afterLive ||
        report == null ||
        identical(report, previous?.lastReport)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final summary = liveSummaryText(l10n, report.changes);
    if (summary == null) return;
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('sync-hint-after-live'),
          content: Text(summary),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.syncHintShowChanges,
            onPressed: () => navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => const RecentChangesScreen(),
              ),
            ),
          ),
        ),
      );
  });
}

/// Closes the page [context] is on, also when something is open on top
/// of it (a dialog, the editor).
void closeRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  Navigator.of(context).removeRoute(route);
}

/// The hint for [change] by [name] (null: not known on this device).
String syncHintText(AppLocalizations l10n, SyncChange change, String? name) {
  final title = change.title;
  if (name == null) {
    return switch (change.kind) {
      SyncChangeKind.songChanged => l10n.syncHintSongChangedAnonymous(title),
      SyncChangeKind.songDeleted => l10n.syncHintSongDeletedAnonymous(title),
      SyncChangeKind.setChanged => l10n.syncHintSetChangedAnonymous(title),
      SyncChangeKind.setDeleted => l10n.syncHintSetDeletedAnonymous(title),
    };
  }
  return switch (change.kind) {
    SyncChangeKind.songChanged => l10n.syncHintSongChanged(title, name),
    SyncChangeKind.songDeleted => l10n.syncHintSongDeleted(title, name),
    SyncChangeKind.setChanged => l10n.syncHintSetChanged(title, name),
    SyncChangeKind.setDeleted => l10n.syncHintSetDeleted(title, name),
  };
}

/// "While you were playing live: 1 song deleted, 2 songs changed", or null
/// when nothing changed. A song or set counts once, deleted if it was.
String? liveSummaryText(AppLocalizations l10n, List<SyncChange> changes) {
  final deleted = {
    for (final c in changes)
      if (c.kind.isDeletion) (c.kind.isSet, c.recordId),
  };
  final changed = {
    for (final c in changes)
      if (!c.kind.isDeletion && !deleted.contains((c.kind.isSet, c.recordId)))
        (c.kind.isSet, c.recordId),
  };
  int count(Set<(bool, String)> records, {required bool sets}) =>
      records.where((r) => r.$1 == sets).length;
  final parts = [
    for (final (n, text) in [
      (count(deleted, sets: false), l10n.syncHintSongsDeleted),
      (count(changed, sets: false), l10n.syncHintSongsChanged),
      (count(deleted, sets: true), l10n.syncHintSetsDeleted),
      (count(changed, sets: true), l10n.syncHintSetsChanged),
    ])
      if (n > 0) text(n),
  ];
  return parts.isEmpty ? null : l10n.syncHintAfterLive(parts.join(', '));
}
