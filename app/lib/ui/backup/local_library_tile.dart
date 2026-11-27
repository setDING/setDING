import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart' show authProvider;
import '../settings/settings_layout.dart';
import '../widgets/dialogs.dart';

/// *Show the local library* (ADR-0054 section 3): people who play only in
/// organizations can hide "On this device" while signed in, also when it is
/// not empty. Switching it off says what stays on the device.
class ShowLocalLibraryTile extends ConsumerWidget {
  const ShowLocalLibraryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider.select((u) => u != null));
    final show = ref.watch(settingsProvider.select((s) => s.showLocalLibrary));
    return SettingsSwitch(
      tileKey: const Key('settings-show-local-library'),
      icon: Icons.phone_android,
      title: l10n.showLocalLibrary,
      hint: signedIn
          ? l10n.showLocalLibraryHint
          : l10n.showLocalLibrarySignedOut,
      // Signed out the local library is always shown; the setting stays.
      value: show || !signedIn,
      onChanged: signedIn
          ? (on) async {
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(showLocalLibrary: on));
              if (on) return;
              final counts = await ref
                  .read(backupServiceProvider)
                  .localCounts();
              final auto = ref.read(autoBackupProvider).enabled;
              showMessageOn(
                messenger,
                [
                  l10n.localLibraryHidden(counts.songs, counts.sets),
                  if (auto) l10n.localLibraryHiddenAutoBackup,
                ].join(' '),
                key: const Key('local-library-hidden'),
                duration: messageActionDuration,
              );
            }
          : null,
    );
  }
}
