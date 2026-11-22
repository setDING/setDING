# ADR-0010: Git workflow for autonomous agents

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

The project must be built and maintained **fully autonomously by agents**. Several
agents may work in parallel, sessions can end at any time, and there is often no
human reviewing each change. The workflow must therefore keep `main` stable, make
every change traceable and allow any agent to continue another agent's work, while
leaving the few decisions that must stay with a human clearly marked.

## Decision

We use **trunk-based development with short-lived branches and pull requests**, as
described in detail in [`docs/development/git-workflow.md`](../../development/git-workflow.md):

- Backlog as issues in the GitHub repository, with labels for agents (`agent:ready`, `agent:in-progress`, `needs-human`).
- One issue = one branch (`<type>/<issue>-<slug>`) = one PR; no direct commits to `main`.
- Every branch lives in its own git worktree (`.worktrees/<branch>` inside the project folder, git-ignored); the main checkout always stays on `main` and is only fast-forwarded.
- Conventional Commits, English, `Co-Authored-By` trailer naming Claude on every commit.
- Local checks + self-review before a PR is marked ready. During early development the local test gate is binding and CI runs only on manual dispatch; required CI checks return when heading towards version 1.
- **Squash merge** only; branch deleted after merge.
- **Test gate:** all tests of the areas a change affects must pass on the final,
  rebased state of the branch before every merge – no exceptions, no weakening of
  tests to get green. Every test runs for larger changes (`make check-full`) and
  before every release (`make release-gate`, with the integration tests).
- Agents **may merge their own PRs** from the start, when the test gate is satisfied,
  CI is green (while it is a required check) and no human-decision rule applies.
- Human decision required for: accepting/rejecting ADRs, store releases, secrets and
  access, history rewrites on `main`, changes to the workflow/CI rules, unclear requirements.
- Handover comments on the PR whenever an agent stops mid-task.
- Semantic versioning with tags `vX.Y.Z`; CHANGELOG generated from commits.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Trunk-based, short-lived branches, PRs, squash merge** (chosen) | Simple, linear history, `main` always green, PR as unit for review, handover and CI | Requires good CI, as there is often no human review |
| GitFlow (`develop`, `release/*`, `hotfix/*`) | Clear release phases | Too heavy for a small team of agents, long-lived branches cause merge conflicts |
| Direct commits to `main` | Fastest | No CI gate, no review unit, parallel agents collide |
| Every PR needs human approval | Maximum control | Contradicts the goal of full autonomy, human becomes the bottleneck |

## Consequences

- CI and branch protection are essential and are set up together with the Flutter project (`tool/check.sh`, GitHub Actions).
- Quality depends on automated tests and the self-review, so test coverage of the core packages (`chordpro`, `sync`) must be high.
- The issue tracker becomes the agents' work queue; issues must have clear acceptance criteria.
- The full workflow needs the GitHub remote plus a `gh` login on the development machine; without a login, agents fall back to pushing branches and squash-merging locally after the test gate (workflow section 11).

## Decision log

