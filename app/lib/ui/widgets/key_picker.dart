import 'package:chordpro/chordpro.dart' as cp;
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'dialogs.dart';

/// Normalizes a transposition to the shortest way: −5 … +6 semitones.
int normalizeSemitones(int value) {
  final n = ((value % 12) + 12) % 12;
  return n > 6 ? n - 12 : n;
}

/// One entry of the key picker.
class KeyOption {
  const KeyOption(this.semitones, this.label);

  /// Transposition relative to the base key (−5 … +6).
  final int semitones;
  final String label;

  bool get isOriginal => semitones == 0;
}

/// The twelve target keys for [base], in chromatic order starting at C.
/// Without a key, the options are plain semitone offsets (−5 … +6).
List<KeyOption> keyOptions(cp.Key? base, cp.ChordNotation notation) {
  final options = [
    for (var s = -5; s <= 6; s++)
      KeyOption(
        s,
        base == null ? formatSemitones(s) : base.transpose(s).format(notation),
      ),
  ];
  if (base != null) {
    int pitch(KeyOption o) => (base.tonic.pitch + o.semitones) % 12;
    options.sort((a, b) => pitch(a).compareTo(pitch(b)));
  }
  return options;
}

/// Dropdown to choose the key a song is played in.
///
/// [baseKey] is the key before this transposition (null if the song has no
/// key – then semitone offsets are offered). [onChanged] receives the
/// transposition in semitones (−5 … +6).
class KeyPicker extends StatelessWidget {
  const KeyPicker({
    super.key,
    required this.baseKey,
    required this.transpose,
    required this.notation,
    required this.onChanged,
    required this.tooltip,
    this.dense = false,
    this.hint,
  });

  final cp.Key? baseKey;
  final int transpose;
  final cp.ChordNotation notation;
  final ValueChanged<int> onChanged;

  /// Says whose key this is (personal, set or band), e.g. "My key – just
  /// for me", so the scope of the choice is clear.
  final String tooltip;

  /// Compact variant for list rows.
  final bool dense;

  /// Shown above the keys, e.g. how the band played the song before
  /// (ADR-0046).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final options = keyOptions(baseKey, notation);
    final selected = normalizeSemitones(transpose);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final current = options.firstWhere(
      (o) => o.semitones == selected,
      orElse: () => options.first,
    );
    final labelStyle =
        (dense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: current.isOriginal ? null : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            );

    final picker = PopupMenuButton<int>(
      tooltip: tooltip,
      initialValue: selected,
      onSelected: (value) {
        if (value != selected) onChanged(value);
      },
      // Tall enough for all twelve keys without scrolling on tablets.
      constraints: const BoxConstraints(minWidth: 160, maxHeight: 640),
      itemBuilder: (context) => [
        if (hint case final hint?) ...[
          PopupMenuItem<int>(
            key: const Key('key-picker-hint'),
            enabled: false,
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(hint, style: secondary)),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        for (final o in options)
          CheckedPopupMenuItem<int>(
            value: o.semitones,
            checked: o.semitones == selected,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    o.label,
                    style: TextStyle(
                      fontWeight: o.isOriginal
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  o.isOriginal
                      ? l10n.keyOriginal
                      : formatSemitones(o.semitones),
                  style: secondary,
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 0, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.label, style: labelStyle),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
    if (dense) return picker;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          picker,
        ],
      ),
    );
  }
}
