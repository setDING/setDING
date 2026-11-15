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

- Backlog as issues in the self-hosted Forgejo repository, with labels for agents (`agent:ready`, `agent:in-progress`, `needs-human`).
- One issue = one branch (`<type>/<issue>-<slug>`) = one PR; no direct commits to `main`.
- Conventional Commits, English, `Co-Authored-By` trailer for agents.
- Local checks + self-review before a PR is marked ready; required CI checks.
- **Squash merge** only; branch deleted after merge.
- **Test gate:** all tests must pass on the final, rebased state of the branch before
  every merge – no exceptions, no weakening of tests to get green.
- Agents **may merge their own PRs** from the start, when the test gate is satisfied,
  CI is green (once it exists) and no human-decision rule applies.
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

- CI and branch protection are essential and are set up together with the Flutter project (`tool/check.sh`, Forgejo Actions with a Forgejo runner).
- Quality depends on automated tests and the self-review, so test coverage of the core packages (`chordpro`, `sync`) must be high.
- The issue tracker becomes the agents' work queue; issues must have clear acceptance criteria.
- The full workflow needs the Forgejo remote plus an access token for agents (`fj` CLI); without a login, agents fall back to pushing branches and squash-merging locally after the test gate (workflow section 11).

## Decision log

- 2026-11-14: Workflow accepted. Agents may merge their own PRs from the start, under the condition that all tests always pass before a merge (test gate).
- 2026-11-15: Repository host decided: self-hosted **Forgejo** at `github.com`, repository `andi/RealChord` (instead of the assumed GitHub). Issues, PRs and labels live there; agents use the forgejo-cli (`fj`); CI becomes Forgejo Actions. Until agents have an access token, they push their branches and squash-merge locally after the test gate.
- 2026-11-15: CLI is forgejo-cli (`fj`) instead of `tea`: built for Forgejo, supports squash merge, drafts ("WIP: ") and AGit PRs.
- 2026-11-15: CI active: Forgejo Actions workflow `.forgejo/workflows/ci.yml` runs `tool/check.sh` (job `test`) on a global `linux-amd64` runner, installing the pinned Flutter version in a Debian container for every PR and push to `main`. Build jobs and commit-lint follow later.
- 2026-11-15: Agents have API access: an access token (scopes repository and issue, under the owner's account) is stored by `fj` on the development machine. The normal flow with issues and PRs applies; local squash merges remain only as a fallback without a login (workflow section 11).

## Open points

- Build jobs: Android (SDK in the container or a separate image), iOS (needs a macOS runner), Windows (needs a Windows runner).
- Branch protection on `main` (PR required, required check `test`) is to be enabled by the owner in the repository settings.