- 2026-11-14: Workflow accepted. Agents may merge their own PRs from the start, under the condition that all tests always pass before a merge (test gate).
- 2026-11-15: Repository host decided: a self-hosted **Forgejo** instance (instead of the assumed GitHub). Issues, PRs and labels live there; agents use the forgejo-cli (`fj`); CI becomes Forgejo Actions. Until agents have an access token, they push their branches and squash-merge locally after the test gate.
- 2026-11-15: CLI is forgejo-cli (`fj`) instead of `tea`: built for Forgejo, supports squash merge, drafts ("WIP: ") and AGit PRs.
- 2026-11-15: CI active: Forgejo Actions workflow `.forgejo/workflows/ci.yml` runs `tool/check.sh` (job `test`) on a global `linux-amd64` runner, installing the pinned Flutter version in a Debian container for every PR and push to `main`. Build jobs and commit-lint follow later.
- 2026-11-15: CI uses its own image `realchord-ci:<flutter version>` (`tool/ci/Dockerfile`, Forgejo container registry) instead of installing Flutter in every run. It is built and pushed with `make ci-image ci-image-push` by the owner (package write token); the runner pulls it with the repository secret `CI_REGISTRY_TOKEN` (package read), since the instance requires sign-in.
- 2026-11-15: Agents act as the Forgejo user `factoryd` (own commit author, `fj` login, CI registry token) instead of the owner's account, so agent work is distinguishable from the owner's.
- 2026-11-15: Agents have API access: an access token (scopes repository and issue, under the owner's account) is stored by `fj` on the development machine. The normal flow with issues and PRs applies; local squash merges remain only as a fallback without a login (workflow section 11).

- 2026-11-15: CI made manual-only (`workflow_dispatch`) during early development: waiting for the runner slowed development down too much. The test gate is the full local suite (`make check`) on the rebased branch right before the merge; agents do not wait for CI. Decided by the owner.
- 2026-11-16: After a merge the branch is deleted locally as well (`git branch -D`, since squash-merged branches do not count as merged), not only on the remote (owner request).
- 2026-11-16: Move to **GitHub** (`github.com/tafli/RealChord`) decided by the owner, to be carried out once #27 is done and all Forgejo issues are closed ([runbook](../../development/github-migration.md), #116). Issues and pull requests keep their numbers (PRs become closed issues), CI becomes GitHub Actions with the image on `ghcr.io`, commits are made with the owner's signed identity instead of `factoryd` (agents marked by `Co-Authored-By`), and **no reference to the Forgejo instance may exist on GitHub**: the history is rewritten before the push (new commit ids, old signatures dropped, every author and committer rewritten to the owner, #127). The workflow sections for GitHub follow in the cutover PR.
- 2026-11-16: Move to GitHub carried out (#129): issues and PRs imported with their numbers, CI on GitHub Actions with `ghcr.io/tafli/realchord-ci`, agents use `gh`, commits are GPG-signed with the owner's global identity (no repository-local identity), `.forgejo/` removed. The Forgejo repository is archived.
- 2026-11-16: Every commit carries the `Co-Authored-By: Claude …` trailer, not only agent commits, since no commit is made without Claude (owner decision, #131). The history on GitHub was rewritten once more to add it to the 23 commits without it (content unchanged, new commit ids, ids in the imported issues updated).

- 2026-11-16: CI no longer uses its own image: on GitHub-hosted runners everything but Flutter is preinstalled, and `subosito/flutter-action` (version from `FLUTTER_VERSION` in the `Makefile`, cached) sets Flutter up about as fast as pulling the multi-GB image, without building and pushing an image per Flutter version (#135). `tool/ci/Dockerfile` stays as the local base image of the Linux release build (ADR-0019) and is no longer pushed to `ghcr.io`.
- 2026-11-16: The release build of section 10 exists for Linux, Android and Windows (`.github/workflows/release.yml`, ADR-0021, accepted, #137): a `vX.Y.Z` tag that matches `pubspec.yaml` builds all three and publishes a GitHub Release; Android updates come through Obtainium. It runs on tags regardless of the manual-only CI.
- 2026-11-17: Every change is made in its own git worktree, a sibling folder `../RealChord-worktrees/<branch>` outside the repository; the main checkout (project folder) always stays on `main` and is only fast-forwarded. Parallel sessions no longer switch branches under each other's feet. Owner request (#225).
- 2026-11-17: App renamed to **setDING** (#318): repository `github.com/tafli/setDING`, worktrees in `../setDING-worktrees/<branch>`, CI image `ghcr.io/tafli/setding-ci`.
- 2026-11-17: Releases (section 10, #345): the build number is the Release workflow's run number for releases and manual test builds alike and is no longer kept in `pubspec.yaml`; a release is done only after its release build passed and `make server-release` deployed the server from the tag (it refuses otherwise). A failed release build is fixed in a PR and released as the next patch version; pushed tags are never moved. Owner request.
- 2026-11-20: The test gate also tests the operations files (#644): ShellCheck on all shell scripts, `caddy validate`/`fmt` of the Caddyfile, `systemd-analyze verify` of the units, a backup restore against a real PocketBase and the website server with the real Caddyfile ([operations tests](../../development/operations-tests.md)). ShellCheck (GPL-3.0) is allowed as a check tool only: pinned, downloaded into the cache and verified, never copied into the repository or shipped. Owner decision.
- 2026-11-20: Test gate by affected area (#684): `make check` runs only the jobs whose area the branch changes (`tool/check_select.py`; every job for shared files, unknown files and more than 40 changed files), `make check-full` runs all of them and is used for larger changes, `make release-gate` runs every check plus the web and Android integration tests before a release; CI runs every job. The dependency check fails only the full check and changes to pinned libraries, otherwise it warns. Reason: running every job for every change, and every new upstream release failing unrelated PRs, slowed down parallel agent work too much. Owner decision.
- 2026-11-20: `make release-gate` runs the web integration tests in Chrome and in Firefox (#688, owner decision).
- 2026-11-21: Worktrees move into the project folder, `.worktrees/<branch>`, ignored in `.gitignore` (#731). Tools scoped to the project folder (e.g. a Claude Code desktop session: file pane, permissions) reach them too. The formatter and analyzer run inside `app/` and `packages/*` and do not see the folder; an IDE that opens the repository root excludes it. Owner request.
- 2026-11-22: Every bug fix comes with a regression test that reproduces the bug, fails without the fix and passes with it, at the lowest test level that can show it; a PR that cannot add one says why (#861). Owner request.
- 2026-11-22: `main` is checked before the test gate runs, not after: `git fetch origin`, rebase only if `origin/main` moved, then `make check` once on the up-to-date branch. That run is the merge gate unless `main` moves before the merge; the former run before the rebase is dropped, saving one `make check` per PR. Owner request.

## Open points

- Re-enable CI on every PR and push to `main` as a required check (`test`) when heading towards version 1, together with branch protection.

- Build jobs: iOS (needs a macOS runner). Linux, Android and Windows release builds exist (ADR-0021).
- Branch protection on `main` (PR required, required check `test`) is to be enabled by the owner in the repository settings.
