import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:drift/drift.dart' show BooleanExpressionOperators;

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart' show authProvider;
import '../settings/settings_layout.dart';
import '../widgets/dialogs.dart';

/// The songs and sets of the local library (not in the trash).
Future<({int songs, int sets})> localLibraryCounts(AppDatabase db) async {
  final songs =
      await (db.select(db.songs)..where(
            (s) => s.libraryId.equals(localBandId) & s.deleted.equals(false),
          ))
          .get();
  final sets =
      await (db.select(db.setlists)..where(
            (s) => s.bandId.equals(localBandId) & s.deleted.equals(false),
          ))
          .get();
  return (songs: songs.length, sets: sets.length);
}

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
              final counts = await localLibraryCounts(
                ref.read(databaseProvider),
              );
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
