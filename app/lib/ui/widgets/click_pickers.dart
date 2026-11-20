import 'package:chordpro/chordpro.dart' show Meter, Subdivision;
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// The name of [subdivision] in the UI.
String subdivisionLabel(AppLocalizations l10n, Subdivision subdivision) =>
    switch (subdivision) {
      Subdivision.off => l10n.subdivisionOff,
      Subdivision.eighths => l10n.subdivisionEighths,
      Subdivision.sixteenths => l10n.subdivisionSixteenths,
      Subdivision.triplets => l10n.subdivisionTriplets,
    };

/// The name of a grouping in the UI: `2+2+3`, or "No groups" for one group.
String groupingLabel(AppLocalizations l10n, Meter meter) =>
    meter.groupingLabel ?? l10n.clickGroupingNone;

/// Chooses the grouping of an odd meter for the click and the beat display
/// (a personal adjustment of the song, #698): a chip in the song's personal
/// panel, an icon button in the tempo row of live mode ([compact]).
/// [songMeter] is the meter as written in the song; [grouping] the
/// personal choice (null = as in the song).
class ClickGroupingPicker extends StatelessWidget {
  const ClickGroupingPicker({
    super.key,
    required this.songMeter,
    required this.grouping,
    required this.onChanged,
    this.compact = false,
  });

  final Meter songMeter;
  final String? grouping;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = groupingLabel(l10n, songMeter.withGrouping(grouping));
    final noGroups = '${songMeter.numerator}';
    return MenuAnchor(
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          return TextButton.icon(
            key: const Key('click-grouping-button'),
            icon: const Icon(Icons.view_week_outlined),
            label: Text(current),
            onPressed: toggle,
          );
        }
        return Tooltip(
          message: l10n.clickGroupingHint,
          child: ActionChip(
            key: const Key('click-grouping-button'),
            avatar: const Icon(Icons.view_week_outlined, size: 18),
            label: Text('${l10n.clickGrouping}: $current'),
            onPressed: toggle,
          ),
        );
      },
      menuChildren: [
        _item(
          'click-grouping-song',
          l10n.clickGroupingAsInSong(groupingLabel(l10n, songMeter)),
          grouping == null,
          () => onChanged(null),
        ),
        for (final choice in songMeter.groupingChoices())
          _item(
            'click-grouping-$choice',
            choice,
            grouping == choice,
            () => onChanged(choice),
          ),
        _item(
          'click-grouping-none',
          l10n.clickGroupingNone,
          grouping == noGroups,
          () => onChanged(noGroups),
        ),
      ],
    );
  }
}

/// Chooses the subdivisions of the click for a song (a personal adjustment,
/// #698): a chip in the song's personal panel, an icon button in the tempo
/// row of live mode ([compact]). [subdivision] is the song's choice (null =
/// the setting [setting]). Choices that sound the same as an earlier one in
/// [meter] are disabled; the current one can always be chosen again.
class ClickSubdivisionPicker extends StatelessWidget {
  const ClickSubdivisionPicker({
    super.key,
    required this.meter,
    required this.subdivision,
    required this.setting,
    required this.onChanged,
    this.compact = false,
  });

  final Meter meter;
  final Subdivision? subdivision;
  final Subdivision setting;
  final ValueChanged<Subdivision?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = subdivisionLabel(l10n, subdivision ?? setting);
    final choices = meter.subdivisionChoices;
    return MenuAnchor(
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          return TextButton.icon(
            key: const Key('click-subdivision-button'),
            icon: const Icon(Icons.more_horiz),
            label: Text(current),
            onPressed: toggle,
          );
        }
        return ActionChip(
          key: const Key('click-subdivision-button'),
          avatar: const Icon(Icons.more_horiz, size: 18),
          label: Text('${l10n.settingsClickSubdivision}: $current'),
          onPressed: toggle,
        );
      },
      menuChildren: [
        _item(
          'click-subdivision-settings',
          l10n.clickSubdivisionAsInSettings(subdivisionLabel(l10n, setting)),
          subdivision == null,
          () => onChanged(null),
        ),
        for (final choice in Subdivision.values)
          _item(
            'click-subdivision-${choice.name}',
            subdivisionLabel(l10n, choice),
            subdivision == choice,
            choices.contains(choice) || subdivision == choice
                ? () => onChanged(choice)
                : null,
          ),
      ],
    );
  }
}

Widget _item(
  String key,
  String label,
  bool selected,
  VoidCallback? onPressed,
) => MenuItemButton(
  key: Key(key),
  trailingIcon: selected ? const Icon(Icons.check) : null,
  onPressed: onPressed,
  child: Text(label),
);
