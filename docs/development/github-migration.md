# Moving the repository from Forgejo to GitHub

> Runbook for the one-time move of the repository from the self-hosted Forgejo to
> **GitHub, `github.com/tafli/RealChord`** (issue #116, ADR-0010). Prepared, **not
> executed yet**: it runs once #27 is done and every Forgejo issue is closed.

## Goals and rules

- **Everything moves:** the git history (`main`, tags), labels, milestones, every
  issue and pull request with its comments, the CI workflow and the CI image.
- **Numbers stay the same.** Commits say `(#115)`, texts say `#27`. On GitHub
  issues and PRs share one number range, as on Forgejo, so the import creates one
  GitHub issue per Forgejo number, in order, into the **empty** repository. Pull
  requests cannot be imported as PRs (their branches are gone); they become
  closed issues with the label `imported:pull-request`, a header naming branch,
  author, dates and the merge commit.
- **No reference to the Forgejo instance on GitHub** (owner rule): not in issue
  texts, not in file contents, not in commit messages, not in the scripts. Hence
  the history is rewritten before the push (see below), the scripts read the
  Forgejo host from the `origin` remote instead of naming it, and every step
  verifies that the host name no longer occurs.
- **Commit identity:** after the move, commits are made with the owner's global
  git identity and are **GPG-signed** (commits and tags). The repository-local
  `factoryd` identity of the Forgejo checkout is not carried over. Agent work stays
  recognisable by the `Co-Authored-By` trailer (git workflow, section 4).

## Consequences of the history rewrite

`git filter-repo` replaces the Forgejo host in all file versions and commit
messages (rules: `tool/github-migration/migrate.py rules`; e.g. the
`Reviewed-on:` lines of the squash commits then point to the GitHub issue with the
same number, the CI image to `ghcr.io/tafli/realchord-ci`). Therefore:

- **All commit ids change.** The import translates commit ids in issue texts with
  the commit map of the rewrite. Existing checkouts cannot be rebased onto GitHub;
  they are replaced by a fresh clone (`local-cutover.sh`).
- **Old signatures are dropped** (they would no longer match the rewritten
  commits). Only commits made after the move are signed.
- Only `main` and the tags move; no other branch (there must be no open work).
- Authors stay as they are (`factoryd` commits keep their author). To rewrite them
  too, pass a mailmap file: `MAILMAP=path/to/mailmap history.sh prepare`.
  Alternatively add the `factoryd` e-mail address to the GitHub account so these
  commits are linked to it.

## Tools

| Script | Purpose |
|---|---|
| [`tool/github-migration/migrate.py`](../../tool/github-migration/migrate.py) | `export` (Forgejo, read-only) → `plan` (dry run) → `import` → `settings` → `verify` |
| [`tool/github-migration/history.sh`](../../tool/github-migration/history.sh) | `prepare` (bare clone + rewrite + check, local only) → `verify` → `push` |
| [`tool/github-migration/local-cutover.sh`](../../tool/github-migration/local-cutover.sh) | Fresh clone from GitHub, copy local untracked data, check identity and signing (dry run without `--apply`) |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | GitHub Actions equivalent of `.forgejo/workflows/ci.yml` (manual only); ignored by Forgejo as long as `.forgejo/workflows` exists |

Work data (export, rewritten clone, import progress) lives in `.github-migration/`
(git-ignored). `migrate.py import` is **resumable**: it keeps its progress in
`.github-migration/import-state.json` and checks before every issue that GitHub
assigns exactly the expected number; if not, it stops. It waits 1.2 s between
write requests and backs off on rate limits (~260 requests, about 6 minutes).

Tokens: Forgejo from the `fj` login (or `FORGEJO_TOKEN`), GitHub from `gh auth token`
(or `GITHUB_TOKEN`).

## 0. Prerequisites (owner, once)

1. GitHub CLI logged in as `tafli` with the scopes for the steps below:
   `gh auth login -s repo,workflow,write:packages,read:packages`
2. SSH key of the development machine on the GitHub account (`ssh -T git@github.com`).
3. GPG key for signed commits on the GitHub account, and the commit e-mail
   verified there (otherwise commits show as "Unverified"):
   `gpg --armor --export "$(git config --global user.signingkey)" | gh gpg-key add -`
4. The GitHub repository `tafli/RealChord` stays **empty**: no README, no issue,
   no PR, no Dependabot or other app that could open issues/PRs before the import
   (that would shift the numbers).
5. `git-filter-repo` installed (`pacman -S git-filter-repo`).

## 1. Preconditions

- #27 is merged, **every Forgejo issue is closed** and no PR is open
  (`migrate.py export` warns about open items).
- No unpushed or uncommitted work in any checkout or worktree.

## 2. Cutover PR (on Forgejo, the last one there)

Issue "chore: move the repository to GitHub", branch, PR as usual. It turns the
tree into its GitHub state, so the rewritten `main` is correct without further
edits. Afterwards `git grep -i <forgejo host>` must be empty and
`git grep -n -i "forgejo\|fj "` may only find history (decision logs) and this
runbook. Changes:

- [ ] Delete `.forgejo/` (the GitHub workflow is already in `.github/workflows/`).
- [ ] `Makefile`: `CI_IMAGE ?= ghcr.io/tafli/realchord-ci:$(FLUTTER_VERSION)`,
      comments ("GitHub container registry", "keep in sync with
      .github/workflows/ci.yml"), `ci-image-push` help: `docker login ghcr.io`.
- [ ] `tool/ci/Dockerfile`: header comment points to `.github/workflows/ci.yml`.
- [ ] `docs/development/releases.md`: image `ghcr.io/tafli/realchord-ci`, `docker login ghcr.io`.
- [ ] `docs/development/git-workflow.md`: section 2 (backlog as GitHub issues),
      6 (`gh pr merge --squash --delete-branch`; PR template from `.github/`),
      7 (GitHub Actions, `ubuntu-latest`, image on ghcr.io pulled with
      `GITHUB_TOKEN`; no `CI_REGISTRY_TOKEN`, no `TEST_CONCURRENCY`; `gh pr checks`,
      `gh run list`), 11 (`gh auth status`), 12 renamed "GitHub" (host, remote
      `git@github.com:tafli/RealChord.git`, identity: owner's global identity,
      signed commits and tags, agents marked by `Co-Authored-By`; `gh` login;
      labels; merge settings; branch protection), quick reference with `gh`
      (`gh pr create --draft`, `gh pr ready`, `gh pr merge --squash --delete-branch`).
- [ ] `AGENTS.md`: the "Remote" bullet (GitHub, `gh`), identity rule.
- [ ] `docs/architecture/adr/0010-git-workflow.md`: decision log entry (move to
      GitHub, identity, CI), consequences (GitHub Actions, `gh`), and remove the
      Forgejo host name from the earlier log entries ("the self-hosted Forgejo
      instance").
- [ ] `docs/architecture/adr/0019-linux-release-builds.md`: "Windows runner" without Forgejo.
- [ ] `docs/architecture/README.md`: open question 13, "Tracked as Forgejo
      issues" in the roadmap, ADR index if a title changes.
- [ ] Remove the Forgejo host from `tool/github-migration` comments if any were
      added; the scripts keep working with `FORGEJO_URL`/`FORGEJO_HOST`/`FORGEJO_REPO`
      set explicitly once `origin` is GitHub.

Merge it with the test gate as usual. From now on **nothing is pushed to Forgejo**.

## 3. Export and rehearse (changes nothing on GitHub)

Run from an up-to-date checkout of `main` whose `origin` is still Forgejo:

```bash
rm -rf .github-migration
tool/github-migration/migrate.py export
```

```bash
tool/github-migration/history.sh prepare
```

```bash
tool/github-migration/migrate.py plan
```

Check the plan: number of items, no open items, "commit map with N entries",
"OK: no text references …". Optionally inspect the rewritten history:
`git -C .github-migration/repo.git log --stat main`.

## 4. Migrate

```bash
tool/github-migration/history.sh push
```

```bash
tool/github-migration/migrate.py settings
```

```bash
tool/github-migration/migrate.py import
```

```bash
tool/github-migration/migrate.py verify
```

`push` refuses a non-empty GitHub repository. `import` can be re-run after an
interruption. `verify` compares numbers, titles, states and comment counts and
scans all GitHub issue texts, comments and labels for the Forgejo host.

## 5. CI image and CI

```bash
docker login ghcr.io -u tafli
```

```bash
make ci-image ci-image-push
```

The image label links the package to the repository, so `GITHUB_TOKEN` may pull
it (package settings → "Manage Actions access" if not). Then run the workflow
once by hand: `gh workflow run CI` and `gh run watch`.

## 6. Switch the development machine

```bash
tool/github-migration/local-cutover.sh ~/Projects/RealChord ~/Projects/RealChord-github
```

```bash
tool/github-migration/local-cutover.sh ~/Projects/RealChord ~/Projects/RealChord-github --apply
```

Then `make setup` and `make check` in the new checkout, move it to the old path
once satisfied. The new clone has no repository-local identity; commits use the
global, signed identity (the script checks that signing works; if gpg asks for
the passphrase, unlock the agent first: `echo test | gpg --sign >/dev/null`).

## 7. Afterwards

- Forgejo: archive the repository (read-only), keep or delete it later (owner);
  remove the `fj` login for the instance if no longer needed (`fj auth logout`).
- The CI image on Forgejo's registry and the `CI_REGISTRY_TOKEN` secret are no
  longer used.
- Branch protection on `main` (PR required, later the `test` check) in the
  GitHub settings, as planned towards version 1 (ADR-0010).
- First PR on GitHub: remove `tool/github-migration/` and the "Prepared for the
  move" note in `.github/workflows/ci.yml`; keep this runbook as a record.
