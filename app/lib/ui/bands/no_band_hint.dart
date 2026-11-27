import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/dialogs.dart';
import '../routes.dart';

/// Shown on the sets tab and the overview while the chosen song library is
/// an organization without a band of the user (#856): sets belong to a
/// band, and the band always follows the song library.
class NoBandHint extends ConsumerWidget {
  const NoBandHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(currentLibraryProvider);
    return EmptyState(
      key: const Key('no-band-hint'),
      icon: Icons.groups_outlined,
      message: l10n.noBandInLibrary(library.name),
      action: FilledButton.tonalIcon(
        key: const Key('no-band-manage'),
        onPressed: () => context.push<void>(AppPaths.bands),
        icon: const Icon(Icons.settings_outlined),
        label: Text(l10n.bandManage),
      ),
    );
  }
}
