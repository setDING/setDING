# ADR-0066: GitHub organization setDING

- **Status:** Accepted
- **Date:** 2026-11-27

## Context

The repository lives in the owner's personal account (`github.com/tafli/setDING`).
The project has its own name, its own domain (`setding.app`) and published
releases that other people install and self-host. Tying it to a personal account
makes it hard to give other people access per area, couples the project's address
to one person, and puts the server image under the owner's name
(`ghcr.io/tafli/setding-server`).

The address is used in many places: the app's update check (installed apps ask
`github.com/tafli/setDING/releases`), Obtainium sources, the Windows installer,
the website, the release and SBOM tooling, the server tooling and the
documentation.

The question whether the website (`website/`, ADR-0030) should move to its own
repository came up at the same time.

## Decision

- The repository moves to the GitHub organization **`setDING`**:
  `github.com/setDING/setDING`, by GitHub's repository transfer, so issues, pull
  requests, releases, stars and the Actions history move with it and GitHub
  redirects the old URLs.
- **Every reference** in the code and the documentation uses the new address;
  past `CHANGELOG.md` entries keep the names that were true then.
- **No repository named `tafli/setDING` may ever be created again**: it would
  break the redirect that old links and the update check of installed apps rely
  on.
- The **server image** is published as `ghcr.io/setding/setding-server` from the
  first release after the transfer (the release workflow takes the owner from
  `GITHUB_REPOSITORY_OWNER`); the self-hosting pages tell Docker users to change
  the image name. Images up to 0.22.1 stay at `ghcr.io/tafli/setding-server`.
- **The website stays in this repository.** A feature, its website page and its
  screenshot land in one PR (AGENTS.md, ADR-0030), the website uses the app's logo
  and the screenshots rendered from the app's tests, and the website is deployed
  from the release tag. A split would turn every visible feature into two
  coordinated PRs and need hand-kept version sync, without saving test time
  (`make check` checks the website only when it changes).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Stay in the personal account | Nothing to do | Project bound to one person; no per-team access |
| New repository in the organization, old one archived | Clean start | Issues, PRs, releases and redirects lost; installed apps' update check breaks |
| **Transfer to the organization** | History, numbers and releases kept; GitHub redirects old URLs | Image name changes; the old name must stay free forever |
| Website in its own repository | Website contributors without code access | Feature, page and screenshot no longer atomic; version sync by hand |

## Consequences

- Installed apps keep finding updates through the redirect; the next release
  carries the new URL.
- Obtainium users with the old source keep getting updates through the redirect;
  the install pages show the new source.
- Docker users change the image name once.
- The owner transfers the repository and checks that the Actions secrets of the
  release workflow (Android release key and others) are present afterwards, and
  that the workflow's run number (the build number, ADR-0021) continues instead
  of starting at 1.
- Local clones change their remote (`git remote set-url origin
  git@github.com:setDING/setDING.git`).
- Access per area (e.g. for website contributors) becomes possible through
  organization teams and `CODEOWNERS`; a website split can be decided again if
  the website gets its own contributors or stops following the app's versions.

## Decision log

- 2026-11-27: Proposed (#1127): transfer to the organization `setDING`, server
  image under `ghcr.io/setding`, website stays in this repository.
- 2026-11-27: Accepted by the owner (#1127).
- 2026-11-27: Repository transferred; the organization profile README lives in `setDING/.github` (`profile/README.md`, #1129).

## Open points

- Teams and `CODEOWNERS` in the organization
