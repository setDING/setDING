# Git workflow

> Binding for every agent and human working on this repository.
> Decision record: [ADR-0010](../architecture/adr/0010-git-workflow.md).

The goal is that the project can be built and maintained **fully autonomously by
agents**, while `main` always stays green and every change stays traceable. The rules
below are written so an agent can follow them without asking, and they name the few
cases where a human must decide.

## 1. Principles

1. **`main` is always releasable.** It builds, all checks pass, and the docs match the code.
   **Nothing is merged unless all tests pass** – without exception (see section 6, "Test gate").
2. **No direct commits to `main`.** Every change goes through a branch and a pull request (PR).
3. **One task = one issue = one branch = one PR.** Small, focused, short-lived (ideally merged within a day).
4. **Everything is in the repository or in issues/PRs.** No knowledge lives only in a chat session. An agent that stops mid-task leaves enough behind for another agent to continue.
5. **Project language is English** (commits, branches, PRs, issues), see [AGENTS.md](../../AGENTS.md).

## 2. Work items (issues)

The backlog is kept as issues in the project's **GitHub** repository
(`github.com/setDING/setDING`, see section 12). An agent always works on an issue;
if none exists for the task, it creates one first.

| Label | Meaning |
|---|---|
| `agent:ready` | Clearly described, can be picked up by an agent |
| `agent:in-progress` | An agent is working on it (set together with the assignee) |
| `needs-human` | Blocked on a decision only a human can make (see section 9) |
| `type:feat`, `type:fix`, `type:docs`, `type:refactor`, `type:chore` | Kind of work |
| `priority:high` | Pick before other `agent:ready` issues |

An issue states the goal, the acceptance criteria and the relevant ADRs. If an agent
finds an issue too vague, it adds its questions as a comment, sets `needs-human` and
picks another one.

**Picking an issue:** take the highest-priority `agent:ready` issue that is not
assigned, set `agent:in-progress`, and comment "Started on branch `<branch>`". Never
work on an issue labelled `agent:in-progress` by someone else.

## 3. Branches

