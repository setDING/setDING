import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../data/trash.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../account/sign_in_screen.dart' show backendErrorText;
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';
import 'bands_screen.dart';
import '../widgets/loading_indicator.dart';

/// Deletes [band] after a confirmation that shows what goes with it and
/// asks for the band's name (organization admins, ADR-0044). Closes the
/// band's screen and offers "Undo".
Future<void> deleteBand(
  BuildContext context,
  WidgetRef ref,
  BandView band, {
  required int members,
}) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(databaseProvider);
  final sets =
      await (db.selectOnly(db.setlists)
            ..addColumns([db.setlists.id.count()])
            ..where(
              db.setlists.bandId.equals(band.id) &
                  db.setlists.deleted.equals(false),
            ))
          .map((r) => r.read(db.setlists.id.count()) ?? 0)
          .getSingle();
  int? invites;
  try {
    final now = DateTime.now();
    invites =
        (await ref
                .read(syncBackendProvider)
                .fetchInvites(band.organizationId!, bandId: band.id))
            .where((i) => i.statusAt(now) == InviteStatus.valid)
            .length;
  } on BackendException {
    invites = null; // Offline: the deletion fails anyway.
  }
  final lastBand =
      (ref.read(bandsProvider).value ?? const <BandView>[])
          .where((b) => b.organizationId == band.organizationId)
          .length <=
      1;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DeleteBandDialog(
      band: band,
      summary: [
        l10n.bandDeleteSets(sets),
        l10n.bandDeleteMembers(members),
        if (invites != null) l10n.bandDeleteInvites(invites),
      ].join(' · '),
      lastBand: lastBand,
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final service = ref.read(bandServiceProvider);
  final deleted = await runBandAction(
    context,
    () => service.deleteBand(band.id),
  );
  if (!deleted) return;
  navigator.pop();
  showUndo(
    messenger,
    l10n.bandDeleted(band.name),
    undoLabel: l10n.undo,
    onUndo: () async {
      try {
        await service.restoreBand(band.id);
      } on BackendException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(backendErrorText(l10n, e.kind))),
        );
      }
    },
  );
}

class _DeleteBandDialog extends StatefulWidget {
  const _DeleteBandDialog({
    required this.band,
    required this.summary,
    required this.lastBand,
  });

  final BandView band;
  final String summary;
  final bool lastBand;

  @override
  State<_DeleteBandDialog> createState() => _DeleteBandDialogState();
}

class _DeleteBandDialogState extends State<_DeleteBandDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _confirmed => _name.text.trim() == widget.band.name.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.bandDeleteTitle(widget.band.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.summary,
              key: const Key('band-delete-summary'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Text(l10n.bandDeleteMessage(trashRetention.inDays)),
            if (widget.lastBand) ...[
              const SizedBox(height: 12),
              Text(l10n.bandDeleteLastBand, key: const Key('band-delete-last')),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('band-delete-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.bandDeleteConfirmName(widget.band.name),
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
          key: const Key('band-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// The deleted bands of an organization that can still be restored, for
/// its admins (ADR-0044). Loaded from the server, so it needs a connection.
class DeletedBandsScreen extends ConsumerStatefulWidget {
  const DeletedBandsScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<DeletedBandsScreen> createState() => _DeletedBandsScreenState();
}

class _DeletedBandsScreenState extends ConsumerState<DeletedBandsScreen> {
  late Future<List<DeletedBand>> _bands = _load();

  Future<List<DeletedBand>> _load() =>
      ref.read(bandServiceProvider).deletedBands(widget.organizationId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = trashRetention.inDays;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashBandsTitle)),
      body: FutureBuilder<List<DeletedBand>>(
        future: _bands,
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
          final bands = snapshot.data;
          if (bands == null) {
            return const LoadingIndicator();
          }
          if (bands.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              message: l10n.trashBandsEmpty(days),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.trashBandsHint(days),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final b in bands) _tile(context, b),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, DeletedBand band) {
    final l10n = AppLocalizations.of(context);
    final left = TrashRepository.restorableUntil(band.deletedAt)
        .difference(DateTime.now());
    // Started days count: deleted just now is "30 days left".
    final daysLeft = left.isNegative ? 0 : (left.inMinutes / (24 * 60)).ceil();
    return ListTile(
      key: ValueKey('trash-band-${band.id}'),
      leading: const Icon(Icons.groups_outlined),
      title: Text(band.name),
      subtitle: Text(
        [
          l10n.trashDeletedOn(formatGigDate(context, band.deletedAt.toLocal())),
          l10n.trashDaysLeft(daysLeft),
        ].join(' · '),
      ),
      trailing: TextButton(
        key: ValueKey('trash-band-restore-${band.id}'),
        onPressed: () async {
          final ok = await runBandAction(
            context,
            () => ref.read(bandServiceProvider).restoreBand(band.id),
          );
          if (!ok || !mounted) return;
          final reloaded = _load();
          setState(() {
            _bands = reloaded;
          });
          if (context.mounted) {
            showMessage(context, l10n.trashRestored(band.name));
          }
        },
        child: Text(l10n.trashRestore),
      ),
    );
  }
}
