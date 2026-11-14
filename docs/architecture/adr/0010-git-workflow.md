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

- Backlog as GitHub issues with labels for agents (`agent:ready`, `agent:in-progress`, `needs-human`).
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

- CI and branch protection are essential and are set up together with the Flutter project (`tool/check.sh`, GitHub Actions).
- Quality depends on automated tests and the self-review, so test coverage of the core packages (`chordpro`, `sync`) must be high.
- The issue tracker becomes the agents' work queue; issues must have clear acceptance criteria.
- A remote repository (GitHub) is required for the full workflow; until then the local variant applies.

## Decision log

- 2026-11-14: Workflow accepted. Agents may merge their own PRs from the start, under the condition that all tests always pass before a merge (test gate).

## Open points

- Repository host and name (GitHub assumed; name depends on the app name, see `docs/app-name-candidates.md`).
