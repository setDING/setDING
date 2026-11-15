import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../account/sign_in_screen.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';
import 'band_screen.dart';
import 'join_screen.dart';
import 'organization_screen.dart';

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
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(backendErrorText(l10n, e.kind))));
    return false;
  }
}

/// The organizations and bands of the signed-in user (ADR-0005, ADR-0017).
class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    List<OrganizationView> orgs,
  ) async {
    final adminOrgs = [
      for (final o in orgs)
        if (o.isAdmin) o,
    ];
    final result = await showDialog<({String name, String? orgId})>(
      context: context,
      builder: (_) => _NewBandDialog(organizations: adminOrgs),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider);
    final orgs = ref.watch(organizationsProvider).value ?? const [];
    final bands = ref.watch(bandsProvider).value ?? const <BandView>[];
    final current = ref.watch(currentBandProvider);
    final service = ref.read(bandServiceProvider);

    Widget body;
    if (user == null) {
      body = EmptyState(
        icon: Icons.groups_outlined,
        message: l10n.bandsSignInHint,
        action: FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<bool>(builder: (_) => const SignInScreen()),
          ),
          child: Text(l10n.accountSignIn),
        ),
      );
    } else if (orgs.isEmpty) {
      body = EmptyState(icon: Icons.groups_outlined, message: l10n.bandsEmpty);
    } else {
      body = RefreshIndicator(
        onRefresh: () => runBandAction(context, service.refresh),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final o in orgs) ...[
              ListTile(
                key: Key('org-${o.id}'),
                leading: const Icon(Icons.domain),
                title: Text(
                  o.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
          if (user != null)
            IconButton(
              tooltip: l10n.bandRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => runBandAction(context, service.refresh),
            ),
        ],
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('band-new'),
              heroTag: null,
              onPressed: () => _create(context, ref, orgs),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(l10n.bandNew),
            ),
      body: body,
    );
  }
}

/// Name and organization of a new band. Without organizations to choose
/// from, the server creates a new organization of the same name.
class _NewBandDialog extends StatefulWidget {
  const _NewBandDialog({required this.organizations});

  /// Organizations in which the user may create bands (admins).
  final List<OrganizationView> organizations;

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
