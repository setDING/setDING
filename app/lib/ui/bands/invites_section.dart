import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../widgets/dialogs.dart';
import 'bands_screen.dart';

/// Invitation links of an organization (organization admins).
final invitesProvider = FutureProvider.autoDispose
    .family<List<InviteInfo>, String>(
      (ref, orgId) => ref.watch(syncBackendProvider).fetchInvites(orgId),
    );

/// "Invite people" and the list of links of an organization (ADR-0005,
/// ADR-0017): links are valid for 7 days, can be used several times and be
/// revoked; admins see who joined with which link.
class InvitesSection extends ConsumerWidget {
  const InvitesSection({super.key, required this.organizationId});

  final String organizationId;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    CreatedInvite? invite;
    final ok = await runBandAction(
      context,
      () async => invite = await ref
          .read(syncBackendProvider)
          .createInvite(organizationId),
    );
    ref.invalidate(invitesProvider(organizationId));
    if (!ok || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InviteLinkDialog(invite: invite!),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final invites =
        ref.watch(invitesProvider(organizationId)).value ?? const [];
    final now = DateTime.now();
    final date = MaterialLocalizations.of(context).formatMediumDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('invite-create'),
          leading: const Icon(Icons.person_add_alt),
          title: Text(l10n.inviteCreate),
          subtitle: Text(l10n.inviteCreateHint),
          onTap: () => _create(context, ref),
        ),
        if (invites.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.invitesTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        for (final i in invites)
          ListTile(
            key: Key('invite-${i.id}'),
            leading: Icon(switch (i.statusAt(now)) {
              InviteStatus.valid => Icons.link,
              InviteStatus.expired => Icons.timer_off_outlined,
              InviteStatus.revoked => Icons.link_off,
            }),
            title: Text(switch (i.statusAt(now)) {
              InviteStatus.valid => l10n.inviteStatusValid(
                date(i.expires.toLocal()),
              ),
              InviteStatus.expired => l10n.inviteStatusExpired,
              InviteStatus.revoked => l10n.inviteStatusRevoked,
            }),
            subtitle: Text(
              l10n.inviteJoined(i.joined.length, i.joined.join(', ')),
            ),
            trailing: i.statusAt(now) != InviteStatus.valid
                ? null
                : TextButton(
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
                      ref.invalidate(invitesProvider(organizationId));
                    },
                    child: Text(l10n.inviteRevoke),
                  ),
          ),
      ],
    );
  }
}

/// Shows a new link once: as text to copy and as a QR code for joining in
/// person at a rehearsal.
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
