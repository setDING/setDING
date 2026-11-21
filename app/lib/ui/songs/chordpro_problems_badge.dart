import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Colour of the ChordPro problem warnings (#314): a warning, not an error,
/// so it stays apart from the sync conflict icon.
Color chordProProblemColor(BuildContext context) =>
    StatusColors.of(context).warning;

/// Icon of songs with places the editor offers to convert (#798): no
/// warning colour, the song shows as intended.
const chordProConversionsIcon = Icons.auto_fix_high_outlined;

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
