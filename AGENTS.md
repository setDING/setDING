# AGENTS.md

Guidance for AI coding agents (and humans) working on this repository.

## Project

setDING (called RealChord until 2026-11-17, working title BandChords) is an app that shows bands the chords of their songs (ChordPro) on tablets
(Android, iOS, Windows) during a performance. Admins put together sets; band members
view and play them, offline-first.

## License

The project is licensed under the [MIT License](LICENSE). The code is largely
AI-generated (by coding agents, reviewed and directed by the owner). New
dependencies, fonts and other assets must have a licence compatible with MIT and
ship their licence notice; never copy code under an incompatible licence (e.g. GPL)
into the repository.

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
deletes its data. `make perf` measures performance on a USB-connected Android device (see [`docs/development/performance.md`](docs/development/performance.md)). `make branding` regenerates the splash screens and icons from the logo sources (see [`docs/development/branding.md`](docs/development/branding.md)). `make web` builds the web client (see [`docs/development/web.md`](docs/development/web.md), ADR-0018), `make release` builds the distributable Linux package
(see [`docs/development/releases.md`](docs/development/releases.md), ADR-0019). `make server-*` installs and operates the PocketBase server over SSH; after a release, `make server-release` deploys it from the tag once the release build passed
(see [`docs/operations/server.md`](docs/operations/server.md), ADR-0014).

## Git workflow (mandatory)

Every change follows [`docs/development/git-workflow.md`](docs/development/git-workflow.md) (ADR-0010). In short:

- Work on an issue; one issue = one branch (`<type>/<issue>-<slug>`) = one PR. **Never commit directly to `main`.**
- **Every change happens in its own git worktree** (`git worktree add -b <branch> ../setDING-worktrees/<branch-with-dashes> origin/main`); the project folder always stays on `main` and is only fast-forwarded (`git pull --ff-only`). Remove the worktree after the merge.
- Conventional Commits in English; **every commit** (including squash merges) carries the `Co-Authored-By: Claude …` trailer.
- Before marking a PR ready: rebase on `main`, run the checks, update ADRs/docs, complete both ARB files, self-review.
- **Test gate: all tests must pass before every merge**, run on the final branch state rebased on `main`. Never skip, delete or weaken tests to get green. New or changed behaviour comes with tests.
- Squash merge only; afterwards delete the branch on the remote and locally (`git branch -D`). An agent may merge its own PR when the test gate (full local `make check`) is satisfied and no "human must decide" rule applies; otherwise label `needs-human`.
- Never end a session with unpushed work: commit, push, and leave a handover comment on the PR.
- **CI is manual-only during early development**: do not wait for it; local green tests are enough. Re-enable it as a required check when heading towards version 1 (ADR-0010).
- Remote: **GitHub** (`github.com/tafli/setDING`), CLI `gh` (logged in on the development machine): issues, PRs and squash merges go through `gh`. Without a login, fall back to workflow section 11.
- Commits use the owner's global git identity and are **GPG-signed**; never set a repository-local identity or commit unsigned. Squash merges on GitHub use `gh pr merge --author-email andi@theboss.ch`. Every commit carries the `Co-Authored-By` trailer.

## External libraries (mandatory)

External libraries are always used in their **newest version** (owner rule,
[`docs/development/dependencies.md`](docs/development/dependencies.md)).
`make check` fails on outdated libraries (`tool/check-deps.sh`); upgrade with
`make upgrade`. Only deliberate pins marked `# Pinned …` in `pubspec.yaml`
are exempt. When adding a library, use its latest version.

## ChordPro features

`docs/examples/feature-showcase.cho` uses every supported ChordPro feature and is a
regression test (package and app). When adding or changing a ChordPro feature, extend
the showcase and its tests, and run `make examples` to rebuild the ZIP.

setDING-specific directives are custom directives in the sense of the ChordPro
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
- Live mode with tap/swipe and page turner/keyboard page turns, no leader sync (ADR-0007)
- UI localized in de-CH and en, selectable in the settings (ADR-0008)
- PDF sheet music attachments per song, available offline (ADR-0009)
- Git workflow with test gate before every merge (ADR-0010)
- No SongSelect API integration; manual ChordPro import (ADR-0011)
- Whole ChordPro specification supported, in phases (ADR-0012)
- Server: Debian LXC on Proxmox, PocketBase via systemd, Cloudflare Tunnel, provisioned with `make server-install`, updated after each release with `make server-release` (ADR-0014)
- Server data model as PocketBase migrations and hooks in `server/`, tested against a real PocketBase in `make check`; `make backend` runs it locally (ADR-0015)
- Organizations above bands: songs belong to the organization and are shared by its bands, users only see people of their organizations (ADR-0017)
- Sign-in through the `SyncBackend` interface, session in secure storage and kept while offline (ADR-0016)
- Linux release with `make release`, built in a Debian container (ADR-0019)
- Release builds for Linux, Android and Windows on GitHub Actions from a `vX.Y.Z` tag; Android via Obtainium, signed with the release key from the repository secrets (ADR-0021)
- Ordered roles: organization admin > librarian > member, band leader > set planner > member; organization admins may do everything (ADR-0023)
- Band arrangements per band and song (key, sequence, tempo) between song and set item; set item transposition is relative to the band's key (ADR-0025)
- Registration set by the server operator in `pocketbase.env`: `invite_only` (default, sign-up only with an invitation, new organizations only via operator founder invitations) or `open`; optional email verification (ADR-0024)
- Semantic Versioning: major = old clients no longer work with the server or data, minor = tolerated features, patch = fixes (ADR-0028)
- Minimum client version: apps send `X-Setding-Version`, the server answers outdated ones with HTTP 426, the app asks for an update; release before deploying the server (ADR-0029)
