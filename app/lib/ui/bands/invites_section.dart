import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../widgets/dialogs.dart';
import 'bands_screen.dart';
import '../widgets/section_header.dart';

/// Invitation links of an organization (organization admins), or of one
/// of its bands (band leaders, ADR-0023).
final invitesProvider = FutureProvider.autoDispose
    .family<List<InviteInfo>, ({String org, String? band})>(
      (ref, key) => ref
          .watch(syncBackendProvider)
          .fetchInvites(key.org, bandId: key.band),
    );

/// "Invite people" and the list of links of an organization (ADR-0005,
/// ADR-0017): links are valid for 7 days, can be used several times and be
/// revoked; admins see the valid ones with their band and who joined, and
/// can show a link again (issue #579).
class InvitesSection extends ConsumerWidget {
  const InvitesSection({super.key, required this.organizationId, this.bandId});

  final String organizationId;

  /// Links into this band: people join the organization and the band.
  final String? bandId;

  ({String org, String? band}) get _key => (org: organizationId, band: bandId);

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    CreatedInvite? invite;
    final ok = await runBandAction(
      context,
      () async => invite = await ref
          .read(syncBackendProvider)
          .createInvite(organizationId, bandId: bandId),
    );
    ref.invalidate(invitesProvider(_key));
    if (!ok || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InviteLinkDialog(invite: invite!),
    );
  }

  /// Shows a valid link again, with its QR code (issue #579).
  Future<void> _show(BuildContext context, WidgetRef ref, String id) async {
    CreatedInvite? invite;
    final ok = await runBandAction(
      context,
      () async =>
          invite = await ref.read(syncBackendProvider).fetchInviteLink(id),
    );
    if (!ok) {
      // Revoked or expired meanwhile: drop it from the list.
      ref.invalidate(invitesProvider(_key));
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InviteLinkDialog(invite: invite!),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The server lists only valid links (issue #579).
    final invites = ref.watch(invitesProvider(_key)).value ?? const [];
    final date = MaterialLocalizations.of(context).formatMediumDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('invite-create'),
          leading: const Icon(Icons.person_add_alt),
          title: Text(l10n.inviteCreate),
          subtitle: Text(
            bandId == null ? l10n.inviteCreateHint : l10n.inviteBandHint,
          ),
          onTap: () => _create(context, ref),
        ),
        if (invites.isNotEmpty) SectionHeader(l10n.invitesTitle),
        for (final i in invites) _inviteTile(context, ref, i, l10n, date),
      ],
    );
  }

  Widget _inviteTile(
    BuildContext context,
    WidgetRef ref,
    InviteInfo i,
    AppLocalizations l10n,
    String Function(DateTime) date,
  ) {
    // When the link was created and until when it is valid (issue #637).
    final dates = l10n.inviteDates(
      date(i.created.toLocal()),
      date(i.expires.toLocal()),
    );
    return ListTile(
      key: Key('invite-${i.id}'),
      leading: const Icon(Icons.link),
      // In the organization, say where the link leads; in a band,
      // that is the band itself.
      title: Text(
        bandId != null ? dates : (i.bandName ?? l10n.inviteOrganizationOnly),
      ),
      subtitle: Text(
        bandId != null
            ? l10n.inviteJoined(i.joined.length, i.joined.join(', '))
            : '$dates · '
                  '${l10n.inviteJoined(i.joined.length, i.joined.join(', '))}',
      ),
      onTap: () => _show(context, ref, i.id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('invite-show-${i.id}'),
            tooltip: l10n.inviteShow,
            icon: const Icon(Icons.qr_code),
            onPressed: () => _show(context, ref, i.id),
          ),
          TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: l10n.inviteRevokeTitle,
                message: l10n.inviteRevokeMessage,
                action: l10n.inviteRevoke,
              );
              if (!ok || !context.mounted) return;
              await runBandAction(
                context,
                () => ref.read(syncBackendProvider).revokeInvite(i.id),
              );
              ref.invalidate(invitesProvider(_key));
            },
            child: Text(l10n.inviteRevoke),
          ),
        ],
      ),
    );
  }
}

/// Shows a link as text to copy and as a QR code for joining in person at a
/// rehearsal.
class InviteLinkDialog extends StatelessWidget {
  const InviteLinkDialog({super.key, required this.invite});

  final CreatedInvite invite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(invite.expires.toLocal());
    return AlertDialog(
      title: Text(l10n.inviteLinkTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  key: const Key('invite-qr'),
                  data: invite.url,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(invite.url, key: const Key('invite-url')),
              const SizedBox(height: 12),
              Text(l10n.inviteLinkHint(date)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(l10n.inviteCopy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.url));
            if (context.mounted) showMessage(context, l10n.inviteCopied);
          },
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
