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
(`github.com/tafli/setDING`, see section 12). An agent always works on an issue;
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

- **Location:** a sibling folder of the main checkout,
  `../setDING-worktrees/<branch with "/" replaced by "-">`, e.g.
  `../setDING-worktrees/feat-12-chordpro-parser`. Outside the repository on
  purpose: tools that scan the tree (`dart format .`, the analyzer, IDE indexing)
  never see a second copy of the code.
- **Create** the branch and its worktree in one step from the latest `origin/main`:
  `git fetch origin && git worktree add -b <branch> ../setDING-worktrees/<dir> origin/main`.
  All further commands (`make check`, commits, `git push`) run inside the worktree.
  Local data is per worktree (`.dev-data/`, `.dart_tool/`), so the first
  `make check` in a new worktree fetches the packages again.
- **Tools that offer their own worktrees** (e.g. Claude Code worktree sessions) may
  use their own location, as long as the main checkout stays on `main`.
- **Remove** the worktree after the merge (section 6):
  `git worktree remove ../setDING-worktrees/<dir>`, then delete the branch.
  `git worktree list` shows the open worktrees; `git worktree prune` cleans up
  entries of folders deleted by hand.
- **Taking over** a branch of another agent (section 8): fetch it and add a worktree
  for it (`git worktree add ../setDING-worktrees/<dir> <branch>`).

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
  (`gh pr merge --squash --delete-branch --author-email andi@theboss.ch --body-file merge.md`).
  The squash commit is created by GitHub; `--author-email` gives it the owner's
  e-mail instead of the account's noreply address.
- **Never commit secrets** (keys, tokens, signing files, `.env`). Use `.env.example` with placeholders. If a secret was committed: stop, set `needs-human`, do not try to rewrite published history yourself.

## 5. Before opening a PR (local checks)

An agent runs all of the following and only continues when everything passes:

1. Rebase on the latest main: `git fetch origin && git rebase origin/main`
2. Format, static analysis, tests – via the project check script (`tool/check.sh`,
   created with the Flutter project setup). Until then: the checks available for the
   changed files.
3. **Docs up to date:** ADRs and the architecture README updated in the same branch if
   the change touches an architectural decision ([AGENTS.md](../../AGENTS.md)).
4. **Localization complete:** every new UI text exists in `app_de.arb` and `app_en.arb`.
5. **Self-review** of the full diff (e.g. a code-review tool), and fix the findings.

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
  `main`** – not on an earlier state. If `main` moves on before the merge, rebase and
  run the tests again.
- **Currently (early development): local test gate.** The agent runs the full suite
  locally (`make check`) immediately before the merge and reports the result in the
  PR and the merge commit body. Agents do not wait for CI (section 7).
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
runs one test process per core unless `TEST_CONCURRENCY` is set. The first step
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

- **Semantic versioning**: `MAJOR.MINOR.PATCH`; before the first store release `0.x.y`.
- A release is a tag `vX.Y.Z` on `main`, created by an agent through a `chore(release): vX.Y.Z` PR that updates the version in `pubspec.yaml` and `CHANGELOG.md` (generated from the Conventional Commits).
- The build number is the CI run number.
- Pushing the tag (`git tag -s vX.Y.Z && git push origin vX.Y.Z`, after the release PR is merged) triggers the release build (`.github/workflows/release.yml`, ADR-0021): Linux, Android and Windows, published as a GitHub Release, from which Obtainium updates the Android app ([releases.md](releases.md)). The tag must match the version in `pubspec.yaml`. iOS is not built yet. **Publishing to the stores requires human approval** (protected CI environment).
- `make release` still builds the Linux package locally (in a container; ADR-0019).
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

- **Host:** GitHub, repository `github.com/tafli/setDING`, remote `origin` over
  SSH (`git@github.com:tafli/setDING.git`). Moved from a self-hosted Forgejo in
  November 2026 with the same issue and PR numbers; former pull requests are closed
  issues labelled `imported:pull-request` ([migration runbook](github-migration.md)).
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
  branches are deleted after the merge. Merges use `--author-email andi@theboss.ch`
  (section 4), so the squash commit carries the owner's e-mail; GitHub signs it.
- **Branch protection on `main`** (repository settings → Branches): no direct push,
  PR required, required status checks from section 7 once CI is required again.

## Quick reference

```bash
# in the main checkout (always on main)
git fetch origin
git worktree add -b feat/12-chordpro-parser ../setDING-worktrees/feat-12-chordpro-parser origin/main
cd ../setDING-worktrees/feat-12-chordpro-parser
# … work, commit in Conventional Commit format …
git fetch origin && git rebase origin/main
make check
git push -u origin feat/12-chordpro-parser
gh pr create --draft --base main --body-file pr.md --title "feat(chordpro): …"
# … checks pass, self-review done …
gh pr ready <number>
gh pr checks <number>
gh pr merge --squash --delete-branch --author-email andi@theboss.ch --body-file merge.md <number>   # only if section 6 "Who merges" allows it; merge.md ends with the Co-Authored-By trailer
cd ../../setDING   # back to the main checkout
git worktree remove ../setDING-worktrees/feat-12-chordpro-parser
git pull --ff-only
git branch -D feat/12-chordpro-parser   # delete the merged branch locally too
```
