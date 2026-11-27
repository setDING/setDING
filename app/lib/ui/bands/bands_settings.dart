import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'bands_screen.dart';
import '../routes.dart';

/// The "Organization & bands" category of the settings (ADR-0005, ADR-0017):
/// the organizations and bands of the signed-in user, joining with an
/// invitation and, for those allowed to (ADR-0023, ADR-0024), a new band.
/// Members see their bands and can leave them; the management actions are
/// offered on the organization and band screens depending on the role.
class BandsSettings extends ConsumerStatefulWidget {
  const BandsSettings({super.key});

  @override
  ConsumerState<BandsSettings> createState() => _BandsSettingsState();
}

class _BandsSettingsState extends ConsumerState<BandsSettings> {
  @override
  void initState() {
    super.initState();
    // Like RefreshOnOpen: people who joined meanwhile show up; offline the
    // stored state stays and nothing is shown.
    unawaited(
      ref.read(bandServiceProvider).refresh().then((_) {}, onError: (_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orgs = ref.watch(organizationsProvider).value ?? const [];
    final canCreate = canCreateBand(ref);
    return Column(
      children: [
        if (orgs.isEmpty)
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            subtitle: Text(l10n.bandsEmpty),
          )
        else
          const OrganizationBandTiles(),
        if (canCreate)
          ListTile(
            key: const Key('settings-bands-new'),
            leading: const Icon(Icons.group_add_outlined),
            title: Text(l10n.bandNew),
            onTap: () => createBand(context, ref),
          ),
        ListTile(
          key: const Key('settings-bands-join'),
          leading: const Icon(Icons.login),
          title: Text(l10n.joinTitle),
          subtitle: Text(l10n.settingsBandsJoinHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push<bool>(AppPaths.join),
        ),
      ],
    );
  }
}
