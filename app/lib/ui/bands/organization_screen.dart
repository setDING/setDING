import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/person_name.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart' show nameFormatProvider;
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'close_organization.dart';
import 'contacts_section.dart';
import 'bands_screen.dart';
import 'invites_section.dart';
import '../widgets/danger_zone.dart';
import '../widgets/docs_link.dart';
import '../widgets/section_header.dart';
import '../widgets/page_width.dart';
import '../widgets/menu_action.dart';
import '../routes.dart';

/// An organization (ADR-0017): its bands and people. Organization admins
/// rename it, create bands in it and manage people and their roles;
/// everyone can leave.
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

    return Scaffold(
      appBar: AppBar(title: Text(org.name)),
      body: RefreshOnOpen(
        child: PageWidth(
          child: ListView(
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
              SectionHeader(l10n.orgBands),
              for (final b in bands)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(b.name),
                  subtitle: Text(bandRoleLabel(l10n, b)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push<void>(AppPaths.band(b.id)),
                ),
              // Organization admins create bands here (ADR-0017, ADR-0023).
              if (org.isAdmin)
                ListTile(
                  key: const Key('org-band-new'),
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(l10n.bandNew),
                  onTap: () async {
                    final name = (await askText(
                      context,
                      title: l10n.bandNew,
                      label: l10n.bandName,
                    ))?.trim();
                    if (name == null || name.isEmpty || !context.mounted) {
                      return;
                    }
                    late String id;
                    final ok = await runBandAction(
                      context,
                      () async => id = await service.createBand(
                        name,
                        organizationId: organizationId,
                      ),
                    );
                    if (!ok || !context.mounted) return;
                    await context.push<void>(AppPaths.band(id));
                  },
                ),
              // Deleted bands, restorable for 30 days (ADR-0044).
              if (org.isAdmin)
                ListTile(
                  key: const Key('org-deleted-bands'),
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.trashBandsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push<void>(AppPaths.deletedBands(organizationId)),
                ),
              // What the roles may do (#993).
              SectionHeader(
                l10n.orgPeople,
                trailing: DocsHelpButton(
                  key: const Key('roles-docs'),
                  page: DocsPage.roles,
                  topic: l10n.orgPeople,
                ),
              ),
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
              // People without an account (ADR-0064), for set editors.
              if (canEditContacts(org, bands))
                ContactsSection(org: org, bands: bands),
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
              // Its admins close the organization (ADR-0044).
              if (org.canClose)
                DangerZone(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: OutlinedButton.icon(
                        key: const Key('org-close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: const Icon(Icons.domain_disabled),
                        label: Text(l10n.orgClose),
                        onPressed: () => closeOrganization(
                          context,
                          ref,
                          org,
                          people: people.length,
                          bands: bands.length,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
    final format = ref.watch(nameFormatProvider);
    final name = personLabel(person.person, format, email: person.userEmail);
    // The full name under the shown one when it says more (ADR-0062).
    final full = person.person.fullName;
    final admin = person.role == OrgRole.admin;
    Future<void> setRole(OrgRole role) =>
        runBandAction(context, () => service.setOrgRole(person.id, role));

    return ListTile(
      leading: Icon(admin ? Icons.shield_outlined : Icons.person_outline),
      title: Text(isMe ? l10n.bandYou(name) : name),
      subtitle: Text(
        [
          if (full.isNotEmpty && !name.contains(full)) full,
          orgRoleLabel(l10n, person.role),
        ].join(' · '),
      ),
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
                  MenuAction(
                    value: 'admin',
                    icon: Icons.admin_panel_settings_outlined,
                    label: l10n.bandMakeAdmin,
                  ),
                if (person.role != OrgRole.librarian)
                  MenuAction(
                    value: 'librarian',
                    icon: Icons.local_library_outlined,
                    label: l10n.orgMakeLibrarian,
                  ),
                if (person.role != OrgRole.member)
                  MenuAction(
                    value: 'member',
                    icon: Icons.person_outline,
                    label: l10n.bandMakeMember,
                  ),
                if (!isMe) ...[
                  const PopupMenuDivider(),
                  MenuAction(
                    value: 'remove',
                    icon: Icons.person_remove_outlined,
                    label: l10n.orgRemove,
                    destructive: true,
                  ),
                ],
              ],
            ),
    );
  }
}
