import 'package:material_ui/material_ui.dart';

/// The app theme for [brightness] (light or dark).
ThemeData appTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3F51B5),
    brightness: brightness,
  ),
  useMaterial3: true,
);