- Created from the latest `origin/main`.
- Name: `<type>/<issue>-<short-slug>`, lower case, hyphens, English.
  - Examples: `feat/12-chordpro-parser`, `fix/31-transpose-flat-keys`, `docs/7-git-workflow`
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`
  - Without an issue (only before a remote exists): omit the number, e.g. `docs/git-workflow`.
- A branch belongs to the agent that created it. Others do not push to it unless the
  PR is explicitly handed over (see section 8).
- **Every branch lives in its own git worktree** (see below). The main checkout is
  never switched to a branch.

### Worktrees

The project folder (the main checkout, e.g. `~/Projects/setDING`) **always stays on
`main`**. It is only ever updated with `git pull --ff-only`; nobody edits, commits or
switches branches in it. Every change – by agents and humans, also small docs fixes –
is made in a separate worktree, so parallel sessions never disturb each other and the
main checkout is always a clean, current `main` to start from.

- **Location:** inside the project folder,
  `.worktrees/<branch with "/" replaced by "-">`, e.g.
  `.worktrees/feat-12-chordpro-parser`. The folder is in `.gitignore`, so the main
  checkout stays clean, and tools scoped to the project folder (e.g. a Claude Code
  desktop session) reach the worktrees too. The formatter and analyzer run inside
  `app/` and `packages/*` and never see the second copy; an IDE that opens the
  repository root should mark `.worktrees/` as excluded.
- **Create** the branch and its worktree in one step from the latest `origin/main`:
  `git fetch origin && git worktree add -b <branch> .worktrees/<dir> origin/main`.
  All further commands (`make check`, commits, `git push`) run inside the worktree.
  Local data is per worktree (`.dev-data/`, `.dart_tool/`), so the first
  `make check` in a new worktree fetches the packages again.
- **Tools that offer their own worktrees** (e.g. Claude Code worktree sessions) may
  use their own location, as long as the main checkout stays on `main`.
- **Remove** the worktree after the merge (section 6):
  `git worktree remove .worktrees/<dir>` (from the main checkout), then delete the branch.
  `git worktree list` shows the open worktrees; `git worktree prune` cleans up
  entries of folders deleted by hand.
- **Taking over** a branch of another agent (section 8): fetch it and add a worktree
  for it (`git worktree add .worktrees/<dir> <branch>`).

## 4. Commits

Format: **[Conventional Commits](https://www.conventionalcommits.org/)**.

```
<type>(<optional scope>): <summary in imperative, lower case, no period>

<body: what and why, wrapped at 72 characters>

Refs #<issue>
Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

- Types as for branches; breaking changes use `!` (`feat(sync)!: …`) and a `BREAKING CHANGE:` footer.
- Scopes follow the client modules: `chordpro`, `render`, `data`, `sync`, `live`, `manage`, `band`, `l10n`, `pdf`, plus `backend`, `ci`, `docs`, `adr`.
- **Each commit builds and passes the tests.** No "WIP" or "fix typo" commits on `main` (they disappear with the squash merge, see section 6).
- **Every commit carries a `Co-Authored-By` trailer naming Claude** – no commit of the
  project is made without it. This includes the squash commit of a PR: merge with
  an explicit body that reports the test gate and ends with the trailer
  (`gh pr merge --squash --delete-branch --author-email "$(git config --global user.email)" --body-file merge.md`).
  The squash commit is created by GitHub; `--author-email` gives it the owner's
  e-mail instead of the account's noreply address.
- **Never commit secrets** (keys, tokens, signing files, `.env`). Use `.env.example` with placeholders. If a secret was committed: stop, set `needs-human`, do not try to rewrite published history yourself.

## 5. Before opening a PR (local checks)

An agent runs all of the following and only continues when everything passes:

1. **Bring the branch up to date with `main` first**, then run the gate:
   `git fetch origin` and, if `origin/main` moved past the branch's base
   (`git merge-base --is-ancestor origin/main HEAD` fails), `git rebase origin/main`.
   Only then `make check`, so one run covers the branch as it will be merged;
   a run on a branch that is behind `main` is wasted, since it has to be repeated
   after the rebase.
2. Format, static analysis, tests – via the project check script (`make check`,
   `tool/check.sh`). After the dependency check it runs its independent jobs in
   parallel (Dart packages, server, app analysis, app and screenshot tests, web
   build, website), prints one line per job and the full log of every failed job.
   `CHECK_PARALLEL=0 make check` runs the jobs one after another with their output
   streamed.
   **Only the affected jobs run** (#684): `tool/check_select.py` maps the files the
   branch changes against `origin/main` (committed, uncommitted, untracked) to
   jobs, e.g. `app/lib/` → app analysis, tests and web build, `packages/chordpro/`
   → the package and the app, `server/` → the server and the app tests,
   `website/` and `docs/screenshots/` → the website; documentation alone runs no
   job. Every job runs for files of the check itself (`Makefile`,
   `tool/check.sh`, …), for files no rule knows, and for more than 40 changed
   files. **For larger changes** (several areas, refactorings, library upgrades)
   run `make check-full`, which always runs every job. The dependency check only
   warns unless the change touches a `pubspec`/`package.json` or the run is full.
   While working, run the tests of the area directly (`flutter test
   test/foo_test.dart`, `dart test`) and the gate **once**, at the end, on the
   branch brought up to date in step 1; that run is the test gate of the merge
   (section 6) as long as `main` does not move on in between.
3. **Docs up to date:** ADRs and the architecture README updated in the same branch if
   the change touches an architectural decision ([AGENTS.md](../../AGENTS.md)).
4. **Tests for the change:** new or changed behaviour comes with tests. **A bug fix
   comes with a regression test** that reproduces the bug: write it first, see it
   fail on the unfixed code, then fix the bug and see it pass. Put it at the lowest
   level that can show the bug (package, server, unit or widget test; an
   integration or e2e test only when nothing lower can) and name the issue in the
   test (`// Regression test for #123`). If a test is truly impossible (e.g. a
   platform-only rendering glitch), say why in the PR under "How it was tested".
5. **Localization complete:** every new UI text exists in every ARB file (`app_*.arb`).
6. **Permissions enforced on the server:** every permission the change adds or
   touches is enforced by server rules, hooks or routes and tested with direct API
   calls as the refused roles, including the permission matrix test
   `server/test/permissions_test.dart` ([AGENTS.md](../../AGENTS.md)).
7. **Self-review** of the full diff (e.g. a code-review tool), and fix the findings.

## 6. Pull requests

- Opened as soon as the branch is pushed. As a **draft** while work is in progress (`gh pr create --draft`), marked **ready** when section 5 is complete (`gh pr ready`).
- Title = the future squash commit message (Conventional Commit format).
- Body follows [`.github/pull_request_template.md`](../../.github/pull_request_template.md) : summary, linked issue (`Closes #n`), affected ADRs, how it was tested, open points.
- Size: aim for **under ~400 changed lines** (generated files excluded). Larger work is split into several PRs, each leaving `main` working.
- **Merge method: squash merge** only. The branch is deleted after the merge, on the
  remote (`gh pr merge --squash --delete-branch`) **and locally**: remove the
  worktree (`git worktree remove`, section 3), fast-forward the main checkout
  (`git pull --ff-only`) and delete the local branch with `git branch -D <branch>`. `-D` is needed because Git does not
  recognise a squash-merged branch as merged; check first that the PR is merged.
  Only the agent that owns the branch deletes it (section 3).
- **CI must be green** before merging while CI is a required check (see section 7). During early development CI is manual-only and the local test gate applies.

### Test gate

**All tests must pass before every merge.** This is the hard precondition for any
merge, by agents and humans alike:

- The full test suite runs on the **final state of the branch, rebased on the latest
  `main`** – not on an earlier state. So **check `main` before running the gate**:
  `git fetch origin`, rebase if `origin/main` moved, then `make check` (section 5,
  step 1). Right before the merge, `git fetch origin` once more: if `main` has not
  moved, that run is the gate and is not repeated; if it moved, rebase and run the
  gate again.
- **Currently (early development): local test gate.** The agent runs the test gate
  locally (`make check`, the jobs the branch affects; `make check-full` for larger
  changes, section 5) immediately before the merge and reports the result in the
  PR and the merge commit body. Agents do not wait for CI (section 7).
- **Before a release** `make release-gate` runs every check (dependency check
  fatal), the Linux release build (`make sbom`) and the web (Chrome and Firefox), end-to-end and Android integration
  tests on `main` ([releases.md](releases.md)); the integration tests run per
  change only when it touches platform code or sync ([android-tests.md](android-tests.md),
  [web-tests.md](web-tests.md), [e2e-tests.md](e2e-tests.md)).
- Once CI is a required check again (towards version 1): the required `test` check
  (and all other required checks) is green.
- **New or changed behaviour comes with tests.** A PR that changes code without
  corresponding tests is not ready (pure docs/config changes excepted).
- **Tests are never weakened to get green:** no skipping, deleting, disabling or
  loosening assertions of existing tests, and no lowering of CI requirements, to make
  a merge possible. If a test is genuinely wrong, fixing it is a separate, explained
  change in the PR description; if in doubt, set `needs-human`.
- Flaky tests are not "re-run until green": the flakiness is fixed first, or the PR
  is labelled `needs-human`.

### Who merges

An agent **may merge its own PR** – from the start of the project – when all of the
following hold:

- the test gate above is satisfied
- CI is green (while CI is a required check, section 7) and the branch is up to date with `main`
- the self-review is done and its findings are fixed
- no rule from section 9 applies

Otherwise the PR gets `needs-human`, and the agent explains in a comment what needs
to be decided.

## 7. Continuous integration

> **Early development: CI is manual-only.** Waiting for the runner slowed development
> down too much, so the workflow has only a `workflow_dispatch` trigger and is not a
> required check; the local test gate (section 6) is binding. Run it by hand when
> useful (`gh workflow run CI`, or GitHub → Actions → CI → Run workflow). **When heading towards version 1**,
> re-enable the `pull_request` and `push` triggers in `ci.yml`, make `test` a
> required check again and enable branch protection (ADR-0010, open points).

CI runs as **GitHub Actions** (when enabled, on every PR and on every push to `main`):
[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml), on a GitHub-hosted
`ubuntu-latest` runner without a container: the runner already has git, curl,
python3 and clang, and `subosito/flutter-action` installs Flutter in the version of
`FLUTTER_VERSION` in the `Makefile`, cached between runs. `tool/check.sh`
runs its jobs in parallel (section 5) unless `CHECK_PARALLEL=0` is set, and each
test run uses its runner's default concurrency unless `TEST_CONCURRENCY` is set. The first step
prints the runner's CPUs and memory.

| Check | Content | Status |
|---|---|---|
| `test` | `tool/check.sh`: format (`dart format --set-exit-if-changed`), `analyze` without infos, `l10n` (all ARB keys in German and English, no "ß"), unit and widget tests of `packages/chordpro` and `app` | **Manual only** (required again towards version 1) |
| `build` | Android build (APK); iOS and Windows builds at least on `main` | Planned (needs the Android SDK, a macOS and a Windows runner) |
| `commit-lint` | PR title follows Conventional Commits | Planned |

**Upgrading Flutter:** set `FLUTTER_VERSION` in the `Makefile` in the same PR as the
code changes for the new version; CI and the release build (`make release` builds
its base image for the new version) follow it automatically.

`gh pr checks <number>` shows the checks of a PR; `gh run list` lists the runs.

Branch protection on `main`: PR required, required checks green, squash merge only,
no force push, no deletion.

**Red CI on a PR:** the author agent fixes it. **Red CI on `main`:** highest priority
for any agent – fix forward or revert the causing commit via a new PR
(`revert: …`).

## 8. Interruptions and handover

An agent never ends a session with work only on its local machine:

1. Commit the current state on the branch (it may be incomplete; the PR stays a draft).
2. Push the branch.
3. Write a **handover comment** on the PR: what is done, what is left, known problems, next step.

Another agent may then take over the PR: it comments "Taking over", reassigns the
issue and continues on the same branch in its own worktree (section 3).

## 9. When a human must decide

Agents do **not** do the following on their own; they set `needs-human` and explain:

| Situation | Reason |
|---|---|
| Accepting or rejecting an ADR (agents create ADRs as `Proposed`) | Architecture is decided by the project owner (AGENTS.md) |
| Publishing a release to an app store | Outward-facing, hard to reverse |
| Changing secrets, signing keys, store accounts, server access | Security |
| Force push or history rewrite on `main`, deleting tags or releases | Irreversible |
| Changing this workflow, CI required checks or branch protection | Rules about rules |
| Tests cannot be made to pass, or a test seems wrong and would have to be weakened | The test gate must not be bypassed |
| A requirement is unclear or two ADRs contradict each other | Needs a product decision |

Agents may create **proposals** for all of these (an ADR, a draft PR), just not put them into effect.

## 10. Versions and releases

- **Semantic versioning** (ADR-0028): `MAJOR.MINOR.PATCH`; before 1.0.0 `0.y.z`. What a
  bump means is defined by client/server compatibility ([releases.md](releases.md#version-numbers)).
- **Build number:** the run number of the Release workflow, set by CI for every build,
  releases and manual test builds alike (one counter). It is never set by hand;
  `pubspec.yaml` holds only `X.Y.Z`. Failed or cancelled runs leave gaps, which is fine:
  Android only needs a higher `versionCode`. Local builds (`make apk`, `make release`)
  carry no meaningful build number and are never distributed.
- **Test builds during development:** a manual run of the Release workflow
  (`gh workflow run Release --ref <branch>`) builds Linux, Android and Windows with the
  next build number (`setding-X.Y.Z-buildN-…`) as workflow artifacts, without a release.
- **A release** is done by an agent in these steps, **each only after the previous one
  succeeded**:
  0. **Ask the owner first whether it is a pre-release or a final release**, every
     time the owner asks for a release and before any other step. A pre-release
     (`vX.Y.Z-<pre>`, e.g. `-beta.1`, `-rc.1`) follows
     [releases.md](releases.md#pre-releases) (ADR-0069): no "What's new" entry, test
     server only, nothing uploaded to Google Play. Never decide this yourself from the
     wording of the request, the previous release or the state of `main`.
  1. `chore(release): vX.Y.Z` PR that sets `version: X.Y.Z` in `app/pubspec.yaml` and
     adds the section `## [X.Y.Z] - YYYY-MM-DD` to `CHANGELOG.md` (drafted with
     `make changelog`, rewritten for users; [releases.md](releases.md#changelog)) and
     the version's "What's new" notes in de-CH and en to `app/assets/whats_new.json`
     ([releases.md](releases.md#whats-new-in-the-app), ADR-0041), and the screenshots
     rendered again with `make screenshots` (feature PRs render only their own,
     [docs/screenshots/README.md](../screenshots/README.md)); test gate and squash
     merge as usual. The section becomes the release notes.
  2. Signed tag on the merged `main` and push it:
     `git tag -s vX.Y.Z -m "setDING X.Y.Z" && git push origin vX.Y.Z`.
  3. **The release build must pass:** the tag triggers `.github/workflows/release.yml`
     (ADR-0021), which builds Linux, Android and Windows and publishes the GitHub
     Release only if all three succeed. Watch it (`gh run watch`). If it fails, nothing
     is published: fix the cause in a normal PR and release the **next patch version**;
     a pushed tag is never moved or reused.
  4. **Update the server:** `make server-release` waits for the tag's build, refuses
     unless it passed and the GitHub Release exists, then installs the server bundle
     published with it on production (`SERVER_PROD`, ADR-0063) and checks the version
     (`/api/setding/config` → `serverVersion`). A pre-release goes to the test server
     only ([releases.md](releases.md#pre-releases), ADR-0069).
  5. **Update the website:** `make server-site VERSION=X.Y.Z` builds the website from
     the tag and deploys it to its own server (ADR-0063 §8). Only after this step is
     the release done.
  6. Report the release (version, build number, server version) on the release PR.
- The production server only runs released versions. `make server-install` deploys the
  working tree, stamped `X.Y.Z-dev+<commit>`, to the test server (`setding.dev`); on
  production only with `TARGET=prod FORCE=1` in an emergency.
- iOS is not built yet. **Publishing to the stores requires human approval** (protected
  CI environment). `make release` still builds the Linux package locally (in a
  container; ADR-0019).
- Hotfixes follow the normal flow (`fix/…` branch, `priority:high`), then a patch release.

## 11. Without API access (fallback)

Agents create issues and PRs and merge with `gh` (section 12). Only if `gh auth status`
shows no login for `github.com` on the machine (e.g. a new machine where the human
has not logged in yet):

- Work on a branch named as in section 3, commit as in section 4, and **push the
  branch** (`git push -u origin <branch>`).
- Run the checks from section 5.
- Rebase on `origin/main` and run the **full test suite** right before merging (test
  gate, section 6). Only merge if it passes.
- Merge in the main checkout (on `main`) with `git merge --squash <branch>` and a Conventional Commit message that
  reports the test result, push `main`, then delete the branch locally and on the
  remote (`git push origin --delete <branch>`).
- Issues that would be created are listed in the handover instead; the human creates
  them or sets up the token.

## 12. GitHub

- **Host:** GitHub, repository `github.com/setDING/setDING`, remote `origin` over
  SSH (`git@github.com:setDING/setDING.git`). Moved from a self-hosted Forgejo in
  November 2026 with the same issue and PR numbers; former pull requests are closed
  issues labelled `imported:pull-request` ([migration runbook](github-migration.md)).
- **Organization:** the repository belongs to the GitHub organization `setDING`
  (ADR-0066); until November 2026 it was `tafli/setDING`. GitHub redirects the old
  URLs, so **no repository named `tafli/setDING` may ever be created again**.
- **Commit identity:** commits are made with the owner's global git identity and
  are **GPG-signed** (commits and tags, `commit.gpgsign`/`tag.gpgsign` in the global
  git config); there is no repository-local identity. Every commit carries the
  `Co-Authored-By` trailer (section 4). If signing fails (locked gpg-agent), the
  agent stops and asks the human to unlock it; it never commits unsigned.
- **CLI:** [GitHub CLI](https://cli.github.com/) (`gh`) for issues, PRs, merges and
  CI runs; it finds the repository from the `origin` remote. Login once per machine,
  done by the human: `gh auth login`. The token is stored by `gh`, never in the
  repository (section 4). `gh auth status` shows whether a login exists.
- **Closing keywords:** `Closes #n` in the PR body closes the issue on merge.
- **Labels:** the labels of section 2 exist in the repository (`gh label list`;
  `gh label create` for new ones).
- **Merge settings:** only *squash* is enabled (commit title = PR title), and
  branches are deleted after the merge. Merges use `--author-email "$(git config --global user.email)"`
  (section 4, the owner's global git identity), so the squash commit carries the owner's e-mail; GitHub signs it.
- **Branch protection on `main`** (repository settings → Branches): no direct push,
  PR required, required status checks from section 7 once CI is required again.

## Quick reference

```bash
# in the main checkout (always on main)
git fetch origin
git worktree add -b feat/12-chordpro-parser .worktrees/feat-12-chordpro-parser origin/main
cd .worktrees/feat-12-chordpro-parser
# … work, commit in Conventional Commit format …
git fetch origin
git merge-base --is-ancestor origin/main HEAD || git rebase origin/main   # only if main moved
make check   # once, on the up-to-date branch: also the merge gate
git push -u origin feat/12-chordpro-parser
gh pr create --draft --base main --body-file pr.md --title "feat(chordpro): …"
# … checks pass, self-review done …
gh pr ready <number>
gh pr checks <number>
git fetch origin && git merge-base --is-ancestor origin/main HEAD   # main moved? then rebase, make check again
gh pr merge --squash --delete-branch --author-email "$(git config --global user.email)" --body-file merge.md <number>   # only if section 6 "Who merges" allows it; merge.md ends with the Co-Authored-By trailer
cd ../..   # back to the main checkout
git worktree remove .worktrees/feat-12-chordpro-parser
git pull --ff-only
git branch -D feat/12-chordpro-parser   # delete the merged branch locally too
```
