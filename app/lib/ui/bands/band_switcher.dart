import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import 'band_labels.dart';
import 'bands_screen.dart';

/// App bar button showing the current band; opens a menu to switch bands
/// (ADR-0005). Hidden while there is only the local library and nobody is
/// signed in, so the single-device app looks as before.
class BandSwitcher extends ConsumerWidget {
  const BandSwitcher({super.key});

  static const _manage = '\u0000manage';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bands =
        ref.watch(bandsProvider).value ??
        (ref.watch(webClientProvider)
            ? const <BandView>[]
            : const [BandView.local]);
    final current = ref.watch(currentBandProvider);
    final signedIn = ref.watch(authProvider) != null;
    if (!signedIn && bands.length <= 1) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      key: const Key('band-switcher'),
      tooltip: l10n.bandSwitch,
      onSelected: (id) {
        if (id == _manage) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const BandsScreen()),
          );
        } else {
          ref.read(selectedBandIdProvider.notifier).select(id);
        }
      },
      itemBuilder: (_) => [
        for (final (i, b) in bands.indexed) ...[
          // Header per organization (ADR-0017).
          if (!b.isLocal &&
              (i == 0 || bands[i - 1].organizationId != b.organizationId))
            PopupMenuItem<String>(
              enabled: false,
              height: 32,
              child: Text(
                b.organizationName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          PopupMenuItem(
            value: b.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                b.id == current.id
                    ? Icons.check
                    : (b.isLocal ? Icons.phone_android : Icons.groups_outlined),
              ),
              title: Text(bandLabel(l10n, b)),
              subtitle: Text(
                b.isLocal ? l10n.bandLocalHint : bandRoleLabel(l10n, b),
              ),
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _manage,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.bandManage),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Chip(
          avatar: Icon(
            current.isLocal ? Icons.phone_android : Icons.groups_outlined,
            size: 18,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  bandLabel(l10n, current),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
