import 'package:chordpro/chordpro.dart' show Song;
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart' show VerseChords;
import '../../l10n/generated/app_localizations.dart';
import '../render/render_cache.dart';

/// The ways [song] can show its verses' chords: all chords, and the
/// adjustments that change the song (#518 later verses with chords, #521
/// verses with the same chords).
Set<VerseChords> verseChordsChoices(Song song) => {
  VerseChords.all,
  if (!identical(firstVerseChordsOnlyCached(song), song)) VerseChords.first,
  if (!identical(stackVersesCached(song), song)) VerseChords.stacked,
};

/// Whether [song] has choruses that stacking changes (#953).
bool canStackChoruses(Song song) => !identical(stackChorusesCached(song), song);

/// Whether the picker is worth showing for [song]: a choice changes
/// something, or one is on and can be turned off again.
bool verseChordsOffered(Song song, VerseChords mode, bool stackedChoruses) =>
    mode != VerseChords.all ||
    stackedChoruses ||
    verseChordsChoices(song).length > 1 ||
    canStackChoruses(song);

/// The name of [mode] in the UI.
String verseChordsLabel(AppLocalizations l10n, VerseChords mode) =>
    switch (mode) {
      VerseChords.all => l10n.verseChordsAll,
      VerseChords.first => l10n.firstVerseChordsOnly,
      VerseChords.stacked => l10n.verseChordsStacked,
    };

IconData _icon(VerseChords mode) => switch (mode) {
  VerseChords.all => Icons.subject,
  VerseChords.first => Icons.short_text,
  VerseChords.stacked => Icons.table_rows_outlined,
};

/// Chooses how the verses of [song] show their chords and whether its
/// choruses are stacked (#953) (personal adjustments, ADR-0006): a chip in
/// the song's personal panel, an icon button in the live mode control bar
/// ([compact]). Choices that would not change the song are disabled; the
/// current one can always be chosen again, e.g. after the song was changed.
class VerseChordsPicker extends StatelessWidget {
  const VerseChordsPicker({
    super.key,
    required this.song,
    required this.mode,
    required this.onChanged,
    required this.stackedChoruses,
    required this.onStackedChorusesChanged,
    this.compact = false,
  });

  final Song song;
  final VerseChords mode;
  final ValueChanged<VerseChords> onChanged;

  /// Choruses whose words change stacked line by line (#953).
  final bool stackedChoruses;
  final ValueChanged<bool> onStackedChorusesChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choices = verseChordsChoices(song);
    final choruses = canStackChoruses(song);
    final enabled = verseChordsOffered(song, mode, stackedChoruses);
    final label = [
      if (mode != VerseChords.all || !stackedChoruses)
        verseChordsLabel(l10n, mode),
      if (stackedChoruses) l10n.chorusesStacked,
    ].join(' · ');
    final icon = mode == VerseChords.all && stackedChoruses
        ? Icons.table_rows_outlined
        : _icon(mode);
    return MenuAnchor(
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          return IconButton(
            key: const Key('verse-chords-button'),
            tooltip: '${l10n.verseChords}: $label',
            isSelected: mode != VerseChords.all || stackedChoruses,
            icon: Icon(icon),
            onPressed: enabled ? toggle : null,
          );
        }
        return Tooltip(
          message: enabled ? '' : l10n.noVersesForFirstVerseChords,
          child: ActionChip(
            key: const Key('verse-chords-button'),
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: enabled ? toggle : null,
          ),
        );
      },
      menuChildren: [
        for (final choice in VerseChords.values)
          MenuItemButton(
            key: Key('verse-chords-${choice.name}'),
            leadingIcon: Icon(_icon(choice)),
            trailingIcon: choice == mode ? const Icon(Icons.check) : null,
            onPressed: choices.contains(choice) || choice == mode
                ? () => onChanged(choice)
                : null,
            child: Text(verseChordsLabel(l10n, choice)),
          ),
        const Divider(),
        CheckboxMenuButton(
          key: const Key('verse-chords-choruses'),
          value: stackedChoruses,
          onChanged: choruses || stackedChoruses
              ? (on) => onStackedChorusesChanged(on ?? false)
              : null,
          child: Text(l10n.chorusesStacked),
        ),
      ],
    );
  }
}
