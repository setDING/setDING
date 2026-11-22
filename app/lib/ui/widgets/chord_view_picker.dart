import 'package:chordpro/chordpro.dart' show ChordView;
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// The name of [view] in the UI (ADR-0055).
String chordViewLabel(AppLocalizations l10n, ChordView view) => switch (view) {
  ChordView.chords => l10n.chordViewChords,
  ChordView.nashville => l10n.chordViewNashville,
  ChordView.numerals => l10n.chordViewNumerals,
};

/// Chooses how a song shows its chords: names, Nashville numbers or Roman
/// numerals (a personal adjustment, ADR-0006, ADR-0055). A chip in the
/// song's personal panel; numbers need a key, so without one the chip is
/// disabled with a hint.
class ChordViewPicker extends StatelessWidget {
  const ChordViewPicker({
    super.key,
    required this.view,
    required this.hasKey,
    required this.onChanged,
  });

  final ChordView view;
  final bool hasKey;
  final ValueChanged<ChordView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = hasKey ? view : ChordView.chords;
    return MenuAnchor(
      builder: (context, controller, _) => Tooltip(
        message: hasKey ? '' : l10n.noKeyForDegrees,
        child: ActionChip(
          key: const Key('chord-view-button'),
          avatar: const Icon(Icons.numbers, size: 18),
          label: Text('${l10n.chordView}: ${chordViewLabel(l10n, shown)}'),
          onPressed: hasKey
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
        ),
      ),
      menuChildren: [
        for (final choice in ChordView.values)
          MenuItemButton(
            key: Key('chord-view-${choice.name}'),
            trailingIcon: choice == shown ? const Icon(Icons.check) : null,
            onPressed: () => onChanged(choice),
            child: Text(chordViewLabel(l10n, choice)),
          ),
      ],
    );
  }
}
