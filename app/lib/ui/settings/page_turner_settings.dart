import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../platform/input_devices.dart';
import '../live/page_turner.dart';
import '../theme.dart' show StatusColors;
import '../widgets/dialogs.dart';
import '../widgets/menu_action.dart';

/// The name of [device] for people; a device without a name says so.
String pageTurnerName(AppLocalizations l10n, InputDeviceInfo device) =>
    device.name.isEmpty ? l10n.pageTurnerUnnamed : device.name;

/// *Settings › Live › Page turner* (ADR-0057): the page turner paired on
/// this device and whether it is connected, *Pair* / *Pair again* and
/// *Forget*. Where the platform cannot tell devices apart it says why.
class PageTurnerTile extends ConsumerWidget {
  const PageTurnerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final support = ref.watch(inputDevicesProvider).support;
    final paired = ref.watch(pairedPageTurnerProvider);
    final connection = ref.watch(pageTurnerConnectionProvider);
    const icon = Icon(Icons.keyboard_outlined);
    if (support != InputDeviceSupport.devices) {
      return ListTile(
        key: const Key('settings-page-turner'),
        leading: icon,
        title: Text(l10n.settingsPageTurner),
        subtitle: Text(
          support == InputDeviceSupport.keyboardOnly
              ? l10n.settingsPageTurnerKeyboardOnly
              : l10n.settingsPageTurnerUnsupported,
        ),
      );
    }
    final status = StatusColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final (state, color) = switch (connection) {
      PageTurnerConnection.connected => (
        l10n.settingsPageTurnerConnected,
        status.success,
      ),
      PageTurnerConnection.notConnected => (
        l10n.settingsPageTurnerNotConnected,
        status.warning,
      ),
      _ => (null, colors.onSurfaceVariant),
    };
    return ListTile(
      key: const Key('settings-page-turner'),
      leading: icon,
      title: Text(l10n.settingsPageTurner),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paired == null)
            Text(l10n.settingsPageTurnerNone)
          else
            Text.rich(
              key: const Key('settings-page-turner-paired'),
              TextSpan(
                children: [
                  TextSpan(text: pageTurnerName(l10n, paired)),
                  if (state != null)
                    TextSpan(
                      text: ' · $state',
                      style: TextStyle(color: color),
                    ),
                ],
              ),
            ),
          Text(l10n.settingsPageTurnerHint),
        ],
      ),
      isThreeLine: true,
      trailing: paired == null
          ? TextButton(
              key: const Key('settings-page-turner-pair'),
              onPressed: () => pairPageTurner(context, ref),
              child: Text(l10n.settingsPageTurnerPair),
            )
          : PopupMenuButton<void>(
              key: const Key('settings-page-turner-menu'),
              tooltip: l10n.settingsPageTurner,
              itemBuilder: (_) => [
                MenuAction(
                  key: const Key('settings-page-turner-pair-again'),
                  icon: Icons.link,
                  label: l10n.settingsPageTurnerPairAgain,
                  onTap: () => pairPageTurner(context, ref),
                ),
                MenuAction(
                  key: const Key('settings-page-turner-forget'),
                  icon: Icons.link_off,
                  label: l10n.settingsPageTurnerForget,
                  destructive: true,
                  onTap: () => _forget(context, ref, paired),
                ),
              ],
            ),
    );
  }

  /// Forgets the page turner, with *Undo* (ADR-0051: undo rather than ask).
  Future<void> _forget(
    BuildContext context,
    WidgetRef ref,
    InputDeviceInfo paired,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(pairedPageTurnerProvider.notifier);
    await notifier.forget();
    showUndo(
      messenger,
      l10n.pageTurnerForgotten(pageTurnerName(l10n, paired)),
      undoLabel: l10n.undo,
      onUndo: () => notifier.pair(paired),
    );
  }
}

/// Asks to press the pedal and pairs the device the next key came from
/// (ADR-0057). Returns the paired device, or null when cancelled.
Future<InputDeviceInfo?> pairPageTurner(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final device = await showDialog<InputDeviceInfo>(
    context: context,
    builder: (_) => _PairDialog(keys: ref.read(inputDevicesProvider).keys),
  );
  if (device == null) return null;
  await ref.read(pairedPageTurnerProvider.notifier).pair(device);
  showMessageOn(messenger, l10n.pageTurnerPaired(pageTurnerName(l10n, device)));
  return device;
}

/// "Press the pedal now": closes with the device of the first key.
class _PairDialog extends StatefulWidget {
  const _PairDialog({required this.keys});

  final Stream<InputDeviceInfo> keys;

  @override
  State<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends State<_PairDialog> {
  StreamSubscription<InputDeviceInfo>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.keys.listen((device) {
      _sub?.cancel();
      _sub = null;
      if (mounted) Navigator.of(context).pop(device);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('page-turner-pair-dialog'),
      title: Text(l10n.pairPageTurnerTitle),
      content: Row(
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(l10n.pairPageTurnerPrompt)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
