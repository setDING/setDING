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

The backlog is kept as issues in the project's **Forgejo** repository
(`github.com/tafli/RealChord`, see section 12). An agent always works on an issue;
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
- When several agents work in parallel, each uses its own **git worktree** (one per branch).

## 4. Commits

Format: **[Conventional Commits](https://www.conventionalcommits.org/)**.

```
<type>(<optional scope>): <summary in imperative, lower case, no period>

<body: what and why, wrapped at 72 characters>

Refs #<issue>
Co-Authored-By: <agent name> <noreply@…>
```

- Types as for branches; breaking changes use `!` (`feat(sync)!: …`) and a `BREAKING CHANGE:` footer.
- Scopes follow the client modules: `chordpro`, `render`, `data`, `sync`, `live`, `manage`, `band`, `l10n`, `pdf`, plus `backend`, `ci`, `docs`, `adr`.
- **Each commit builds and passes the tests.** No "WIP" or "fix typo" commits on `main` (they disappear with the squash merge, see section 6).
- Commits made by an agent carry a `Co-Authored-By` trailer naming the agent.
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

- Opened as soon as the branch is pushed. As a **draft** while work is in progress, marked **ready** when section 5 is complete.
- Title = the future squash commit message (Conventional Commit format).
- Body follows [`.github/pull_request_template.md`](../../.github/pull_request_template.md) (Forgejo reads PR templates from `.github/` as well as `.forgejo/`): summary, linked issue (`Closes #n`), affected ADRs, how it was tested, open points.
- Size: aim for **under ~400 changed lines** (generated files excluded). Larger work is split into several PRs, each leaving `main` working.
- **Merge method: squash merge** only. The branch is deleted after the merge.
- **CI must be green** before merging (see section 7).

### Test gate

**All tests must pass before every merge.** This is the hard precondition for any
merge, by agents and humans alike:

- The full test suite runs on the **final state of the branch, rebased on the latest
  `main`** – not on an earlier state. If `main` moves on before the merge, rebase and
  run the tests again.
- With CI: the required `test` check (and all other required checks) is green.
  Without CI (no Forgejo Actions runner yet, section 12): the agent runs the full
  suite locally immediately before the merge and reports the result in the PR and the
  merge commit body.
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
- CI is green (once it exists) and the branch is up to date with `main`
- the self-review is done and its findings are fixed
- no rule from section 9 applies

Otherwise the PR gets `needs-human`, and the agent explains in a comment what needs
to be decided.

## 7. Continuous integration

CI runs as **Forgejo Actions** (workflows in `.forgejo/workflows/`, executed by a
Forgejo runner) on every PR and on every push to `main`. Required checks:

| Check | Content |
|---|---|
| `format` | `dart format --set-exit-if-changed` |
| `analyze` | `flutter analyze` without warnings |
| `test` | unit, widget and golden tests |
| `l10n` | all ARB keys present in German and English |
| `build` | Android build (APK); iOS and Windows builds at least on `main` |
| `commit-lint` | PR title follows Conventional Commits |

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
issue and continues on the same branch.

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
- The tag triggers the CI release build (artifacts for Android, iOS, Windows). **Publishing to the stores requires human approval** (protected CI environment).
- Hotfixes follow the normal flow (`fix/…` branch, `priority:high`), then a patch release.

## 11. Without API access (fallback)

Agents create issues and PRs and merge with `fj` (section 12). Only if `fj auth list`
shows no login for `github.com` on the machine (e.g. a new machine where the
human has not added the token yet):

- Work on a branch named as in section 3, commit as in section 4, and **push the
  branch** (`git push -u origin <branch>`).
- Run the checks from section 5.
- Rebase on `origin/main` and run the **full test suite** right before merging (test
  gate, section 6). Only merge if it passes.
- Merge with `git merge --squash <branch>` and a Conventional Commit message that
  reports the test result, push `main`, then delete the branch locally and on the
  remote (`git push origin --delete <branch>`).
- Issues that would be created are listed in the handover instead; the human creates
  them or sets up the token.

## 12. Forgejo

- **Host:** self-hosted Forgejo, repository `github.com/tafli/RealChord`, remote
  `origin` over SSH (`git@github.com:tafli/RealChord.git`).
- **CLI:** [forgejo-cli](https://codeberg.org/Cyborus/forgejo-cli) (`fj`, v0.7 or
  later) for issues, PRs and merges; it finds the repository from the `origin` remote.
  Login once per machine, done by the human: `fj -H github.com auth login`
  (browser) or `fj -H github.com auth add-token` (token from stdin). The token is a
  personal access token with read/write scope for *repository* and *issue*; it is
  stored by `fj`, never in the repository (section 4). `fj auth list` shows whether a
  login exists.
- **AGit:** `fj pr create --agit` (or `git push origin HEAD:refs/for/main -o topic=…`)
  creates a PR without pushing a branch, if AGit is enabled on the instance.
- **Closing keywords:** `Closes #n` in the PR body closes the issue on merge, as on
  GitHub.
- **Labels:** the labels of section 2 are created once in the repository settings
  (`fj` 0.7 cannot create labels).
- **Merge settings:** in the repository settings only *squash* is enabled, and
  "delete branch after merge" is the default.
- **Branch protection on `main`** (repository settings → Branches): no direct push,
  PR required, required status checks from section 7 once a runner exists.

## Quick reference

```bash
git fetch origin
git switch -c feat/12-chordpro-parser origin/main
# … work, commit in Conventional Commit format …
git fetch origin && git rebase origin/main
tool/check.sh
git push -u origin feat/12-chordpro-parser
fj pr create --base main --head feat/12-chordpro-parser \
  --body-file pr.md "WIP: feat(chordpro): …"   # "WIP: " title prefix = draft
# … checks pass, self-review done, "WIP: " prefix removed (fj pr edit) …
fj pr status <index>
fj pr merge -M squash -d <index>   # only if section 6 "Who merges" allows it
```
