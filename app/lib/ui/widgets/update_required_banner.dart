import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../platform/reload.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../../sync/sync_controller.dart';
import '../../sync/update_check.dart' show releasesUrl;
import '../../update/update_providers.dart';
import 'app_update.dart';

export '../../sync/update_check.dart' show releasesUrl;

/// Whether the server refused this app version (ADR-0029).
final updateRequiredProvider = Provider<bool>(
  (ref) =>
      ref.watch(syncControllerProvider.select((s) => s.lastReport?.error)) ==
      BackendErrorKind.updateRequired,
);

/// Asks the person to update setDING when the server no longer accepts this
/// version (ADR-0029). Local changes stay on the device and are synced after
/// the update. Shown above the main navigation, so never in live mode.
class UpdateRequiredBanner extends ConsumerWidget {
  const UpdateRequiredBanner({super.key, this.minVersion});

  /// The version the server needs; read from the server config if null.
  final String? minVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final min =
        minVersion ?? ref.watch(serverConfigProvider).value?.minClientVersion;
    final current = ref.watch(clientVersionProvider);
    // The Windows app installs a newer release itself (ADR-0035).
    final update = ref.watch(installableUpdateProvider);

    return Material(
      key: const Key('update-required-banner'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.system_update, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.updateRequiredTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          l10n.updateRequiredBody,
                          if (min != null && current != null)
                            l10n.updateRequiredVersions(current, min),
                          if (!canReload && update == null)
                            l10n.updateRequiredHowTo,
                        ].join(' '),
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: update != null
                  ? FilledButton(
                      key: const Key('update-install'),
                      onPressed: () => installAppUpdate(context, update),
                      child: Text(l10n.appUpdateInstall),
                    )
                  : canReload
                  ? TextButton(
                      key: const Key('update-reload'),
                      onPressed: reloadApp,
                      child: Text(l10n.updateRequiredReload),
                    )
                  : TextButton(
                      key: const Key('update-copy-link'),
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: releasesUrl),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(content: Text(l10n.updateRequiredCopied)),
                        );
                      },
                      child: Text(l10n.updateRequiredCopyLink),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
