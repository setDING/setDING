import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../platform/http_client.dart';
import '../../platform/self_update.dart';
import '../../update/app_update.dart';
import '../../util/log.dart';
import 'dialogs.dart';

const _log = Log('update');

/// Downloads and installs [version] after asking (ADR-0035): the setup closes
/// setDING, installs the new version and starts it again. Never without a
/// tap, so an update never restarts the app during a performance.
Future<void> installAppUpdate(BuildContext context, String version) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirm(
    context,
    title: l10n.appUpdateInstallTitle(version),
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
    final update = await fetchUpdate(client, version);
    final setup = await downloadVerifiedUpdate(
      client,
      update,
      onProgress: (v) => progress.value = v,
    );
    _log.info('Installing $version');
    await runInstallerAndExit(setup);
  } catch (e) {
    _log.warning('Update $version not installed', e);
    navigator.pop();
    if (context.mounted) showMessage(context, l10n.appUpdateFailed);
  } finally {
    client.close();
  }
}
