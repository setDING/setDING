import 'package:material_ui/material_ui.dart';

import '../../settings/song_display.dart';

/// Tones of the song display palette (ADR-0033): one for light and one for
/// dark backgrounds, each with a contrast of at least 4.5:1 on the
/// backgrounds of the app and of live mode (tested).
const songColorTones = <SongColor, ({Color light, Color dark})>{
  SongColor.blue: (light: Color(0xFF1F4FBF), dark: Color(0xFF7AA7FF)),
  SongColor.amber: (light: Color(0xFF8F5400), dark: Color(0xFFFFC54D)),
  SongColor.red: (light: Color(0xFFB3261E), dark: Color(0xFFFF8A80)),
  SongColor.green: (light: Color(0xFF1E7B3A), dark: Color(0xFF7BD88F)),
  SongColor.teal: (light: Color(0xFF00696B), dark: Color(0xFF5ED6D0)),
  SongColor.purple: (light: Color(0xFF6A3FB5), dark: Color(0xFFC3A6FF)),
  SongColor.pink: (light: Color(0xFFA8326E), dark: Color(0xFFFF9CC8)),
  SongColor.grey: (light: Color(0xFF5F6470), dark: Color(0xFFA3A8B4)),
  SongColor.blackWhite: (light: Color(0xFF000000), dark: Color(0xFFFFFFFF)),
};

/// The tone of [color] on a background of [brightness]; null for
/// [SongColor.auto], which keeps the element's own colour.
Color? songColorValue(SongColor color, Brightness brightness) {
  final tones = songColorTones[color];
  if (tones == null) return null;
  return brightness == Brightness.dark ? tones.dark : tones.light;
}
