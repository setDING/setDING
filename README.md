# RealChord

**Chords for the whole band, on stage, offline.**

RealChord shows bands the chords of their songs on tablets while they perform.
Songs are written in [ChordPro](https://www.chordpro.org/); band leaders put
together sets, and every member opens the same set on their own device and plays
from it in live mode, turning pages with a foot pedal. Everything works without a
network: the app syncs when it is online and never needs it on stage.

> **Status:** early development. The single-device MVP is done, sync with a
> self-hosted backend and the web client exist; versions before 1.0 may still change
> the data model. See the [roadmap](docs/architecture/README.md#8-phases--roadmap-proposal).

## Features

- **ChordPro as the source of truth** – the whole specification is supported in
  phases: sections, grids, tab, conditionals, chord diagrams, images, ABC/Lilypond,
  custom `x_` directives ([ADR-0003](docs/architecture/adr/0003-chordpro-source-format.md),
  [ADR-0012](docs/architecture/adr/0012-full-chordpro-support.md)).
- **Transposition and notation** – transpose per set or personally, chord notation
  B or H, Nashville numbers.
- **Sets** – put songs, breaks and notes together by drag & drop, with a key and
  sequence per song; export as ZIP, text or a printable PDF set list.
- **Live mode** – full screen, screen stays on, page turns by Bluetooth foot pedal,
  keyboard, tap or swipe; every member navigates on their own
  ([ADR-0007](docs/architecture/adr/0007-live-mode.md)).
- **PDF sheet music** attached to songs, available offline
  ([ADR-0009](docs/architecture/adr/0009-pdf-attachments.md)).
- **Personal adjustments** (transposition, capo, font size, notes) as overlays that
  never change the shared song ([ADR-0006](docs/architecture/adr/0006-personal-overlays.md)).
- **Organizations, bands and roles** – songs belong to an organization and are
  shared by its bands; admins manage, members play
  ([ADR-0005](docs/architecture/adr/0005-single-app-with-roles.md),
  [ADR-0017](docs/architecture/adr/0017-organizations.md)).
- **Offline-first sync** with a self-hosted [PocketBase](https://pocketbase.io/)
  server ([ADR-0001](docs/architecture/adr/0001-offline-first.md),
  [ADR-0004](docs/architecture/adr/0004-backend-and-sync.md)).
- **Import** of `.cho`, `.chordpro`, `.chopro` and `.txt` files (also as ZIP,
  e.g. downloaded from SongSelect) and PDF attachments.
- **Web client** for managing songs and sets without installing anything
  ([ADR-0018](docs/architecture/adr/0018-web-client.md)).
- UI in **Swiss Standard German and English**
  ([ADR-0008](docs/architecture/adr/0008-localization.md)).

## Platforms

| Platform | Status |
|---|---|
| Android | Release APK on [GitHub Releases](https://github.com/tafli/RealChord/releases), install and update with Obtainium |
| Windows | Release zip on GitHub Releases (not code-signed) |
| Linux | Release tarball on GitHub Releases, or `make release` |
| Web | Management client, served by the backend |
| iOS | Planned (the Flutter code base supports it, no release build yet) |

## Installation

Download the files of the latest [release](https://github.com/tafli/RealChord/releases):

- **Android:** install [Obtainium](https://github.com/ImranR98/Obtainium), choose
  *Add app* and enter `https://github.com/tafli/RealChord`. Obtainium installs
  RealChord and offers updates when a new release is published.
- **Windows:** unpack `realchord-<version>-windows-x64.zip` and run `realchord.exe`.
  SmartScreen warns on the first start ("More info" → "Run anyway").
- **Linux:** unpack `realchord-<version>-linux-x64.tar.gz` and run `realchord`.
  Requires GTK 3 and libsecret.

Details, checksums and how releases are made: [docs/development/releases.md](docs/development/releases.md).

To try the ChordPro features, import
[`docs/examples/feature-showcase.zip`](docs/examples/feature-showcase.zip)
(see [docs/examples](docs/examples/README.md)).

## Development

Requirements: [Flutter](https://flutter.dev/) (the version is set in the
[`Makefile`](Makefile)), and on Linux `cmake`, `ninja` and the GTK 3 development
files. Android builds need the Android SDK and a JDK 17 or later; `make backend`
downloads PocketBase.

```bash
make setup      # install dependencies, generate code and translations
make dev        # start a test instance with hot reload (own data in .dev-data/)
make backend    # start a local PocketBase with the schema and hooks from server/
make check      # all checks – the test gate before every merge
make help       # list all targets
```

Test instances keep their data in `.dev-data/` and never touch the data of a normally
installed app; `make reset` deletes it. More in [app/README.md](app/README.md),
[docs/development/web.md](docs/development/web.md) and, for running the server,
[docs/operations/server.md](docs/operations/server.md).

### Repository layout

| Path | Content |
|---|---|
| [`app/`](app) | Flutter client (Android, iOS, Windows, Linux, web) |
| [`packages/chordpro/`](packages/chordpro) | Pure Dart ChordPro parser, transposition, notation, Nashville numbers |
| [`server/`](server) | PocketBase migrations and hooks, tested against a real PocketBase |
| [`tool/`](tool) | Check, release, CI and server scripts used by the `Makefile` |
| [`docs/architecture/`](docs/architecture) | Architecture overview and Architecture Decision Records |
| [`docs/development/`](docs/development) | Git workflow, dependencies, releases, web client |
| [`docs/operations/`](docs/operations) | Installing and operating the server |
| [`docs/examples/`](docs/examples) | ChordPro feature showcase |

## Architecture

The architecture and all decisions are documented in
[docs/architecture/README.md](docs/architecture/README.md), with the decisions as
[ADRs](docs/architecture/adr/). Accepted ADRs are binding for every change.

## Contributing

Changes follow the [git workflow](docs/development/git-workflow.md): one issue, one
branch, one pull request, Conventional Commits, squash merge, and all tests
(`make check`) must pass before a merge. External libraries are kept at their newest
versions ([dependencies](docs/development/dependencies.md)). Project language is
English; UI texts go into both ARB files (de-CH and en). Guidance for coding agents
is in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE). The code is largely AI-generated, written by coding agents and
reviewed and directed by the owner.
