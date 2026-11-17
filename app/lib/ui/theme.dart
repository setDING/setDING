import 'package:material_ui/material_ui.dart';

import '../settings/settings.dart' show AccentColor;
import 'widgets/logo.dart' show BrandColors;

/// Seed of the app colour scheme: the night blue of the logo's tile (#319;
/// the red of the former RealChord logo is the accent [AccentColor.red]).
const brandSeed = BrandColors.tileBottom;

/// Seed colours and stage chord colours of the accent colours a user can
/// choose (issue #300, docs/development/branding.md, "Accent colours").
extension AccentColorPalette on AccentColor {
  /// The seed of the colour scheme. Only its hue and chroma matter: the
  /// tones come from Material's `tonalSpot` variant, so every accent gets
  /// the same tonal structure (and contrast) as the brand blue in light and
  /// dark.
  Color get seed => switch (this) {
    AccentColor.brand => brandSeed,
    AccentColor.red => const Color(0xFFE8461C),
    AccentColor.amber => const Color(0xFFFFB300),
    AccentColor.green => const Color(0xFF43A047),
    AccentColor.teal => const Color(0xFF00897B),
    AccentColor.purple => const Color(0xFF8E24AA),
    AccentColor.pink => const Color(0xFFD81B60),
  };

  /// Chord colour on a light stage (ADR-0007): the hue of [seed] at HCT
  /// tone 30 with its full chroma, about 9:1 on the light surface.
  Color get stageChord => switch (this) {
    AccentColor.brand => const Color(0xFF2A3D9C),
    AccentColor.red => const Color(0xFF852309),
    AccentColor.amber => const Color(0xFF604100),
    AccentColor.green => const Color(0xFF005313),
    AccentColor.teal => const Color(0xFF005048),
    AccentColor.purple => const Color(0xFF790096),
    AccentColor.pink => const Color(0xFF90003B),
  };
}

/// The colour scheme of the app for [brightness], derived from the seed of
/// [accent] (docs/development/branding.md, "App colours").
///
/// The default `tonalSpot` variant keeps the hue of the seed but calm (for
/// the brand blue a muted indigo instead of the logo's saturated night
/// blue), so chords and controls do not shout and stay apart from the
/// error red.
///
/// A red seed (the accent [AccentColor.red]) puts the primary roles next to the error roles, so two of
/// them use other tones of the Material error palette (hue 25, chroma 84):
/// - dark: `error` tone 65 instead of 80 (tone 80 is the same pastel as the
///   primary colour);
/// - light: `errorContainer` tone 80 instead of 90 (tone 90 is the same
///   blush as `primaryContainer`).
///
/// The error colours are the same for every accent.
ColorScheme appColorScheme(
  Brightness brightness, [
  AccentColor accent = AccentColor.brand,
]) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent.seed,
    brightness: brightness,
  );
  return switch (brightness) {
    Brightness.dark => scheme.copyWith(error: const Color(0xFFFF7164)),
    Brightness.light => scheme.copyWith(
      errorContainer: const Color(0xFFFFB4AB),
    ),
  };
}

/// Built once per brightness and accent: the colour scheme is computed from
/// the seed colour.
final _themes = <(Brightness, AccentColor), ThemeData>{};

/// The app theme for [brightness] (light or dark) and [accent].
ThemeData appTheme(
  Brightness brightness, [
  AccentColor accent = AccentColor.brand,
]) => _themes.putIfAbsent(
  (brightness, accent),
  () => ThemeData(
    colorScheme: appColorScheme(brightness, accent),
    useMaterial3: true,
  ),
);
