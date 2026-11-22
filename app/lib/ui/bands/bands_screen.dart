import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../account/account_section.dart';
import '../account/sign_in_screen.dart' show backendErrorText;
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'band_screen.dart';
import 'close_organization.dart';
import 'join_screen.dart';
import 'organization_screen.dart';
import '../widgets/page_width.dart';

/// Runs a band action and shows backend errors as a message.
Future<bool> runBandAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on BackendException catch (e) {
    showMessageOn(messenger, backendErrorText(l10n, e.kind));
    return false;
  }
}

/// A screen of people (organization, band): reloads the organizations and
/// bands from the server when it opens, whatever the sync mode, so people
/// who joined meanwhile show up without a restart, and on pull-to-refresh.
/// Without a connection the stored state stays and nothing is shown.
class RefreshOnOpen extends ConsumerStatefulWidget {
  const RefreshOnOpen({super.key, required this.child});

  /// The scrollable content.
  final Widget child;

  @override
  ConsumerState<RefreshOnOpen> createState() => _RefreshOnOpenState();
}

class _RefreshOnOpenState extends ConsumerState<RefreshOnOpen> {
  @override
  void initState() {
    super.initState();
    // Concurrent refreshes share one request (BandService.refresh).
    unawaited(
      ref.read(bandServiceProvider).refresh().then((_) {}, onError: (_) {}),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () =>
        runBandAction(context, ref.read(bandServiceProvider).refresh),
    child: widget.child,
  );
}

/// Whether the signed-in user may create a band: new organizations only on
/// open servers; on invite-only servers they come from founder invitations
/// (ADR-0024), so bands only inside organizations the user administers. An
/// unknown mode counts as not open (issue #829).
bool canCreateBand(WidgetRef ref) {
  final user = ref.watch(authProvider);
  final orgs = ref.watch(organizationsProvider).value ?? const [];
  final open = ref.watch(serverConfigProvider).value?.openRegistration ?? false;
  return user != null && (open || orgs.any((o) => o.isAdmin));
}

/// Asks for a new band and creates it, then selects it.
Future<void> createBand(BuildContext context, WidgetRef ref) async {
  final orgs = ref.read(organizationsProvider).value ?? const [];
  final open = ref.read(serverConfigProvider).value?.openRegistration ?? false;
  final adminOrgs = [
    for (final o in orgs)
      if (o.isAdmin) o,
  ];
  final result = await showDialog<({String name, String? orgId})>(
    context: context,
    builder: (_) =>
        _NewBandDialog(organizations: adminOrgs, newOrganization: open),
  );
  if (result == null || !context.mounted) return;
  late String id;
  final ok = await runBandAction(
    context,
    () async => id = await ref
        .read(bandServiceProvider)
        .createBand(result.name, organizationId: result.orgId),
  );
  if (!ok || !context.mounted) return;
  await ref.read(selectedBandIdProvider.notifier).select(id);
}

/// The organizations of the signed-in user, each followed by its bands
/// (ADR-0005, ADR-0017); a tap opens the organization or band. Admin
/// actions are offered there depending on the role (ADR-0023).
class OrganizationBandTiles extends ConsumerWidget {
  const OrganizationBandTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final orgs = ref.watch(organizationsProvider).value ?? const [];
    final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
    final current = ref.watch(currentBandProvider);
    return Column(
      children: [
        for (final o in orgs) ...[
          ListTile(
            key: Key('org-${o.id}'),
            leading: const Icon(Icons.domain),
            title: Text(o.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              o.isAdmin ? l10n.bandRoleOrgAdmin : l10n.bandRoleMember,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrganizationScreen(organizationId: o.id),
              ),
            ),
          ),
          for (final b in bands)
            if (b.organizationId == o.id)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 56, right: 16),
                leading: Icon(
                  b.id == current.id
                      ? Icons.check_circle
                      : Icons.groups_outlined,
                ),
                title: Text(bandLabel(l10n, b)),
                subtitle: Text(bandRoleLabel(l10n, b)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BandScreen(bandId: b.id),
                  ),
                ),
              ),
          const Divider(),
        ],
      ],
    );
  }
}

/// The organizations and bands of the signed-in user (ADR-0005, ADR-0017).
class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider);
    final orgs = ref.watch(organizationsProvider).value ?? const [];
    final service = ref.read(bandServiceProvider);
    final canCreate = canCreateBand(ref);

    Widget body;
    if (user == null) {
      body = EmptyState(
        icon: Icons.groups_outlined,
        message: l10n.bandsSignInHint,
        action: const SignedOutActions(),
      );
    } else if (orgs.isEmpty) {
      body = EmptyState(icon: Icons.groups_outlined, message: l10n.bandsEmpty);
    } else {
      body = RefreshIndicator(
        onRefresh: () => runBandAction(context, service.refresh),
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: const [OrganizationBandTiles()],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bandsTitle),
        actions: [
          IconButton(
            key: const Key('band-join'),
            tooltip: l10n.joinTitle,
            icon: const Icon(Icons.login),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(builder: (_) => const JoinScreen()),
            ),
          ),
          // Closed organizations, restorable for 30 days (ADR-0044).
          if (user != null)
            IconButton(
              key: const Key('orgs-closed'),
              tooltip: l10n.orgsClosedTitle,
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ClosedOrganizationsScreen(),
                ),
              ),
            ),
          if (user != null)
            IconButton(
              tooltip: l10n.bandRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => runBandAction(context, service.refresh),
            ),
        ],
      ),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              key: const Key('band-new'),
              heroTag: null,
              onPressed: () => createBand(context, ref),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(l10n.bandNew),
            ),
      body: body,
    );
  }
}

class _NewBandDialog extends StatefulWidget {
  const _NewBandDialog({
    required this.organizations,
    this.newOrganization = true,
  });

  /// Organizations in which the user may create bands (admins).
  final List<OrganizationView> organizations;

  /// Whether "new organization" can be chosen (only on open servers,
  /// ADR-0024).
  final bool newOrganization;

  @override
  State<_NewBandDialog> createState() => _NewBandDialogState();
}

class _NewBandDialogState extends State<_NewBandDialog> {
  final _name = TextEditingController();
  late String? _orgId = widget.organizations.firstOrNull?.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, orgId: _orgId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bandNew),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('band-new-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.bandName),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.organizations.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: const Key('band-new-org'),
                initialValue: _orgId,
                decoration: InputDecoration(
                  labelText: l10n.bandOrganization,
                  helperText: l10n.bandNewHint,
                ),
                items: [
                  for (final o in widget.organizations)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                  if (widget.newOrganization)
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.bandNewOrganization),
                    ),
                ],
                onChanged: (v) => setState(() => _orgId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
