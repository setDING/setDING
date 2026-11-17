import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'band_screen.dart';
import 'bands_screen.dart';
import 'invites_section.dart';

/// An organization (ADR-0017): its bands and people. Organization admins
/// rename it and manage people and their roles; everyone can leave.
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final org = (ref.watch(organizationsProvider).value ?? const [])
        .where((o) => o.id == organizationId)
        .firstOrNull;
    final me = ref.watch(authProvider);
    final people =
        ref.watch(orgMembersProvider(organizationId)).value ??
        const <OrgMembershipEntry>[];
    final bands = [
      for (final b in ref.watch(bandsProvider).value ?? const <BandView>[])
        if (b.organizationId == organizationId) b,
    ];
    final service = ref.read(bandServiceProvider);
    if (org == null || me == null) return Scaffold(appBar: AppBar());
    final own = people.where((p) => p.userId == me.id).firstOrNull;
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(org.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (org.isAdmin)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.orgName),
              subtitle: Text(org.name),
              onTap: () async {
                final name = await askText(
                  context,
                  title: l10n.orgName,
                  initial: org.name,
                );
                if (name == null || name == org.name || !context.mounted) {
                  return;
                }
                await runBandAction(
                  context,
                  () => service.renameOrganization(organizationId, name),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            subtitle: Text(l10n.orgSongsShared),
          ),
          header(l10n.orgBands),
          for (final b in bands)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(b.name),
              subtitle: Text(bandRoleLabel(l10n, b)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BandScreen(bandId: b.id),
                ),
              ),
            ),
          header(l10n.orgPeople),
          for (final p in people)
            _PersonTile(
              person: p,
              isAdmin: org.isAdmin,
              isMe: p.userId == me.id,
            ),
          if (org.isAdmin)
            InvitesSection(organizationId: organizationId)
          else
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              subtitle: Text(l10n.inviteAskAdmin),
            ),
          if (own != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: OutlinedButton.icon(
                key: const Key('org-leave'),
                icon: const Icon(Icons.logout),
                label: Text(l10n.orgLeave),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: l10n.orgLeaveTitle(org.name),
                    message: l10n.orgLeaveMessage,
                    action: l10n.orgLeave,
                  );
                  if (!ok || !context.mounted) return;
                  final left = await runBandAction(
                    context,
                    () => service.removeOrgMember(own.id),
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

class _PersonTile extends ConsumerWidget {
  const _PersonTile({
    required this.person,
    required this.isAdmin,
    required this.isMe,
  });

  final OrgMembershipEntry person;

  /// The signed-in user is an admin of the organization.
  final bool isAdmin;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(bandServiceProvider);
    final name = person.userName.isEmpty
        ? (person.userEmail ?? '?')
        : person.userName;
    final admin = person.role == OrgRole.admin;
    Future<void> setRole(OrgRole role) =>
        runBandAction(context, () => service.setOrgRole(person.id, role));

    return ListTile(
      leading: Icon(admin ? Icons.shield_outlined : Icons.person_outline),
      title: Text(isMe ? l10n.bandYou(name) : name),
      subtitle: Text(orgRoleLabel(l10n, person.role)),
      trailing: !isAdmin
          ? null
          : PopupMenuButton<String>(
              key: Key('person-menu-${person.id}'),
              onSelected: (value) async {
                switch (value) {
                  case 'admin':
                    await setRole(OrgRole.admin);
                  case 'librarian':
                    await setRole(OrgRole.librarian);
                  case 'member':
                    await setRole(OrgRole.member);
                  case 'remove':
                    final ok = await confirm(
                      context,
                      title: l10n.orgRemoveTitle(name),
                      message: l10n.orgRemoveMessage(name),
                      action: l10n.orgRemove,
                    );
                    if (ok && context.mounted) {
                      await runBandAction(
                        context,
                        () => service.removeOrgMember(person.id),
                      );
                    }
                }
              },
              itemBuilder: (_) => [
                if (person.role != OrgRole.admin)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(l10n.bandMakeAdmin),
                  ),
                if (person.role != OrgRole.librarian)
                  PopupMenuItem(
                    value: 'librarian',
                    child: Text(l10n.orgMakeLibrarian),
                  ),
                if (person.role != OrgRole.member)
                  PopupMenuItem(
                    value: 'member',
                    child: Text(l10n.bandMakeMember),
                  ),
                if (!isMe)
                  PopupMenuItem(value: 'remove', child: Text(l10n.orgRemove)),
              ],
            ),
    );
  }
}
