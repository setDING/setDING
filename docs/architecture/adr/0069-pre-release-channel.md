# ADR-0069: Pre-releases through Obtainium and the staging server

- **Status:** Accepted
- **Date:** 2026-11-27

## Context

Before a version goes to Google Play (ADR-0067) and production, the owner wants
to try it on real devices: installed and updated through Obtainium from the
GitHub Releases (ADR-0021), like a release, but without anyone else getting it.

The release workflow already made tags with a suffix (`v1.3.0-beta.1`) GitHub
pre-releases, which Obtainium skips unless the app is set to include them. But:

- the `play` job uploaded every tag build to the internal track, pre-releases
  included;
- `make server-release` without `VERSION` deployed the newest tag by git's
  version sort, in which `v1.3.0-beta.1` sorts after `v1.3.0`, to production;
- the pre-release apps talked to production (`api.setding.app`), so a new app
  would meet an older server, and test data would land in production.

The staging server `api.setding.dev` (ADR-0014, `make server-install`) is the
place to test a server version before production.

## Decision

A **pre-release** is a tag with a suffix, `vX.Y.Z-<pre>` (e.g. `v1.3.0-beta.1`,
`v1.3.0-rc.1`), with the same version in `app/pubspec.yaml` and its section in
`CHANGELOG.md`. It is built by the same release workflow as a release, with these
differences:

1. **GitHub pre-release.** It is published as a GitHub pre-release with all
   assets. Obtainium offers it only to an installation whose app entry includes
   pre-releases; the final release of the same version updates it later (higher
   build number, ADR-0021).
2. **No Google Play.** The `play` job does not run for pre-releases, so nothing
   reaches any Play track.
3. **Staging server as the default.** The apps of a pre-release are built with
   `--dart-define=SETDING_SERVER_URL=https://api.setding.dev`, so a fresh
   installation talks to the staging server. The default applies only when no
   server is chosen in the settings **and no session is stored**: an
   installation signed in to a server keeps it (`ServerUrlNotifier`), so updating
   to a pre-release (or from it to the release) never signs out silently or mixes
   servers.
4. **Server only on staging.** `make server-release VERSION=1.3.0-beta.1` goes to
   staging by default; production refuses a pre-release
   (`tool/release/release_tag.py`). Without `VERSION`, production gets the newest
   *final* tag and staging the newest tag, pre-releases included, ordered as
   semantic versions (`1.3.0-beta.2 < 1.3.0-beta.10 < 1.3.0`). Deploying stays a
   manual step from the owner's machine (ADR-0029); CI gets no server access.
5. The server image of a pre-release is pushed under its version only, never as
   `X.Y` or `latest` (unchanged).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Pre-releases on the Play internal track too | One channel for testers | Testers need Play access; the internal track is the gate for production releases |
| Separate beta app `app.setding.beta` in the GitHub Release | Runs next to the release | Separate data and sign-in; the local beta (`make android-install`) already covers this |
| Pre-release apps keep the production server | No build difference | New app against an older server; test data in production |
| Deploy pre-releases to staging from CI | No manual step | An SSH deploy key in GitHub secrets; production deploys are manual anyway |

## Consequences

- Release testing on devices without Play and without production.
- A tester who was signed in to production before installing a pre-release stays
  on production and switches to `api.setding.dev` in the settings to test the
  pre-release server; a fresh installation starts on staging.
- An installation that stayed on staging keeps it after the final release
  (its session belongs there) until the server is changed in the settings.
- Pre-releases use the shared build number counter like test builds.

## Decision log

- 2026-11-27: Proposed (#1178). Owner decisions: pre-release apps default to the
  staging server; the pre-release server is deployed to staging manually with
  `make server-release`, not from CI.
- 2026-11-27: Accepted by the owner.

## Open points

- Pre-releases on the website (download page) are not shown; GitHub's "latest
  release" skips them.
