# ADR-0035: Windows installer with in-app updates

- **Status:** Proposed
- **Date:** 2026-11-18

## Context

Since ADR-0021 the Windows build is a plain, unsigned zip
(`setding-<version>-windows-x64.zip`). This has three problems for band members:

- **Unknown publisher:** the executable is not code-signed, so Windows SmartScreen
  warns on the first start ("More info" → "Run anyway").
- **No updates:** a new version means downloading the zip and replacing the folder
  by hand. Android has Obtainium for this (ADR-0021), Windows has nothing.
- **No installation:** no Start menu entry and no uninstall entry.

The owner's band uses Android, iOS, macOS and Windows, so Windows is a real target
platform. iOS and macOS use the web client (ADR-0018) for now.

Removing the warning needs a signature that Windows trusts. Every way to get one
verifies the publisher's identity: certificate authorities (Certum, OV/EV
certificates, Azure Artifact Signing) and the Microsoft Store (free for individual
developers since 2025, but with ID and selfie verification). The owner does not
want to send an ID. SmartScreen only checks files that carry the "downloaded from
the internet" mark (Mark of the Web), which browsers set; a file the app downloads
itself does not get it.

## Decision

- **Inno Setup installer** `setding-<version>-windows-x64-setup.exe`, built by the
  release workflow on `windows-latest` from the same folder as the zip (including
  the Visual C++ runtime DLLs). Script: `app/windows/installer/setding.iss`.
  - Installs **per user** into `%LOCALAPPDATA%\Programs\setDING`, without
    administrator rights (`PrivilegesRequired=lowest`), with a Start menu entry,
    an optional desktop icon and an uninstall entry; English and German.
  - A fixed `AppId` identifies the installation: a newer setup **updates it in
    place**, closes a running setDING (`CloseApplications=force`) and replaces
    Flutter's `data` folder as a whole.
  - The data stays in `%APPDATA%` (Flutter's application support folder), outside
    the installation, so updates and uninstalling never touch it.
- **In-app update (Windows, installed with the setup only):**
  - At every start, the app asks GitHub for the latest release
    (`api.github.com/repos/tafli/setDING/releases/latest`; pre-releases are never
    offered) and compares it with its version (SemVer, ADR-0028). No automatic
    retries; offline it simply finds nothing.
  - A newer version is offered in a banner above the navigation ("Later" hides it
    until the next start) and under *Settings → Storage & info → Updates*, where a
    tap checks again. The "Please update setDING" banner (ADR-0029) offers
    "Install" instead of copying the link.
  - **Install** asks first, downloads the setup into a temporary folder, checks it
    against the release's `SHA256SUMS` (deleted on mismatch), starts it with
    `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART` and ends the app. The setup's `[Run]`
    entry starts the new version afterwards.
  - Never without a tap, so an update never restarts the app during a performance.
  - "Installed with the setup" means Inno Setup's uninstaller `unins000.exe` lies
    next to the executable. The portable zip has none and never updates itself (a
    setup would install a second copy elsewhere).
- **No code signing** for now. SmartScreen warns once, when the downloaded setup is
  first run; updates downloaded by the app do not carry the internet mark.
- The **zip stays** as a portable alternative.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep the zip only (status quo) | No work | SmartScreen warning, manual updates, no Start menu entry |
| Microsoft Store (MSIX) | Free for individuals, signed by Microsoft (no warning), Store updates | ID and selfie verification (owner declined), certification delay per release, privacy policy and MSIX sandbox |
| Installer signed with an own certificate (Certum open source, Azure Artifact Signing, OV/EV) | Own name as publisher, no warning once reputation is built | Identity verification, costs per year, CI signing with hardware tokens is awkward |
| Installer signed by the SignPath Foundation | Free for open-source projects, CI integration | Publisher shown is "SignPath Foundation", project must be admitted; can be added later without changing this decision |
| Self-distributed MSIX with `.appinstaller` | Automatic updates by Windows | Needs a trusted signing certificate anyway; self-signed ones must be imported on every device |
| winget package | Command-line install and update without SmartScreen prompt | Users must run `winget upgrade`; manifest PRs per release |
| Automatic silent update without asking | No tap needed | Could restart the app on stage; the person decides when |
| **Inno Setup + in-app update (chosen)** | No account or identity check, free, per-user install without admin rights, updates like Obtainium, works offline-first | One SmartScreen warning on the first install, publisher shown as unknown, relies on GitHub releases and the checksum file of the same release |

## Consequences

- Windows users install once (one SmartScreen confirmation) and then update from
  inside the app; running a newer setup by hand works as well.
- The app talks to GitHub once per start (only the Windows app installed with the
  setup); GitHub sees the IP address. Unauthenticated API requests are limited to
  60 per hour and IP, far above one per start.
- The checksum comes from the same GitHub release as the setup: it protects against
  broken or truncated downloads, not against a compromised repository. A signature
  (e.g. SignPath) would add that later.
- Switching from the zip to the setup keeps the data: both use the same
  `%APPDATA%` folder. The old zip folder can be deleted.
- The setup itself is only tested by a release build on GitHub Actions (there is no
  Windows machine in `make check`); the update logic (release lookup, checksum,
  download, installed-with-setup check) and the UI are covered by `make check`.
- Inno Setup's German messages are German German (they may contain "ß"); the app UI
  stays de-CH (ADR-0008).

## Decision log

- 2026-11-18: First proposed (#494) as distribution through the Microsoft Store.
  The owner declined the Store's ID and selfie verification; changed to an Inno
  Setup installer with in-app updates from the GitHub releases, no code signing for
  now.

## Open points

- Code signing (e.g. SignPath Foundation) if the one-time warning bothers users.
- Registering the `setding://` invitation links on Windows (the installer could add
  the protocol to the registry).
- Whether to keep the zip in the long run.
