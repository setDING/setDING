# Release builds

How RealChord is built for distribution: on GitHub Actions from a tag for Linux,
Android and Windows (ADR-0021), and locally for Linux (ADR-0019). iOS and store
releases are not covered yet.

## Releasing a version (CI)

1. Merge a `chore(release): vX.Y.Z` PR that sets `version: X.Y.Z+…` in
   `app/pubspec.yaml` (the build number after `+` is ignored by CI).
2. Tag `main` and push the tag:

   ```bash
   git tag -s vX.Y.Z -m "RealChord X.Y.Z" && git push origin vX.Y.Z
   ```

3. The workflow [`release.yml`](../../.github/workflows/release.yml) builds and
   publishes the GitHub Release `vX.Y.Z` with:

   | File | Content |
   |---|---|
   | `realchord-X.Y.Z-android.apk` | Universal APK, signed with the release key |
   | `realchord-X.Y.Z-linux-x64.tar.gz` | Linux bundle, built like `make release-linux` |
   | `realchord-X.Y.Z-windows-x64.zip` | Windows build with the Visual C++ runtime |
   | `SHA256SUMS` | Checksums of the files above |

The tag must equal `v` + the version in `pubspec.yaml`, otherwise the workflow fails.
The build number (Android `versionCode`) is the workflow's run number. Tags with a
suffix (`v1.2.0-beta.1`) become pre-releases, which Obtainium skips by default.

A manual run (GitHub → Actions → Release → Run workflow, or `gh workflow run Release`)
builds the same files as workflow artifacts without publishing a release.

## Android release key (once, owner)

Android only installs updates signed with the same key, so all releases use one
release key stored in the repository secrets. The owner creates it once:

```bash
make android-keystore
```

This writes `~/.local/share/realchord/android-release.jks` and a `key.properties`
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
2. In Obtainium: **Add app** → source URL `https://github.com/tafli/RealChord` → **Add**.
3. Install RealChord from there. Obtainium checks the GitHub Releases for new
   versions and offers the update.

An app installed earlier with `make apk` (debug key) must be uninstalled first.

## Windows

Unpack the zip and run `realchord.exe`. The build is not code-signed, so Windows
SmartScreen warns on the first start ("More info" → "Run anyway").

## Linux (local)

```bash
make release
```

The result is `app/build/realchord-<version>-<commit>-linux-x64.tar.gz`
(`make release-linux` does the same). It is built from the **committed** state
(`HEAD`); commit first, uncommitted changes only print a warning and are not included.

### Requirements

Docker (`DOCKER=podman` works too). make first builds the Flutter base image
`realchord-ci:<flutter-version>` from `tool/ci/Dockerfile` if it is missing
(`make ci-image` does that by hand), then a local image
`realchord-release-linux:<flutter-version>` with the Linux build dependencies and
runs `flutter build linux --release` in it. Pub packages are cached in the Docker
volume `realchord-release-pub-cache`. CI runs the same target.

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

Unpack the archive on the target machine and run `realchord` in the unpacked folder.
Requires GTK 3 and libsecret, which desktop distributions include.

To add RealChord to the application menu, run `./install-desktop-entry.sh` in the
unpacked folder once (again after moving the folder; `--uninstall` removes it). It
installs a desktop entry and the icon for the current user under
`~/.local/share`. Under Wayland (KDE, GNOME) the window only shows the RealChord
icon with this entry, because the compositor looks the icon up through the
`.desktop` file named after the app ID `app.realchord`.
