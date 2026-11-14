# BandChords app

Flutter client for Android, iOS and Windows (ADR-0002). See the
[architecture docs](../docs/architecture/README.md) for decisions and scope.

## Development

```bash
flutter pub get
dart run build_runner build   # after changing lib/data/database.dart
flutter gen-l10n              # after changing lib/l10n/*.arb (also runs on build)
flutter run
```

Checks (format, analysis, tests) for the whole repository: `../tool/check.sh`.

Screenshots with real fonts for visual review (not part of the test suite):

```bash
flutter test test_screenshots   # writes build/screenshots/*.png
```

## Structure

| Path | Content |
|---|---|
| `lib/data/` | Drift database, repositories, attachment storage, import/export |
| `lib/settings/` | Device settings (language, notation, Nashville, live mode) |
| `lib/l10n/` | UI texts: `app_de.arb` (reference, Swiss German) and `app_en.arb` |
| `lib/ui/render/` | ChordPro renderer and auto-fit layout |
| `lib/ui/live/` | Live mode (pedal/keyboard, tap zones, PDF) |
| `lib/ui/songs/`, `lib/ui/sets/` | Library, editor, sets |
| `../packages/chordpro/` | Pure Dart ChordPro parser, transposition, notation, Nashville |
