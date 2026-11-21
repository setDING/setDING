# AGENTS.md

Guidance for AI coding agents (and humans) working on this repository. This file
holds only the rules that always apply; the details live in the linked documents.
Read the linked document before working in its area.

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

The architecture is documented in [`docs/architecture/README.md`](docs/architecture/README.md)
(overview, domain model, roadmap, open questions, **ADR index**) and the Architecture
Decision Records in [`docs/architecture/adr/`](docs/architecture/adr/).

**Before you start a task**, read the README and the ADRs relevant to it.
Accepted ADRs are binding. Do not silently deviate from them. The decisions that
shape almost every change:

- Offline-first, local SQLite on every device (ADR-0001); Flutter client (ADR-0002).
- ChordPro text is the single source of truth, parsed in the client (ADR-0003).
- PocketBase, self-hosted, revision-based sync (ADR-0004); server data model in `server/` (ADR-0015).
- Personal adjustments are overlays and never modify the shared song (ADR-0006).
- Organizations above bands; songs belong to the organization (ADR-0017).
- Ordered roles and the permission matrix (ADR-0023).

### Keeping the ADRs up to date (mandatory)

The documentation must always reflect the current state of the project:

- **New architectural decision** (technology, library, data model, sync, security, platform, UX principle with structural impact): create a new ADR from [`adr/template.md`](docs/architecture/adr/template.md), using the next free number (`NNNN-short-title.md`).
- **Change to an existing decision**: update the ADR and add a dated entry to its *Decision log*. If a decision is replaced, set the old ADR to `Superseded by ADR-XXXX` instead of deleting it.
- **Implementation deviates from an ADR**: stop and clarify with the user first; then either adapt the code or update the ADR. Never leave the two out of sync.
- **Open points**: when an open point in an ADR is resolved, move it to the *Decision log*.
- **Always update the README** together with the ADR: the solution strategy table, the domain model, the roadmap, the open questions and the ADR index (number, title, status).
- Status values: `Proposed`, `Accepted`, `Rejected`, `Superseded by ADR-XXXX`. Only the user can accept or reject an ADR; agents create ADRs as `Proposed`.

## Git workflow (mandatory)

Every change follows [`docs/development/git-workflow.md`](docs/development/git-workflow.md) (ADR-0010). The rules that are never skipped:

- One issue = one branch (`<type>/<issue>-<slug>`) = one PR. **Never commit directly to `main`.**
- **Every change happens in its own git worktree** (`git worktree add -b <branch> .worktrees/<branch-with-dashes> origin/main`, inside the project folder and git-ignored); the project folder always stays on `main` and is only fast-forwarded (`git pull --ff-only`).
- **Test gate: `make check` passes on the final branch state rebased on `main` before every merge.** It runs the jobs of the areas the branch changes; run `make check-full` for larger changes, and `make release-gate` (every check plus web and Android integration tests) before a release. While working, run only the affected tests directly. Never skip, delete or weaken tests to get green. New or changed behaviour comes with tests. CI is manual-only for now; do not wait for it.
- Conventional Commits in English, **GPG-signed** with the owner's global git identity (never a repository-local identity), and **every commit** (including squash merges) carries the `Co-Authored-By: Claude …` trailer.
- Squash merge only, through `gh` with `--author-email andi@theboss.ch`; an agent may merge its own PR on a green local `make check` unless a "human must decide" rule applies (then label `needs-human`).
- Never end a session with unpushed work: commit, push, and leave a handover comment on the PR.

## Permissions on the server (mandatory)

The server is the only place where permissions are enforced (owner rule, issue #632):
anyone can call the PocketBase API directly. **Deny by default**, every permission
is enforced and tested through the API in `server/`, and a change to a client
permission check (`app/lib/data/band_view.dart`) changes the server rules, their
tests and ADR-0023's matrix in the same PR. The full rules are in
[`server/AGENTS.md`](server/AGENTS.md).

## External libraries (mandatory)

External libraries are always used in their **newest version**
([`docs/development/dependencies.md`](docs/development/dependencies.md)); `make check-full`
fails on outdated ones (`make check` only when a pubspec changes, otherwise it warns), `make upgrade` upgrades them. Only deliberate pins marked
`# Pinned …` in `pubspec.yaml` are exempt.

## User documentation and screenshots (mandatory)

A new or visibly changed feature updates its website page in both languages
(`website/src/content/docs/`, ADR-0030) **and shows the feature in a screenshot**
there, so users see what to look for: a screenshot test in
`app/test_screenshots/` (de and en), a line in `tool/copy-screenshots.sh`, the
rendered images in `docs/screenshots/` and the image on the page. This includes
hints, dialogs and import reports, not only whole screens. A PR renders **only its
own screenshots** (`make screenshots ONLY="<test name>"`); the release PR renders
all of them (`make screenshots`) and commits the ones that changed since. Details:
[`website.md`](docs/development/website.md),
[`docs/screenshots/README.md`](docs/screenshots/README.md).

## ChordPro features

`docs/examples/feature-showcase.cho` uses every supported ChordPro feature and is a
regression test (package and app). When adding or changing a ChordPro feature, extend
the showcase and its tests, and run `make examples` to rebuild the ZIP.

setDING-specific directives are custom directives in the sense of the ChordPro
specification and **must start with `x_`** (e.g. `{x_sequence}`); never add directives
without this prefix that the specification does not define.

## Language

- **Project language is English**: code, identifiers, comments, documentation, ADRs, commit messages, pull requests, issues and file names.
- **Exception: user-facing UI texts**, in **Swiss Standard German (`de-CH`, no "ß")** and **English** (ADR-0008). UI texts are never hard-coded; every new text goes into both ARB files (`app_de.arb`, `app_en.arb`).
- Conversation with the user may be in German; this does not change the project language.

## Local commands

`make help` lists all targets. `make check` is the test gate; `make dev` / `make start`
run an isolated local instance on Linux, `make reset` deletes its data. Read the
document before using a target of its area:

- [`releases.md`](docs/development/releases.md): `make release`, `make sbom` (ADR-0019, ADR-0021, ADR-0037), `make changelog` (its `CHANGELOG.md` section is the GitHub Release text), `make android-install` (beta build next to a release)
- [`server.md`](docs/operations/server.md): `make server-*` (ADR-0014); after a release, `make server-release` deploys from the tag once the release build passed (ADR-0029)
- [`operations-tests.md`](docs/development/operations-tests.md): shell, Caddyfile, systemd and backup restore checks in `make check`
- [`web.md`](docs/development/web.md) `make web` (ADR-0018) · [`website.md`](docs/development/website.md) `make site` (ADR-0030) · [`branding.md`](docs/development/branding.md) `make branding`
- [`coverage.md`](docs/development/coverage.md) `make coverage` · [`performance.md`](docs/development/performance.md) `make perf`
- [`e2e-tests.md`](docs/development/e2e-tests.md): `make e2e` (the Linux desktop app and the web client at the same time against one local PocketBase)
- [`android-tests.md`](docs/development/android-tests.md): `make android-test` (integration tests on an own emulator or `DEVICE=<id>`, as the separate app `app.setding.itest`) · [`web-tests.md`](docs/development/web-tests.md): `make web-test` (web client in headless Chrome or `BROWSER=firefox`, served by a local PocketBase)
