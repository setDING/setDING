import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/person_name.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart' show nameFormatProvider;
import '../../sync/auth_providers.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'bands_screen.dart';
import 'delete_band.dart';
import 'invites_section.dart';
import '../widgets/danger_zone.dart';
import '../widgets/docs_link.dart';
import '../widgets/section_header.dart';
import '../widgets/page_width.dart';
import '../widgets/menu_action.dart';

/// Settings and members of one band. Band leaders and organization admins
/// rename the band, add people of the organization, invite new people into
/// the band, change roles and remove members; members can leave (ADR-0005,
/// ADR-0017, ADR-0023).
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
    final format = ref.read(nameFormatProvider);
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
                title: Text(personLabel(p.person, format, email: p.userEmail)),
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
      body: RefreshOnOpen(
        child: PageWidth(
          child: ListView(
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
              ] else if (band.substitute)
                // Only some sets of the band, read-only (ADR-0061).
                ListTile(
                  key: const Key('band-substitute-hint'),
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(bandRoleLabel(l10n, band)),
                  subtitle: Text(l10n.bandSubstituteHint),
                )
              else
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(bandRoleLabel(l10n, band)),
                  subtitle: band.role == BandRole.planner
                      ? Text(l10n.bandPlannerHint)
                      : null,
                ),
              // What the roles may do (#993); a substitute sees no members.
              if (!band.substitute)
                SectionHeader(
                  l10n.bandMembers,
                  trailing: DocsHelpButton(
                    key: const Key('roles-docs'),
                    page: DocsPage.roles,
                    topic: l10n.bandMembers,
                  ),
                ),
              for (final m in members)
                _MemberTile(member: m, band: band, isMe: m.userId == me.id),
              if (band.canManageBand) ...[
                ListTile(
                  key: const Key('band-add-member'),
                  leading: const Icon(Icons.person_add_alt),
                  title: Text(l10n.bandAddMember),
                  onTap: () => _addMember(context, ref, band, members),
                ),
                // New people straight into this band (ADR-0023).
                InvitesSection(
                  organizationId: band.organizationId!,
                  bandId: band.id,
                ),
              ],
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
              // Organization admins delete the band (ADR-0044).
              if (band.canDeleteBand)
                DangerZone(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: OutlinedButton.icon(
                        key: const Key('band-delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.bandDelete),
                        onPressed: () => deleteBand(
                          context,
                          ref,
                          band,
                          members: members.length,
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
    final format = ref.watch(nameFormatProvider);
    final name = personLabel(member.person, format, email: member.userEmail);
    // The full name under the shown one when it says more (ADR-0062).
    final full = member.person.fullName;
    final isAdmin = member.role == BandRole.admin;
    Future<void> setRole(BandRole role) =>
        runBandAction(context, () => service.setRole(member.id, role));

    return ListTile(
      leading: Icon(isAdmin ? Icons.shield_outlined : Icons.person_outline),
      title: Text(isMe ? l10n.bandYou(name) : name),
      subtitle: Text(
        [
          if (full.isNotEmpty && !name.contains(full)) full,
          roleLabel(l10n, member.role),
        ].join(' · '),
      ),
      trailing: !band.canManageBand
          ? null
          : PopupMenuButton<String>(
              key: Key('member-menu-${member.id}'),
              onSelected: (value) async {
                switch (value) {
                  case 'admin':
                    await setRole(BandRole.admin);
                  case 'planner':
                    await setRole(BandRole.planner);
                  case 'member':
                    await setRole(BandRole.member);
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
                if (member.role != BandRole.admin)
                  MenuAction(
                    value: 'admin',
                    icon: Icons.admin_panel_settings_outlined,
                    label: l10n.bandMakeLeader,
                  ),
                if (member.role != BandRole.planner)
                  MenuAction(
                    value: 'planner',
                    icon: Icons.edit_calendar_outlined,
                    label: l10n.bandMakePlanner,
                  ),
                if (member.role != BandRole.member)
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
                    label: l10n.bandRemoveMember,
                    destructive: true,
                  ),
                ],
              ],
            ),
    );
  }
}
