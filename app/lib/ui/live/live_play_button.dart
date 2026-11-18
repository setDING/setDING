import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// The button that starts the live mode, the last action of the set and song
/// app bars (#444).
///
/// A vertical divider sets it apart from the other actions; it is filled with
/// the primary colour and labelled, so it stands out and is always in the same
/// place. Narrow screens (phones) leave out the label to keep room for the
/// title.
class LivePlayButton extends StatelessWidget {
  const LivePlayButton({super.key, required this.onPressed});

  /// Below this screen width the button shows only its icon.
  static const labelWidth = 600.0;

  /// Null disables the button (an empty set).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const key = Key('play-live');
    const icon = Icon(Icons.play_arrow);
    final labelled = MediaQuery.sizeOf(context).width >= labelWidth;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 17, thickness: 1),
          ),
          if (labelled)
            Tooltip(
              message: l10n.playLive,
              child: FilledButton.icon(
                key: key,
                onPressed: onPressed,
                icon: icon,
                label: Text(l10n.live),
              ),
            )
          else
            IconButton.filled(
              key: key,
              tooltip: l10n.playLive,
              onPressed: onPressed,
              icon: icon,
            ),
        ],
      ),
    );
  }
}
