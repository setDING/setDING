# AGENTS.md

Guidance for AI coding agents (and humans) working on this repository.

## Project

RealChord (formerly the working title BandChords) is an app that shows bands the chords of their songs (ChordPro) on tablets
(Android, iOS, Windows) during a performance. Admins put together sets; band members
view and play them, offline-first.

## Architecture and ADRs

The architecture is documented in [`docs/architecture/`](docs/architecture/):

- [`docs/architecture/README.md`](docs/architecture/README.md) – overview, building blocks, domain model, roadmap, open questions, ADR index
- [`docs/architecture/adr/`](docs/architecture/adr/) – Architecture Decision Records (ADRs)

**Before you start a task**, read the README and the ADRs relevant to it.
Accepted ADRs are binding. Do not silently deviate from them.

### Keeping the ADRs up to date (mandatory)

The documentation must always reflect the current state of the project:

- **New architectural decision** (technology, library, data model, sync, security, platform, UX principle with structural impact): create a new ADR from [`adr/template.md`](docs/architecture/adr/template.md), using the next free number (`NNNN-short-title.md`).
- **Change to an existing decision**: update the ADR and add a dated entry to its *Decision log*. If a decision is replaced, set the old ADR to `Superseded by ADR-XXXX` instead of deleting it.
- **Implementation deviates from an ADR**: stop and clarify with the user first; then either adapt the code or update the ADR. Never leave the two out of sync.
- **Open points**: when an open point in an ADR is resolved, move it to the *Decision log*.
- **Always update the README** together with the ADR: the solution strategy table, the domain model, the roadmap, the open questions and the ADR index (number, title, status).
- Status values: `Proposed`, `Accepted`, `Rejected`, `Superseded by ADR-XXXX`. Only the user can accept or reject an ADR; agents create ADRs as `Proposed`.

## Local commands

Use the `Makefile` in the repository root (`make help`): `make check` is the test gate,
`make dev` / `make start` run an isolated local test instance on Linux, `make reset`
deletes its data. `make release` builds the distributable Linux package
(see [`docs/development/releases.md`](docs/development/releases.md), ADR-0019). `make server-*` installs and operates the PocketBase server over SSH
(see [`docs/operations/server.md`](docs/operations/server.md), ADR-0014).

## Git workflow (mandatory)

Every change follows [`docs/development/git-workflow.md`](docs/development/git-workflow.md) (ADR-0010). In short:

- Work on an issue; one issue = one branch (`<type>/<issue>-<slug>`) = one PR. **Never commit directly to `main`.**
- Conventional Commits in English, with a `Co-Authored-By` trailer for agents.
- Before marking a PR ready: rebase on `main`, run the checks, update ADRs/docs, complete both ARB files, self-review.
- **Test gate: all tests must pass before every merge**, run on the final branch state rebased on `main`. Never skip, delete or weaken tests to get green. New or changed behaviour comes with tests.
- Squash merge only. An agent may merge its own PR when the test gate (full local `make check`) is satisfied and no "human must decide" rule applies; otherwise label `needs-human`.
- Never end a session with unpushed work: commit, push, and leave a handover comment on the PR.
- **CI is manual-only during early development**: do not wait for it; local green tests are enough. Re-enable it as a required check when heading towards version 1 (ADR-0010).
- Remote: self-hosted **Forgejo** (`github.com/tafli/RealChord`), CLI `fj` (forgejo-cli, logged in on the development machine): issues, PRs and squash merges go through `fj`. Without a login, fall back to workflow section 11.

## ChordPro features

`docs/examples/feature-showcase.cho` uses every supported ChordPro feature and is a
regression test (package and app). When adding or changing a ChordPro feature, extend
the showcase and its tests, and run `make examples` to rebuild the ZIP.

RealChord-specific directives are custom directives in the sense of the ChordPro
specification and **must start with `x_`** (e.g. `{x_sequence}`); never add directives
without this prefix that the specification does not define.

## Language

- **Project language is English**: code, identifiers, comments, documentation, ADRs, commit messages, pull requests, issues and file names.
- **Exception: user-facing UI texts.** The app UI is available in **Swiss Standard German (`de-CH`, no "ß")** and **English** (see ADR-0008). UI texts are never hard-coded; they go into the ARB files (`app_de.arb`, `app_en.arb`). Every new UI text must be added in both languages.
- Conversation with the user may be in German; this does not change the project language.

## Key decisions at a glance

See the ADR index in the architecture README for the current status. In short:

- Offline-first, local SQLite on every device (ADR-0001)
- Flutter client for Android, iOS, Windows (ADR-0002)
- ChordPro text is the single source of truth, parsed in the client (ADR-0003)
- PocketBase, self-hosted, revision-based sync (ADR-0004)
- One app with roles admin/member, several bands per user (ADR-0005)
- Personal adjustments as overlays, never modifying the shared song (ADR-0006)
- Live mode with pedal support, no leader sync (ADR-0007)
- UI localized in de-CH and en, selectable in the settings (ADR-0008)
- PDF sheet music attachments per song, available offline (ADR-0009)
- Git workflow with test gate before every merge (ADR-0010)
- No SongSelect API integration; manual ChordPro import (ADR-0011)
- Whole ChordPro specification supported, in phases (ADR-0012)
- Server: Debian LXC on Proxmox, PocketBase via systemd, Cloudflare Tunnel, provisioned with `make server-install` (ADR-0014)
- Server data model as PocketBase migrations and hooks in `server/`, tested against a real PocketBase in `make check`; `make backend` runs it locally (ADR-0015)
- Organizations above bands: songs belong to the organization and are shared by its bands, users only see people of their organizations (ADR-0017)
- Sign-in through the `SyncBackend` interface, session in secure storage and kept while offline (ADR-0016)
- Linux release with `make release`, built in a Debian container (ADR-0019)
