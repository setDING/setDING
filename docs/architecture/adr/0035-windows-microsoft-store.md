# ADR-0035: Windows app through the Microsoft Store

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

Removing the warning needs a code-signing certificate. Since 2023 classic OV/EV
certificates require a hardware token or HSM (awkward in CI, roughly 200–500 USD per
year), and even signed files get SmartScreen warnings until the certificate has
built up reputation. An installer (e.g. Inno Setup) would add a Start menu entry and
in-place updates, but neither signing nor automatic updates.

Since September 2025, registering as an **individual developer** in the Microsoft
Store (Partner Center) is free. Microsoft signs Store packages itself, and the Store
updates installed apps automatically.

## Decision

- The Windows app is published as an **MSIX package in the Microsoft Store**, as a
  free app under an individual developer account of the owner.
- The package is built with the [`msix`](https://pub.dev/packages/msix) pub package
  (`msix_config` in `app/pubspec.yaml`, Store mode). Its identity (identity name,
  publisher, publisher display name) comes from the app reserved in Partner Center.
  The MSIX version is derived from the app version and the build number
  (ADR-0021).
- The **release workflow** builds the MSIX on `windows-latest` next to the zip and
  submits it to the Store with the Microsoft Store Developer CLI (`msstore`,
  `microsoft/setup-msstore-cli`). The Partner Center API credentials (tenant ID,
  client ID, client secret, seller ID) are repository secrets. Manual test builds
  only build the package and submit nothing, like the other platforms. The first
  submission (Store listing, screenshots, age rating) is done once by hand in
  Partner Center.
- The **zip stays** as a portable alternative (Windows without the Store, e.g.
  LTSC, or for testing), unchanged.
- The Store listing needs a **privacy policy**; it is published on the website
  (ADR-0030) in de-CH and en.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep the zip only (status quo) | No work | SmartScreen warning, manual updates, no Start menu entry |
| Installer (Inno Setup), unsigned | In-place updates, Start menu, no admin rights needed (per-user install) | Still "unknown publisher", no automatic updates |
| Installer, signed with an own certificate (Certum open source, Azure Artifact Signing, OV/EV) | Own name as publisher, no store review | Costs per year, CI signing with hardware tokens is awkward, Azure signing is restricted by country for individuals, SmartScreen reputation still has to build up, still no automatic updates |
| Installer signed by the SignPath Foundation | Free for open-source projects, CI integration | Publisher shown is "SignPath Foundation", project must be admitted, no automatic updates |
| Self-distributed MSIX with `.appinstaller` | Automatic updates without the Store | Needs a trusted signing certificate anyway; self-signed ones must be imported on every device |
| winget package | Command-line install and update | Users must use winget; no update without running it; manifest PRs per release |
| **Microsoft Store (chosen)** | Free, signed by Microsoft (no warning), automatic updates, clean install and uninstall | Store certification per release (hours to days), Partner Center account with ID verification, privacy policy required, MSIX sandbox differences |

## Consequences

- Windows users install setDING from the Store and get updates like any Store app;
  no SmartScreen warning.
- **Releases reach Windows with a delay:** each version goes through Store
  certification. With the minimum client version (ADR-0029), a release that raises
  the minimum must wait until the Store version is published before
  `make server-release`; otherwise Store users are locked out (HTTP 426) until the
  update arrives.
- **Switching from the zip to the Store version is a new installation:** a packaged
  app keeps its data in its own package folder (`%LOCALAPPDATA%\Packages\…`), not
  where the zip build stored it. Users sign in again and the data is synced from the
  server; changes not yet synced in the zip version must be synced before switching.
- Packaged apps run with MSIX restrictions (file system virtualization, declared
  capabilities such as `internetClient`); the app is tested as an MSIX before the
  first submission, including file pickers for ChordPro/PDF import and the
  `setding://` invitation links (protocol activation must be declared in the
  manifest).
- The owner keeps the Partner Center account and its API credentials; losing access
  means updates can no longer be published under the same Store entry.
- Store updates through the CLI only work for free products; setDING is free.

## Decision log

- 2026-11-18: Proposed (#494) after the owner asked how to get rid of the "unknown
  publisher" warning and whether an installer makes sense. The owner prefers the
  Microsoft Store because it is free and the band uses Windows next to Android,
  iOS and macOS.

## Open points

- Owner registers as an individual developer in Partner Center, reserves the app
  name and creates the API credentials (Entra ID app) for the release workflow.
- Implementation: `msix_config`, release workflow job, privacy policy page,
  user documentation (install from the Store).
- Whether to keep the zip in the long run once the Store version is established.
