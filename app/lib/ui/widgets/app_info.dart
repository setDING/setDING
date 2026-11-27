import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../sync/auth_providers.dart';
import '../../sync/update_check.dart';
import '../../update/update_providers.dart';
import '../../update/whats_new.dart';
import 'app_update.dart';
import 'whats_new_dialog.dart';

/// The notes of the running version, or of the newest one before it with
/// notes (ADR-0041); null while they load or if there are none.
final recentNotesProvider = Provider<VersionNotes?>((ref) {
  final current = ref.watch(clientVersionProvider);
  return switch (ref.watch(whatsNewProvider).value) {
    final all? => latestNotes(all, current),
    null => null,
  };
});

/// The hint about a newer release (ADR-0036), with the installed version;
/// installs it where the app updates itself (ADR-0035), otherwise opens
/// the release page, or Google Play for Play installs (ADR-0067). Empty without a newer release. Under *Storage & info*
/// and in the footer of the overview (ADR-0045).
class UpdateAvailableTile extends ConsumerWidget {
  const UpdateAvailableTile({
    super.key,
    this.installKey = const Key('update-available-install'),
  });

  /// Key of the install button, distinct per place.
  final Key installKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateCheckProvider);
    if (update == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(clientVersionProvider);
    final installable = ref.watch(installableUpdateProvider);
    final googlePlay = ref.watch(installedFromGooglePlayProvider);
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: Text(l10n.updateAvailableTitle(update)),
      subtitle: Text(
        [
          if (current != null) l10n.updateAvailableInstalled(current),
          if (installable == null)
            googlePlay ? l10n.updateHowToGooglePlay : l10n.updateRequiredHowTo,
        ].join(' '),
      ),
      trailing: installable != null
          ? FilledButton(
              key: installKey,
              onPressed: () => installAppUpdate(context, installable),
              child: Text(l10n.appUpdateInstall),
            )
          : const Icon(Icons.open_in_new),
      onTap: () => launchUrl(
        updatePageUrl(update, googlePlay: googlePlay),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}

/// Shows the notes of the running version again (ADR-0041). Empty when
/// there are none.
class WhatsNewButton extends ConsumerWidget {
  const WhatsNewButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(recentNotesProvider);
    if (notes == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.new_releases_outlined),
      label: Text(AppLocalizations.of(context).whatsNewTitle),
      onPressed: () => showWhatsNew(context, notes),
    );
  }
}
