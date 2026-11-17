# Release builds

How setDING is built for distribution: on GitHub Actions from a tag for Linux,
Android and Windows (ADR-0021), and locally for Linux (ADR-0019). iOS and store
releases are not covered yet.

## Releasing a version (CI)

1. Merge a `chore(release): vX.Y.Z` PR that sets `version: X.Y.Z+…` in
   `app/pubspec.yaml` (the build number after `+` is ignored by CI).
   Choose the number by the rules in [Version numbers](#version-numbers).
2. Tag `main` and push the tag:

   ```bash
   git tag -s vX.Y.Z -m "setDING X.Y.Z" && git push origin vX.Y.Z
   ```

3. The workflow [`release.yml`](../../.github/workflows/release.yml) builds and
   publishes the GitHub Release `vX.Y.Z` with:

   | File | Content |
   |---|---|
   | `setding-X.Y.Z-android.apk` | Universal APK, signed with the release key |
   | `setding-X.Y.Z-linux-x64.tar.gz` | Linux bundle, built like `make release-linux` |
   | `setding-X.Y.Z-windows-x64.zip` | Windows build with the Visual C++ runtime |
   | `SHA256SUMS` | Checksums of the files above |

The tag must equal `v` + the version in `pubspec.yaml`, otherwise the workflow fails.
The build number (Android `versionCode`) is the workflow's run number. Tags with a
suffix (`v1.2.0-beta.1`) become pre-releases, which Obtainium skips by default.

A manual run (GitHub → Actions → Release → Run workflow, or `gh workflow run Release`)
builds the same files as workflow artifacts without publishing a release.

## Version numbers

setDING uses Semantic Versioning for the whole product (ADR-0028). The rules are
about whether devices still work with the server:

| Bump | When |
|---|---|
| **Major** | Clients of the previous major version no longer work correctly with the server or data; all devices of a band must update |
| **Minor** | New features that older clients of the same major version tolerate (new fields they ignore, automatic local migrations) |
| **Patch** | Fixes only, nothing new and nothing incompatible |

Before 1.0.0, a minor bump also covers incompatible changes. Take the highest bump
implied by the commits since the last tag (`git log --oneline vLAST..`): `feat` →
minor, `fix`/`perf` → patch, a breaking commit (`!`) → major (minor before 1.0.0).
When devices must be updated, start the release notes with an **"Update required"**
section. The server is deployed from `main`, so a server change must not break
released clients of the current major version.

### Releases that require an update

The server refuses apps older than `MIN_CLIENT_VERSION` in
`server/pb_hooks/lib/compat.js` with HTTP 426, and the app asks for an update
(ADR-0029). For a release with an incompatible change:

1. The PR with the incompatible change raises `MIN_CLIENT_VERSION` to the coming
   release version (e.g. `1.0.0`).
2. Tag the release and wait until the GitHub Release is published, so the new APK
   and packages can be downloaded (Obtainium).
3. Only then deploy the server with `make server-install`. Deploying first would
   lock every band out before an update exists.

## Android release key (once, owner)

Android only installs updates signed with the same key, so all releases use one
release key stored in the repository secrets. The owner creates it once:

```bash
make android-keystore
```

This writes `~/.local/share/setding/android-release.jks` and a `key.properties`
next to it (override the path with `ANDROID_KEYSTORE=…`), and sets the secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD` with `gh`. **Back up both files** (e.g. in a password
manager): if the key is lost, installed apps can no longer be updated. Never commit
them; `key.properties` and `*.jks` are ignored by git.

To sign a local `make apk` with the release key, copy that `key.properties` to
`app/android/key.properties`. Without it, local builds use the machine's debug key;
such an APK cannot be updated by a release APK (uninstall first).

## Installing on Android with Obtainium

1. Install [Obtainium](https://github.com/ImranR98/Obtainium) (from its GitHub
   releases or F-Droid).
2. In Obtainium: **Add app** → source URL `https://github.com/tafli/setDING` → **Add**.
3. Install setDING from there. Obtainium checks the GitHub Releases for new
   versions and offers the update.

An app installed earlier with `make apk` (debug key) must be uninstalled first.

## Windows

Unpack the zip and run `setding.exe`. The build is not code-signed, so Windows
SmartScreen warns on the first start ("More info" → "Run anyway").

## Linux (local)

```bash
make release
```

The result is `app/build/setding-<version>-<commit>-linux-x64.tar.gz`
(`make release-linux` does the same). It is built from the **committed** state
(`HEAD`); commit first, uncommitted changes only print a warning and are not included.

### Requirements

Docker (`DOCKER=podman` works too). make first builds the Flutter base image
`setding-ci:<flutter-version>` from `tool/ci/Dockerfile` if it is missing
(`make ci-image` does that by hand), then a local image
`setding-release-linux:<flutter-version>` with the Linux build dependencies and
runs `flutter build linux --release` in it. Pub packages are cached in the Docker
volume `setding-release-pub-cache`. CI runs the same target.

### Why a container

A binary linked on the development machine (CachyOS with `znver4` repositories) is
marked as requiring x86-64-v4 and does not start on CPUs without AVX-512 ("CPU ISA
level is lower than required"). The Debian container links against a baseline glibc.
`tool/release/check-isa.sh` fails the build if any file in the bundle requires more
than x86-64-v2; it can also check any bundle by hand:

```bash
tool/release/check-isa.sh app/build/linux/x64/debug/bundle
```

### Installing

Unpack the archive on the target machine and run `setding` in the unpacked folder.
Requires GTK 3 and libsecret, which desktop distributions include.

To add setDING to the application menu, run `./install-desktop-entry.sh` in the
unpacked folder once (again after moving the folder; `--uninstall` removes it). It
installs a desktop entry and the icon for the current user under
`~/.local/share`. Under Wayland (KDE, GNOME) the window only shows the setDING
icon with this entry, because the compositor looks the icon up through the
`.desktop` file named after the app ID `app.setding`.
