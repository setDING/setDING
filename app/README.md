# RealChord app

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

## Running locally on Linux (development only)

Linux is not a release platform (ADR-0002); it is used to try the app quickly.
Requires `cmake`, `ninja` and GTK 3 development files (on Arch: `sudo pacman -S cmake ninja`).

The `Makefile` in the repository root starts **test instances** with their own data
directory (`.dev-data/`, override with `DATA_DIR=...`), so they never touch the data of
a normally started app:

```bash
make            # list all targets
make dev        # test instance with hot reload (r = reload, q = quit)
make start      # build and start a test instance
make reset      # delete the test instance's data (next start begins fresh)
make check      # all checks – the test gate before every merge
```

A keyboard simulates a foot pedal in live mode: arrow keys, Page Up/Down and Space.

Data locations: the database, settings and PDF attachments live in the app's private
support directory (on Linux `~/.local/share/ch.realchord.realchord/`). Older builds
stored the database in the documents folder; it is moved on the next start.
`REALCHORD_DATA_DIR` (development only) overrides the directory for database and PDFs.

## Android APK for manual installation

`make apk` builds a release APK and copies it to
`app/build/realchord-<version>-<commit>.apk`. It needs the Android SDK
(`ANDROID_HOME`, default `~/Android/Sdk`) and a JDK 17 or later.

- **Install via USB:** enable USB debugging on the tablet (Settings → About →
  tap "Build number" seven times, then Developer options → USB debugging), connect
  it and run `make apk-install` (`adb install -r`, keeps the app's data).
- **Install without a cable:** copy the APK to the tablet (cloud drive, chat, USB
  stick), open it in the file manager and allow "Install unknown apps" for that app
  when asked.

The APK is signed with the **debug key of the machine that built it**
(`~/.android/debug.keystore`). An update installs over an earlier version only if
both were built on the same machine; otherwise uninstall the app first, which
deletes its local data (songs and sets of bands come back through sync, the local
library does not). A release signing key and store releases are still open.

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
