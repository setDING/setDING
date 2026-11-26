import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/auth_providers.dart';
import '../routes.dart';

/// App bar button of the songs tab showing the current song library: the
/// local library or an organization's library (ADR-0017). Choosing a
/// library also chooses a band of it for the sets tab (#856). Hidden while
/// there is only the local library and nobody is signed in, so the
/// single-device app looks as before.
class LibrarySwitcher extends ConsumerWidget {
  const LibrarySwitcher({super.key});

  static const _manage = '\u0000manage';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libraries =
        ref.watch(librariesProvider).value ??
        (ref.watch(localLibraryShownProvider)
            ? const [LibraryView.local]
            : const <LibraryView>[]);
    final current = ref.watch(currentLibraryProvider);
    final signedIn = ref.watch(authProvider) != null;
    if (!signedIn && libraries.length <= 1) return const SizedBox.shrink();

    String label(LibraryView l) => l.isLocal ? l10n.bandLocal : l.name;
    IconData icon(LibraryView l) =>
        l.isLocal ? Icons.phone_android : Icons.domain;

    return PopupMenuButton<String>(
      key: const Key('library-switcher'),
      tooltip: l10n.librarySwitch,
      onSelected: (id) {
        if (id == _manage) {
          context.push<void>(AppPaths.bands);
        } else {
          ref.read(selectedLibraryIdProvider.notifier).select(id);
        }
      },
      itemBuilder: (_) => [
        for (final l in libraries)
          PopupMenuItem(
            value: l.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              // The icon stays; a check at the end marks the chosen
              // library, as in the band switcher (#864).
              selected: l.id == current.id,
              leading: Icon(icon(l)),
              title: Text(label(l)),
              subtitle: l.isLocal ? Text(l10n.bandLocalHint) : null,
              trailing: SizedBox(
                width: 24,
                child: l.id == current.id ? const Icon(Icons.check) : null,
              ),
            ),
          ),
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
          avatar: Icon(icon(current), size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(label(current), overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
