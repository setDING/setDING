import 'package:material_ui/material_ui.dart';

import '../../settings/settings.dart';
import '../render/song_style.dart' show StageColors;
import '../theme.dart';

/// The theme of live mode for [appearance]: the app theme [app] (with the
/// stronger chord colour), always dark, or dark on true black.
ThemeData liveTheme(ThemeData app, LiveAppearance appearance) {
  final base = switch (appearance) {
    LiveAppearance.app => app,
    LiveAppearance.dark => _darkTheme,
    LiveAppearance.black => _blackTheme,
  };
  return base.copyWith(
    extensions: [
      ...base.extensions.values.where((e) => e is! StageColors),
      base.brightness == Brightness.dark ? StageColors.dark : StageColors.light,
    ],
  );
}

/// Built once: the colour scheme is computed from the seed colour.
final _darkTheme = appTheme(Brightness.dark);
final _blackTheme = _black(_darkTheme);

/// [dark] on true black: the page is black, bars and panels very dark grey.
ThemeData _black(ThemeData dark) {
  final scheme = dark.colorScheme.copyWith(
    surface: Colors.black,
    surfaceDim: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0B0B0B),
    surfaceContainer: const Color(0xFF121212),
    surfaceContainerHigh: const Color(0xFF1B1B1B),
    surfaceContainerHighest: const Color(0xFF242424),
  );
  return dark.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    bottomSheetTheme: dark.bottomSheetTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
    ),
  );
}
