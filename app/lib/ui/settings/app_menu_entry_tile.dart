import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../update/app_menu_entry.dart';
import '../../util/log.dart';
import '../widgets/dialogs.dart';

const _log = Log('menu-entry');

/// Adds the Linux AppImage to the desktop's application menu, with the
/// setDING icon, or removes it again (#1006). Shown only where the app has
/// such an entry (`appMenuEntryProvider`).
class AppMenuEntryTile extends ConsumerWidget {
  const AppMenuEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appMenuEntryStateProvider).value;
    if (state == null) return const SizedBox.shrink();
    final controller = ref.read(appMenuEntryStateProvider.notifier);

    Future<void> change(Future<void> Function() action, String done) async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await action();
        showMessageOn(messenger, done);
      } catch (e) {
        _log.warning('Application menu entry not changed', e);
        showMessageOn(messenger, l10n.appMenuEntryFailed('$e'));
      }
    }

    if (state == AppMenuEntryState.installed) {
      return ListTile(
        key: const Key('app-menu-entry'),
        leading: const Icon(Icons.apps),
        title: Text(l10n.appMenuEntryInstalled),
        subtitle: Text(l10n.appMenuEntryInstalledHint),
        trailing: TextButton(
          key: const Key('app-menu-entry-remove'),
          onPressed: () => change(controller.remove, l10n.appMenuEntryRemoved),
          child: Text(l10n.appMenuEntryRemove),
        ),
      );
    }
    return ListTile(
      key: const Key('app-menu-entry'),
      leading: const Icon(Icons.add_to_home_screen_outlined),
      title: Text(l10n.appMenuEntryAdd),
      subtitle: Text(l10n.appMenuEntryAddHint),
      onTap: () => change(controller.install, l10n.appMenuEntryAdded),
    );
  }
}
