# Android integration tests

Unit and widget tests (`make check`) replace the platform with fakes: an
in-memory database, memory file storage, a memory session store, no network.
The integration tests in [`app/integration_test/`](../../app/integration_test/)
run the real app on Android instead (issue #647). They need an emulator or a
device and are therefore **not part of `make check`**; run them before a
release and after changes to platform code (database, files, secure storage,
wake lock, PDF rendering, network, sign-in and sync).

## Running

```bash
make android-test                                    # own headless emulator (default)
make android-test DEVICE=R52M40MRFMR                 # USB device, id from `adb devices`
make android-test TESTS=integration_test/app_test.dart
make android-test EMULATOR_WINDOW=1                  # watch the emulator
```

[`tool/android-test.sh`](../../tool/android-test.sh)

1. picks the device:
   - **Emulator (default):** its own AVD `setding-itest` (`ANDROID_AVD`
     overrides it). If it does not exist, it is created from the newest
     installed Google APIs system image of the host's architecture as a Pixel
     Tablet. The emulator starts headless with a fresh data partition
     (`-wipe-data`, no snapshot), animations are turned off, and it is stopped
     after the run. An emulator of that AVD that is already running is reused
     and kept running (faster when running the tests several times).
   - **Real device:** `DEVICE=<id>`, USB debugging on.
2. starts a local PocketBase with the repository's schema and hooks
   ([`server/bin/itest_backend.dart`](../../server/bin/itest_backend.dart))
   with a user, a band and two songs (one with a PDF), and forwards its port to the device with
   `adb reverse`, so the device reaches it as `http://127.0.0.1:<port>`;
3. runs every `integration_test/*_test.dart` except the performance scenarios
   (`make perf`) with `flutter test -d <device>`, passing the server and the
   account with `--dart-define`.

Requirements: the Android SDK (`ANDROID_HOME`, with `platform-tools`,
`emulator`, `cmdline-tools/latest` and a Google APIs system image for the
emulator), KVM for a fast x86-64 emulator, and Flutter.

## Your installations are safe

The tests build the app as its own application **`app.setding.itest`**
("setDING Test", `SETDING_ANDROID_ITEST=1` in `app/android/app/build.gradle.kts`).
A release (`app.setding`) or beta (`app.setding.beta`) installation on the
device and its data are never touched. The test app is uninstalled before
and after the run, so every run starts like a fresh installation.

`make perf` still runs as `app.setding` in profile mode and refuses to run
next to a release installation ([performance.md](performance.md)).

## Plain HTTP in debug builds

Android allows no plain HTTP by default. Debug builds
(`app/android/app/src/debug/`) allow it to `127.0.0.1`, `localhost` and
`10.0.2.2` (the emulator's alias for the host) only, for the local
PocketBase. Release builds use the main manifest without this configuration;
`app/test/android_manifest_test.dart` checks both.

## The tests

| File | What runs on the device |
|---|---|
| `app_test.dart` | Start-up through `main()` with the real database, files and secure storage; the demo song in the library and on the song screen; a set in live mode with a PDF rendered by the platform's engine, page turns with page-turner keys, no wake-lock warning |
| `platform_test.dart` | Songs and attachment files survive closing and reopening the SQLite file and the storage; the session is kept in the secure storage |
| `sync_test.dart` | Sign-in through the real UI against the local PocketBase over the network, the sync brings the organization's songs onto the device, the session is stored in the secure storage. Skipped without the server of `make android-test` |

Each file runs as its own app start. Tests that call `main()` should stay one
`testWidgets` per file, since the app's services are opened once per process.

## Adding tests

- Wait for real platform work with `pumpUntil` / `pumpFor`
  ([`integration_test/support.dart`](../../app/integration_test/support.dart)),
  not `pumpAndSettle`: database, files and network do not settle on their own.
- Set `language` to `en` in the shared preferences before `main()` when the
  test looks for texts; the device's language would apply otherwise.
- Run platform work inside `tester.runAsync`.
- Keep a test independent of the device: no fixed screen size, no device
  settings beyond what the runner sets.

## Not covered (yet)

MIDI and Bluetooth page turners (need hardware; keys are simulated), audio
output of the metronome, deep links, file import and sharing, iOS and
Windows.
