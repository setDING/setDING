import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../platform/http_client.dart';
import '../../platform/self_update.dart';
import '../../update/app_update.dart';
import '../../update/update_providers.dart';
import '../../util/log.dart';
import 'dialogs.dart';

const _log = Log('update');

/// Downloads and installs [update] after asking (ADR-0035): the setup closes
/// setDING, installs the new version and starts it again. Never without a
/// tap, so an update never restarts the app during a performance.
Future<void> installAppUpdate(
  BuildContext context,
  AvailableUpdate update,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirm(
    context,
    title: l10n.appUpdateInstallTitle(update.version),
    message: l10n.appUpdateInstallBody,
    action: l10n.appUpdateInstall,
  );
  if (!ok || !context.mounted) return;

  final progress = ValueNotifier<double?>(null);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('app-update-progress'),
        title: Text(l10n.appUpdateDownloading),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => LinearProgressIndicator(value: value),
        ),
      ),
    ),
  );
  final client = createHttpClient();
  try {
    final setup = await downloadVerifiedUpdate(
      client,
      update,
      onProgress: (v) => progress.value = v,
    );
    _log.info('Installing ${update.version}');
    await runInstallerAndExit(setup);
  } catch (e) {
    _log.warning('Update ${update.version} not installed', e);
    navigator.pop();
    if (context.mounted) showMessage(context, l10n.appUpdateFailed);
  } finally {
    client.close();
  }
}

/// Offers a newer version above the main navigation until it is put off
/// (ADR-0035). Not in live mode, which covers the navigation.
class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key, required this.update});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('app-update-banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.appUpdateAvailable(update.version),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              key: const Key('app-update-later'),
              onPressed: () =>
                  ref.read(updateBannerDismissedProvider.notifier).dismiss(),
              child: Text(l10n.appUpdateLater),
            ),
            FilledButton(
              key: const Key('app-update-install'),
              onPressed: () => installAppUpdate(context, update),
              child: Text(l10n.appUpdateInstall),
            ),
          ],
        ),
      ),
    );
  }
}

/// The update state in the settings; a tap checks again. Only shown where
/// the app updates itself ([selfUpdateSupportedProvider]).
class AppUpdateTile extends ConsumerWidget {
  const AppUpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(availableUpdateProvider);
    final update = state.value;
    return ListTile(
      key: const Key('app-update-tile'),
      leading: const Icon(Icons.system_update_outlined),
      title: Text(l10n.appUpdateTitle),
      subtitle: Text(switch (state) {
        AsyncLoading() => l10n.appUpdateChecking,
        AsyncError() => l10n.appUpdateCheckFailed,
        _ when update != null => l10n.appUpdateAvailable(update.version),
        _ => l10n.appUpdateCurrent,
      }),
      trailing: update == null || state.isLoading
          ? null
          : FilledButton(
              key: const Key('app-update-tile-install'),
              onPressed: () => installAppUpdate(context, update),
              child: Text(l10n.appUpdateInstall),
            ),
      onTap: state.isLoading
          ? null
          : () => ref.invalidate(availableUpdateProvider),
    );
  }
}
