# ADR-0021: Release builds on GitHub Actions, Android via Obtainium

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

The git workflow (ADR-0010, section 10) plans a CI release build triggered by a
`vX.Y.Z` tag, but it did not exist: the Linux package was built locally with
`make release` (ADR-0019), Android only as a sideloaded `make apk` signed with the
development machine's debug key, and Windows not at all. Since the move to GitHub
(#129), GitHub-hosted Linux and Windows runners are available.

Band members install the Android app outside the Play Store. They should get updates
without someone copying APK files around. [Obtainium](https://github.com/ImranR98/Obtainium)
installs and updates Android apps directly from the releases of a GitHub repository.
Android only installs an update that is signed with the **same key** as the installed
app, so the APK must be signed with a stable release key, not a per-machine debug key.

## Decision

- **Workflow `.github/workflows/release.yml`**, triggered by a `v*` tag (and manually
  for test builds, which publish nothing). Separate jobs build:
  - **Linux** with `make release-linux` on `ubuntu-latest`, i.e. in the same Debian
    container with the ISA check as locally (ADR-0019) →
    `realchord-<version>-linux-x64.tar.gz`.
  - **Android** with `flutter build apk --release` (one universal APK) →
    `realchord-<version>-android.apk`.
  - **Windows** with `flutter build windows --release` on `windows-latest`, zipped
    together with the Visual C++ runtime DLLs → `realchord-<version>-windows-x64.zip`.
- **Version:** the tag must match the version in `app/pubspec.yaml` (`v` + version),
  otherwise the release fails. The **build number is the workflow's run number**
  (ADR-0010), so the Android `versionCode` grows with every release.
- **GitHub Release:** a `publish` job creates the release for the tag with generated
  notes, all three packages and a `SHA256SUMS` file. Only tags with a suffix
  (`v1.2.0-beta.1`) become pre-releases, because Obtainium ignores pre-releases by
  default.
- **Android signing:** one release key (PKCS12, RSA 4096, alias `realchord`), created
  once by the owner with `make android-keystore` (`tool/release/android-keystore.sh`),
  which stores it as the repository secrets `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. The
  workflow writes `app/android/key.properties` from them; Gradle signs release builds
  with it and falls back to the debug key when the file is missing (local
  `make apk`). A tag build without the secrets fails rather than publishing an APK
  with a throwaway key.
- **Obtainium:** users add `https://github.com/tafli/RealChord` as an app source; the
  release contains exactly one APK, so no filter is needed.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep building locally (`make release`, `make apk`) | No CI setup | Windows needs a Windows machine; APK signed with a per-machine debug key, so updates break between machines; manual upload |
| Google Play (internal testing) or F-Droid | Store updates, Play signing | Developer account and review (Play), reproducible-build requirements and own repository (F-Droid); overkill for band members during early development |
| Split APKs per ABI | ~3× smaller downloads | Obtainium needs an APK filter per device; one universal APK is simpler for now |
| Obtainium from GitHub Releases (chosen) | No store account, automatic update checks, free for public repositories | Users must install Obtainium; the release key must be kept safe forever |

## Consequences

- A release is: version bump PR (`chore(release): vX.Y.Z`), then push the tag
  `vX.Y.Z` on `main`. CI builds and publishes everything; no local release build needed.
- The release key is a long-lived secret: if it is lost, installed apps cannot be
  updated (users must uninstall and reinstall, losing local data). The owner keeps a
  backup outside GitHub.
- APKs built locally with `make apk` (debug key) cannot be updated by release APKs
  and vice versa; switching needs an uninstall.
- The Windows build is a plain zip (no installer, no code signing): SmartScreen
  warns on first start.
- The tests (`make check`) are not re-run in the release workflow; the tag is on
  `main`, where every merge passed the test gate.

## Decision log

- 2026-11-16: Proposed (#137) on the owner's request for Linux, Android and Windows
  builds on GitHub Actions with Android installable via Obtainium. The Android build
  needed AGP 9.1.1 (Flutter's minimum) instead of 9.1.0.
- 2026-11-16: Accepted by the owner.
- 2026-11-17: Application ID `app.realchord` instead of `ch.realchord.realchord`
  (#298). For Android this is a different app: installs of the earlier test
  releases (up to v0.4.0) cannot be updated to it; uninstall them and add the app
  to Obtainium again. Not live yet, so no migration.

## Open points

- Owner creates the release key (`make android-keystore`) and backs it up.
- iOS build (needs a macOS runner and an Apple developer account).
- Windows installer (MSIX/Inno Setup) and code signing; Linux packaging (AppImage/Flatpak).
- Split APKs per ABI if the APK size becomes a problem.
