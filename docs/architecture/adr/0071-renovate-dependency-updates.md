# ADR-0071: Renovate for dependency updates

- **Status:** Proposed
- **Date:** 2026-11-28

## Context

The project uses every external library in its newest version
([`dependencies.md`](../../development/dependencies.md)). Today this works by
hand: `tool/check-deps.sh` finds outdated Dart/Flutter and npm packages, the
SBOM's Gradle plugin, the server image's base image and the check tools of
`tool/fetch-tool.sh`; `make upgrade` raises the packages; `make upgrade-guard`
keeps two sessions from raising libraries at the same time (#995). The nightly
full check (#1249, ADR-0010) fails on an outdated library and opens an issue.

Gaps and costs of this:

- Nothing checks the versions of the **GitHub Actions** in
  `.github/workflows/` (`actions/checkout@v7`, `subosito/flutter-action@v2`, …)
  or the pinned commit of `r0adkll/upload-google-play`.
- **Flutter** (`FLUTTER_VERSION`) and **PocketBase** (`PB_VERSION`, ADR-0004) in
  the `Makefile` are raised only when someone thinks of it.
- Every upgrade needs a session to notice it, run `make upgrade`, open the PR
  and run the gate.

The owner asked (2026-11-28) for a bot that opens the upgrade PRs.

Forces:

- **One upgrade at a time.** `upgrade-guard` stops when an open PR changes a
  dependency file; many bot PRs at once would block every agent's
  `make upgrade` and conflict in the lock files.
- **Deliberate pins** are marked with a `# Pinned …` comment in `pubspec.yaml`
  (`jni`, `jni_flutter`, `pocketbase`); a bot does not read comments.
- **Checksums:** `tool/fetch-tool.sh` pins ShellCheck and geckodriver with their
  SHA-256 sums; raising only the version breaks the download check.
- **The local gate is binding** (ADR-0010): CI on PRs is manual, so a bot PR is
  only merged after a green local `make check`.
- The repository is public on GitHub; the licence of new transitive
  dependencies must stay MIT-compatible (AGENTS.md).

## Decision

- **Renovate** (hosted GitHub App by Mend, free for public repositories)
  opens the dependency PRs. The owner installs the app for
  `setDING/setDING` only; the configuration is `renovate.json` in the
  repository root.
- **One grouped PR per week** for everything that is not a major version
  (schedule: Monday early morning, Europe/Zurich), so it is one upgrade PR in
  the sense of `upgrade-guard`. Major versions get their own PR each, because
  they may need code changes.
- **Covered:** `pub` (all four `pubspec.yaml`, with `pubspec.lock`), `npm`
  (`website/`), GitHub Actions (also commit-pinned ones, kept pinned with the
  version as a comment), the server image's `Dockerfile` (digest), Gradle (the
  SBOM's CycloneDX plugin), and through custom regex managers `FLUTTER_VERSION`
  and the Caddy version of `tool/fetch-tool.sh`.
- **Not covered, stay by hand:** the pinned packages (`jni`, `jni_flutter`,
  `pocketbase`; `ignoreDeps` in `renovate.json`), `PB_VERSION` (pinned with the
  `pocketbase` package, ADR-0004), ShellCheck and geckodriver (checksums).
  A test keeps the `ignoreDeps` list equal to the `# Pinned` lines of the
  pubspecs, so a new pin cannot be forgotten in one of the two.
- **Dependency Dashboard** issue on (Renovate's overview of pending and
  ignored updates); no automerge.
- **Merging:** an agent picks up the PR like any other: rebase if needed,
  `make check` (a pubspec change makes the dependency check strict), squash
  merge with the owner's identity and the `Co-Authored-By` trailer in the merge
  commit. A failing PR is fixed on its branch or left with a comment.
- `make upgrade` and the nightly full check stay as the safety net; the
  nightly issue for an outdated library is closed by Renovate's next PR.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep it by hand (`make upgrade` + nightly issue) | No new tool, no third-party app with write access | GitHub Actions and the Makefile versions stay unchecked; every upgrade needs a session to start it |
| Dependabot | Built into GitHub, no app to install; pub, npm, Actions, Docker, Gradle | No custom managers: `FLUTTER_VERSION` and `tool/fetch-tool.sh` stay unchecked; grouping across ecosystems is limited, so several PRs at once trip `upgrade-guard`; no dashboard |
| **Renovate, hosted app** (chosen) | Custom regex managers, one grouped PR across all ecosystems, schedule, dependency dashboard, ignore list | A third-party app with write access to the repository; configuration to keep in sync with the pins |
| Renovate self-hosted in a GitHub Action | No third-party app; could run `postUpgradeTasks` (e.g. update the checksums) | A token with write access as a secret, a workflow to maintain, more setup than the app |

## Consequences

- Upgrades arrive without someone noticing them first; the GitHub Actions and
  Flutter get raised regularly.
- The owner installs and may uninstall the Renovate app (a "human must decide"
  case: store and repository access, git-workflow section 9).
- `renovate.json` and the pins must stay in sync (tested).
- Renovate's PR is authored by its bot; the squash merge still carries the
  owner's identity. Its commits are not GPG-signed by the owner, which the squash
  merge covers.
- `upgrade-guard` treats Renovate's open PR as a running upgrade, so sessions
  wait for it instead of upgrading in parallel.
- `dependencies.md` describes the weekly PR and what stays by hand.

## Decision log

- 2026-11-28: Proposed (#1251) after the owner asked for a bot for version
  upgrades and chose Renovate over Dependabot.

## Open points

- Whether Renovate updates `pubspec.lock` for Flutter packages correctly (it
  needs the Flutter SDK for `flutter pub`); checked in the first PR after the
  app is installed. If not, the grouped PR raises the constraints and an agent
  runs `make upgrade` on the branch.
- Whether to start CI automatically for Renovate's PRs only (a `pull_request`
  trigger limited to the bot), so its PRs come with a result.
