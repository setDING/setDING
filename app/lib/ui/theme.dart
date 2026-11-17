import 'package:material_ui/material_ui.dart';

import 'widgets/logo.dart' show BrandColors;

/// Seed of the app colour scheme: the red of the logo (issue #269).
const brandSeed = BrandColors.gradientBottom;

/// The colour scheme of the app for [brightness], derived from [brandSeed]
/// (docs/development/branding.md, "App colours").
///
/// The default `tonalSpot` variant keeps the brand hue but calm (a muted
/// terracotta instead of the logo's bright vermilion), so chords and
/// controls do not shout and stay apart from the error red.
///
/// A red seed puts the primary roles next to the error roles, so two of
/// them use other tones of the Material error palette (hue 25, chroma 84):
/// - dark: `error` tone 65 instead of 80 (tone 80 is the same pastel as the
///   primary colour);
/// - light: `errorContainer` tone 80 instead of 90 (tone 90 is the same
///   blush as `primaryContainer`).
ColorScheme appColorScheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: brightness,
  );
  return switch (brightness) {
    Brightness.dark => scheme.copyWith(error: const Color(0xFFFF7164)),
    Brightness.light => scheme.copyWith(
      errorContainer: const Color(0xFFFFB4AB),
    ),
  };
}

/// The app theme for [brightness] (light or dark).
ThemeData appTheme(Brightness brightness) =>
    ThemeData(colorScheme: appColorScheme(brightness), useMaterial3: true);
