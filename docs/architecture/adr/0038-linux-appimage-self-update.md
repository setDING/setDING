# ADR-0038: Linux AppImage with in-app updates

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

Since ADR-0019 the Linux release is a tar.gz with the Flutter bundle: unpack it and
start `setding`. A new version means downloading and unpacking it again by hand.
The update check (ADR-0036) tells Linux users about a new version, but cannot
install it. On Windows the app installs updates itself since ADR-0035; Linux should
work the same way.

## Decision

- **AppImage next to the tar.gz:** the release build (`make release-linux`, the same
  Debian container as ADR-0019, in CI through ADR-0021) also packs the bundle as
  `setding-<version>-linux-x64.AppImage`, a single executable file.
  - The AppDir is the bundle plus a start script (`AppRun`), the desktop entry
    (`app.setding.desktop`, from `app/linux/packaging`) and the icon.
  - Built with **appimagetool 1.9.1** and the **type-2 runtime 20251108** (both
    MIT; the runtime contains libfuse, LGPL-2.1, statically), downloaded into the
    release image and pinned by version and SHA-256 (`tool/release/linux.Dockerfile`).
    The runtime's licence ships in the AppImage (`licenses/`).
  - Like the tar.gz, the AppImage uses GTK 3 and libsecret of the system (no
    libraries bundled); the type-2 runtime needs no libfuse2, only FUSE
    (`fusermount`) on the system.
  - No embedded update information (zsync) for external tools: the app updates
    itself.
- **In-app update (AppImage only):** the AppImage runtime sets `APPIMAGE` to the
  file the app runs from; an unpacked tar.gz has none and never updates itself.
  Everything else is the same as ADR-0035: the version comes from the update check
  (ADR-0036), *Install* sits in the one-time SnackBar, the *Storage & info* tile and
  the "Please update" banner (ADR-0029), and nothing happens without a tap.
  - **Install** asks first, downloads the AppImage of the release `v<version>` next
    to the running file (`<file>.update`), checks it against the release's
    `SHA256SUMS` (deleted on mismatch), makes it executable like the old file and
    renames it over the old file in one step, so a failure never leaves a broken
    AppImage. The file keeps its name and place (desktop entries and launchers keep
    working).
  - Then the app ends and the new version starts two seconds later (the Linux app
    is not single-instance; the delay keeps the two from sharing the database).
  - If the folder of the AppImage is not writable, the update fails with the usual
    message; the person can download the new AppImage by hand.
- **Application menu entry (AppImage only, #1006):** under *Storage & info → This
  device*, **Add to application menu** writes the desktop entry
  `app.setding.desktop` (from the template in the bundle, `Exec` = the AppImage
  file, marked `X-setDING-AppImage=true`) and the icon (PNG 256 px and SVG, from
  the bundle's `data/`) to `$XDG_DATA_HOME` (`~/.local/share`), like
  `install-desktop-entry.sh` of the tar.gz, then refreshes the menu
  (`update-desktop-database`, `kbuildsycoca6/5`, each optional). **Remove** deletes
  them again. Never without a tap. Under Wayland the entry also gives the window
  its icon (ADR-0019).
  - The in-app update keeps the file's name and place, so the entry keeps
    working. If an entry made by an AppImage starts a file that is gone (the
    AppImage was moved or renamed), the app points it at itself when it starts;
    an entry of the tar.gz or of another AppImage that still exists is left
    alone (*Add* replaces it).
- The **tar.gz stays** for people who prefer it (and for `install-desktop-entry.sh`).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| tar.gz only (status quo) | No work | Manual updates |
| tar.gz with in-app update (unpack next to it, swap folders) | No new format | Swapping a folder is not atomic, needs a writable parent folder, harder to restart from |
| AppImage with zsync update information and AppImageUpdate | Standard tooling, delta updates | Needs an extra tool; does not fit the app's own update flow (ADR-0035/0036) |
| Flatpak on Flathub | Updates by the system, desktop integration, sandbox | Flathub review, build from source in their builder (awkward for Flutter), every release waits for Flathub |
| .deb with an own APT repository | Native updates on Debian/Ubuntu | Only Debian-like distributions; a signed repository to host |
| **AppImage with in-app update (chosen)** | One file, atomic replacement, same flow as Windows, no account or review | Needs FUSE on the system; the desktop entry is added from inside the app (#1006); not signed |

## Consequences

- Linux users who run the AppImage update from inside the app; the tar.gz still
  needs manual updates.
- Every release must contain the AppImage and `SHA256SUMS` under the names above
  (the `publish` job uploads everything the Linux job builds).
- As on Windows, the checksum comes from the same GitHub release: it protects
  against broken downloads, not against a compromised repository.
- The release image downloads two binaries from GitHub when it is built; their
  checksums are pinned, so a changed file fails the build. Newer versions are
  taken over by changing version and checksum together.
- The AppImage is one more release asset for the SBOMs of ADR-0037 (open point
  there): the components of the tar.gz plus the type-2 runtime and libfuse.
- The update logic (AppImage detection, verified download, replacement) is covered
  by `make check`; building and starting the AppImage only by a release build.

## Decision log

- 2026-11-18: Proposed (#503) after the Windows in-app update (ADR-0035) worked
  in v0.13.0; the owner chose an AppImage next to the tar.gz.
- 2026-11-18: Accepted by the owner after the AppImage of the test build (#504)
  started on the desktop; the in-app update is tested with the next release.
- 2026-11-18: Renumbered from ADR-0037 to ADR-0038: the SBOM ADR (#506) took
  number 0037 while this one was in review.
- 2026-11-23: Open point "desktop integration without extra tools" resolved
  (#1006): the AppImage adds its own application menu entry and icon on
  request (*Storage & info*), and the entry follows a moved AppImage. The owner
  chose this over shipping the icon as a separate release asset.

## Open points

- Signing the AppImage (embedded GPG signature) together with the Windows signing
  question of ADR-0035.
