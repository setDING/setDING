import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import 'band_labels.dart';
import '../routes.dart';

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
        (ref.watch(localLibraryShownProvider)
            ? const [BandView.local]
            : const <BandView>[]);
    final current = ref.watch(currentBandProvider);
    final signedIn = ref.watch(authProvider) != null;
    if (!signedIn && bands.length <= 1) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      key: const Key('band-switcher'),
      tooltip: l10n.bandSwitch,
      onSelected: (id) {
        if (id == _manage) {
          context.push<void>(AppPaths.bands);
        } else {
          ref.read(selectedBandIdProvider.notifier).select(id);
        }
      },
      itemBuilder: (_) => [
        for (final (i, b) in bands.indexed) ...[
          // Header per organization (ADR-0017), with the organization icon
          // of the song library switcher; a divider separates the
          // organizations (#864).
          if (!b.isLocal &&
              (i == 0 || bands[i - 1].organizationId != b.organizationId)) ...[
            if (i > 0) const PopupMenuDivider(),
            PopupMenuItem<String>(
              enabled: false,
              height: 40,
              child: _OrganizationHeader(b.organizationName),
            ),
          ],
          PopupMenuItem(
            value: b.id,
            child: ListTile(
              // Bands are indented under their organization.
              contentPadding: EdgeInsets.only(left: b.isLocal ? 0 : 16),
              selected: b.id == current.id,
              leading: Icon(
                b.isLocal
                    ? Icons.phone_android
                    : (b.id == current.id
                          ? Icons.groups
                          : Icons.groups_outlined),
              ),
              title: Text(bandLabel(l10n, b)),
              subtitle: b.isLocal ? Text(l10n.bandLocalHint) : null,
              trailing: _BandTrailing(
                role: b.isLocal ? null : bandRoleLabel(l10n, b),
                chosen: b.id == current.id,
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
                  current.id == noBandId
                      ? l10n.bandNone
                      : bandLabel(l10n, current),
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

/// Group header of an organization in the band switcher (#864).
class _OrganizationHeader extends StatelessWidget {
  const _OrganizationHeader(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.domain, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The user's role in a band, compact at the end of its row, and the check
/// of the chosen band (#864).
class _BandTrailing extends StatelessWidget {
  const _BandTrailing({required this.role, required this.chosen});

  final String? role;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (role != null)
          Text(
            role!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: chosen
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
        ),
      ],
    );
  }
}
