import 'package:material_ui/material_ui.dart';

/// Colour of the ChordPro problem warnings (#314): a warning, not an error,
/// so it stays apart from the sync conflict icon.
Color chordProProblemColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.amber.shade400
    : Colors.amber.shade900;

/// Warning icon for ChordPro sources with problems (`validateChordPro`,
/// #314); its meaning in the tooltip.
class ChordProProblemsBadge extends StatelessWidget {
  const ChordProProblemsBadge({super.key, required this.message, this.size});

  final String message;
  final double? size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    child: Icon(
      Icons.warning_amber_rounded,
      size: size,
      color: chordProProblemColor(context),
      semanticLabel: message,
    ),
  );
}
