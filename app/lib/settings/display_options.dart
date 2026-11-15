/// Display options of songs that are device settings (layer 4, ADR-0006)
/// and used by the renderer. They live here so that the settings do not
/// depend on the UI.
library;

/// Where the diagrams of all chords of a song are shown.
enum DiagramsPosition { off, top, bottom }

/// How a repeated chorus (`{chorus}`) is shown in live mode.
enum ChorusRepeat {
  /// Full lines, shortened to a label only if that is needed to fit.
  auto,

  /// Always the full lines.
  full,

  /// Always a label only.
  label,
}
