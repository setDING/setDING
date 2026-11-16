import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'bands_screen.dart';

/// Settings and members of one band. Band and organization admins rename
/// the band, allow members to edit songs, add people of the organization,
/// change roles and remove members; members can leave (ADR-0005, ADR-0017).
class BandScreen extends ConsumerWidget {
  const BandScreen({super.key, required this.bandId});

  final String bandId;

  Future<void> _addMember(
    BuildContext context,
    WidgetRef ref,
    BandView band,
    List<MembershipEntry> members,
  ) async {
    final l10n = AppLocalizations.of(context);
    final people =
        ref.read(orgMembersProvider(band.organizationId!)).value ??
        const <OrgMembershipEntry>[];
    final candidates = [
      for (final p in people)
        if (!members.any((m) => m.userId == p.userId)) p,
    ];
    if (candidates.isEmpty) {
      showMessage(context, l10n.bandAddMemberNone);
      return;
    }
    final person = await showDialog<OrgMembershipEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.bandAddMemberTitle),
        children: [
          for (final p in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  p.userName.isEmpty ? (p.userEmail ?? '?') : p.userName,
                ),
              ),
            ),
        ],
      ),
    );
    if (person == null || !context.mounted) return;
    await runBandAction(
      context,
      () => ref
          .read(bandServiceProvider)
          .addBandMember(bandId, person.userId, BandRole.member),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final band = (ref.watch(bandsProvider).value ?? const <BandView>[])
        .where((b) => b.id == bandId)
        .firstOrNull;
    final me = ref.watch(authProvider);
    final members =
        ref.watch(bandMembersProvider(bandId)).value ??
        const <MembershipEntry>[];
    final service = ref.read(bandServiceProvider);

    // The band is gone (left, removed or signed out).
    if (band == null || me == null || band.isLocal) {
      return Scaffold(appBar: AppBar());
    }
    // Load the organization's people for "add member".
    ref.watch(orgMembersProvider(band.organizationId!));
    final own = members.where((m) => m.userId == me.id).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(bandLabel(l10n, band))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.domain),
            title: Text(l10n.bandOrganization),
            subtitle: Text(band.organizationName),
          ),
          if (band.canManageBand) ...[
            if (band.role == null)
              ListTile(
                leading: const Icon(Icons.info_outline),
                subtitle: Text(l10n.bandOrgAdminHint),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.bandName),
              subtitle: Text(band.name),
              onTap: () async {
                final name = await askText(
                  context,
                  title: l10n.bandName,
                  initial: band.name,
                );
                if (name == null || name == band.name || !context.mounted) {
                  return;
                }
                await runBandAction(
                  context,
                  () => service.renameBand(bandId, name),
                );
              },
            ),
            SwitchListTile(
              key: const Key('band-members-can-edit'),
              secondary: const Icon(Icons.edit_note),
              title: Text(l10n.bandMembersCanEdit),
              subtitle: Text(l10n.bandMembersCanEditHint),
              value: band.membersCanEditSongs,
              onChanged: (v) => runBandAction(
                context,
                () => service.setMembersCanEditSongs(bandId, v),
              ),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(bandRoleLabel(l10n, band)),
              subtitle: band.membersCanEditSongs
                  ? Text(l10n.bandMembersCanEdit)
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              l10n.bandMembers,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          for (final m in members)
            _MemberTile(member: m, band: band, isMe: m.userId == me.id),
          if (band.canManageBand)
            ListTile(
              key: const Key('band-add-member'),
              leading: const Icon(Icons.person_add_alt),
              title: Text(l10n.bandAddMember),
              onTap: () => _addMember(context, ref, band, members),
            ),
          if (own != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: OutlinedButton.icon(
                key: const Key('band-leave'),
                icon: const Icon(Icons.logout),
                label: Text(l10n.bandLeave),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: l10n.bandLeaveTitle(band.name),
                    message: l10n.bandLeaveMessage,
                    action: l10n.bandLeave,
                  );
                  if (!ok || !context.mounted) return;
                  final left = await runBandAction(
                    context,
                    () => service.removeMember(own.id),
                  );
                  if (left && context.mounted) Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.band,
    required this.isMe,
  });

  final MembershipEntry member;
  final BandView band;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(bandServiceProvider);
    final name = member.userName.isEmpty
        ? (member.userEmail ?? '?')
        : member.userName;
    final isAdmin = member.role == BandRole.admin;

    return ListTile(
      leading: Icon(isAdmin ? Icons.shield_outlined : Icons.person_outline),
      title: Text(isMe ? l10n.bandYou(name) : name),
      subtitle: Text(roleLabel(l10n, member.role)),
      trailing: !band.canManageBand
          ? null
          : PopupMenuButton<String>(
              key: Key('member-menu-${member.id}'),
              onSelected: (value) async {
                switch (value) {
                  case 'admin':
                    await runBandAction(
                      context,
                      () => service.setRole(member.id, BandRole.admin),
                    );
                  case 'member':
                    await runBandAction(
                      context,
                      () => service.setRole(member.id, BandRole.member),
                    );
                  case 'remove':
                    final ok = await confirm(
                      context,
                      title: l10n.bandRemoveTitle(name),
                      message: l10n.bandRemoveMessage(name),
                      action: l10n.bandRemoveMember,
                    );
                    if (ok && context.mounted) {
                      await runBandAction(
                        context,
                        () => service.removeMember(member.id),
                      );
                    }
                }
              },
              itemBuilder: (_) => [
                if (!isAdmin)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(l10n.bandMakeAdmin),
                  ),
                if (isAdmin)
                  PopupMenuItem(
                    value: 'member',
                    child: Text(l10n.bandMakeMember),
                  ),
                if (!isMe)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(l10n.bandRemoveMember),
                  ),
              ],
            ),
    );
  }
}
