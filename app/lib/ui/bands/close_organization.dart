import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../data/trash.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/sync_backend.dart';
import '../../sync/sync_controller.dart';
import '../account/sign_in_screen.dart' show backendErrorText;
import '../backup/backup_actions.dart' show exportBackup;
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';
import 'bands_screen.dart';

/// Closes [org] after a confirmation that shows what goes with it, offers a
/// backup first and asks for the organization's name (its admins,
/// ADR-0044). Closes the organization's screen and offers "Undo".
Future<void> closeOrganization(
  BuildContext context,
  WidgetRef ref,
  OrganizationView org, {
  required int people,
  required int bands,
}) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(databaseProvider);
  final songs =
      await (db.selectOnly(db.songs)
            ..addColumns([db.songs.id.count()])
            ..where(
              db.songs.libraryId.equals(org.id) &
                  db.songs.deleted.equals(false),
            ))
          .map((r) => r.read(db.songs.id.count()) ?? 0)
          .getSingle();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _CloseOrganizationDialog(
      org: org,
      summary: [
        l10n.orgCloseBands(bands),
        l10n.orgCloseSongs(songs),
        l10n.orgClosePeople(people),
      ].join(' · '),
      backUp: () =>
          exportBackup(context, ref, ref.read(libraryProvider(org.id))),
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final service = ref.read(bandServiceProvider);
  // Read now: the organization's screen is gone when "Undo" is tapped.
  final sync = ref.read(syncControllerProvider.notifier);
  final closed = await runBandAction(
    context,
    () => service.closeOrganization(org.id),
  );
  if (!closed) return;
  navigator.pop();
  showUndo(
    messenger,
    l10n.orgClosed(org.name),
    undoLabel: l10n.undo,
    onUndo: () async {
      try {
        await service.restoreOrganization(org.id);
        // Its songs and sets come back from the server.
        await sync.syncNow();
      } on BackendException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(backendErrorText(l10n, e.kind))),
        );
      }
    },
  );
}

class _CloseOrganizationDialog extends StatefulWidget {
  const _CloseOrganizationDialog({
    required this.org,
    required this.summary,
    required this.backUp,
  });

  final OrganizationView org;
  final String summary;
  final Future<void> Function() backUp;

  @override
  State<_CloseOrganizationDialog> createState() =>
      _CloseOrganizationDialogState();
}

class _CloseOrganizationDialogState extends State<_CloseOrganizationDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _confirmed => _name.text.trim() == widget.org.name.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.orgCloseTitle(widget.org.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.summary,
              key: const Key('org-close-summary'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Text(l10n.orgCloseMessage(trashRetention.inDays)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('org-close-backup'),
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.orgCloseBackup),
              onPressed: widget.backUp,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('org-close-name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.bandDeleteConfirmName(widget.org.name),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_confirmed) Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('org-close-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.orgClose),
        ),
      ],
    );
  }
}

/// The closed organizations of the signed-in user that can still be
/// restored; their admins restore them here (ADR-0044). Loaded from the
/// server, so it needs a connection.
class ClosedOrganizationsScreen extends ConsumerStatefulWidget {
  const ClosedOrganizationsScreen({super.key});

  @override
  ConsumerState<ClosedOrganizationsScreen> createState() =>
      _ClosedOrganizationsScreenState();
}

class _ClosedOrganizationsScreenState
    extends ConsumerState<ClosedOrganizationsScreen> {
  late Future<List<ClosedOrganization>> _orgs = _load();

  Future<List<ClosedOrganization>> _load() =>
      ref.read(bandServiceProvider).closedOrganizations();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = trashRetention.inDays;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orgsClosedTitle)),
      body: FutureBuilder<List<ClosedOrganization>>(
        future: _orgs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              message: error is BackendException
                  ? backendErrorText(l10n, error.kind)
                  : '$error',
            );
          }
          final orgs = snapshot.data;
          if (orgs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orgs.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              message: l10n.orgsClosedEmpty(days),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.orgsClosedHint(days),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final o in orgs) _tile(context, o),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, ClosedOrganization org) {
    final l10n = AppLocalizations.of(context);
    final left = TrashRepository.restorableUntil(org.closedAt)
        .difference(DateTime.now());
    // Started days count: closed just now is "30 days left".
    final daysLeft = left.isNegative ? 0 : (left.inMinutes / (24 * 60)).ceil();
    return ListTile(
      key: ValueKey('closed-org-${org.id}'),
      leading: const Icon(Icons.domain_disabled),
      title: Text(org.name),
      subtitle: Text(
        [
          l10n.orgClosedOn(formatGigDate(context, org.closedAt.toLocal())),
          if (org.closedBy case final name?) l10n.orgClosedBy(name),
          l10n.trashDaysLeft(daysLeft),
        ].join(' · '),
      ),
      trailing: !org.isAdmin
          ? null
          : TextButton(
              key: ValueKey('closed-org-restore-${org.id}'),
              onPressed: () async {
                final ok = await runBandAction(
                  context,
                  () =>
                      ref.read(bandServiceProvider).restoreOrganization(org.id),
                );
                if (!ok || !mounted) return;
                final reloaded = _load();
                setState(() {
                  _orgs = reloaded;
                });
                if (context.mounted) {
                  showMessage(context, l10n.trashRestored(org.name));
                }
                // Its songs and sets come back from the server.
                await ref.read(syncControllerProvider.notifier).syncNow();
              },
              child: Text(l10n.trashRestore),
            ),
    );
  }
}
