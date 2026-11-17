# ADR-0028: Semantic versioning with setDING-specific bump rules

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

Releases are numbered `vX.Y.Z` since `v0.1.0`; a tag builds and publishes the
packages for Linux, Android and Windows (ADR-0021). The format looks like
[Semantic Versioning](https://semver.org/), but nothing defines **when** the major,
minor or patch number changes. So far the choice was made by feel in the
`chore(release)` PR.

Calendar versioning (CalVer, e.g. `26.11.0` for the first release in November 2026)
was raised as an alternative. To compare the two, it helps to see what a version
number has to tell the people involved:

- **setDING is a client and a server.** The server (PocketBase migrations and hooks,
  ADR-0015) and the web client (ADR-0018) are deployed with `make server-install`
  from `main`; they are always the newest state. The installed apps (Android via
  Obtainium, Linux, Windows) are updated by each band member, whenever they like.
- **Clients are offline-first** (ADR-0001) and may run an old version for weeks. A
  band only works on stage if every member's device still syncs with the server.
  The most important question for a band is therefore: *Do we all have to update
  now?*
- **Releases follow features, not a calendar.** There is no fixed release cadence,
  and the age of a version says little about what it can do.
- **Platforms constrain the format.** iOS (`CFBundleShortVersionString`) and Windows
  accept up to three numeric components; Android's `versionCode` is separate (the
  workflow's run number, ADR-0021). Both SemVer and a `YY.M.MICRO` CalVer fit.
- **No version check exists.** The client does not know the server's version, and
  the server does not know the client's. Compatibility is only kept by convention.

## Decision

### Scheme

setDING keeps **Semantic Versioning 2.0.0**. One version number covers the product:
the apps, the web client and the server built from the same repository state. It is
set in `app/pubspec.yaml` and tagged as `vX.Y.Z` (ADR-0021). The internal packages
(`packages/chordpro`, `server`) are not published and not versioned separately;
their `version` field has no meaning.

### What a bump means (from 1.0.0)

The rules are about **compatibility between devices and the server**, because that
is what decides whether a band can keep playing:

| Bump | When | Example |
|---|---|---|
| **Major** `X` | A client of the previous major version **can no longer work correctly** with the current server or data, so all devices of a band must update. | A collection or field old clients rely on is removed or renamed; the sync protocol changes incompatibly; access rules change so that old clients' writes fail; data written by new clients is damaged by old clients; a platform is dropped. |
| **Minor** `Y` | New features or changes that **old clients of the same major version tolerate**. | New screens or settings; new fields or collections that old clients ignore; local database migrations that run automatically on start; a new `x_` directive that older clients ignore. |
| **Patch** `Z` | Fixes **without new features** and without incompatible changes. | Bug fixes, translations, performance, dependency updates. |

Consequences for the server: because it is deployed from `main`, every server change
must stay compatible with **all released clients of the current major version**.
An incompatible server change is only deployed together with a major release.

### Before 1.0.0

While the version is `0.y.z`, the project is in early development (SemVer §4):

- **Minor** `y`: new features **and** incompatible changes.
- **Patch** `z`: fixes only.

Incompatible changes are allowed, but the release notes must say that all devices
have to be updated.

**1.0.0** is released when the owner declares the app ready for regular use by
bands; the roadmap items *Towards version 1* (CI as a required check, ADR-0010) are
expected to be done by then.

### Choosing the bump

The `chore(release)` PR takes the highest bump implied by the Conventional Commits
since the last tag:

- `feat` → minor, `fix` / `perf` → patch, other types (`docs`, `chore`, `refactor`,
  `test`, …) → patch if a release is made for them at all;
- a commit marked breaking (`!` or `BREAKING CHANGE:`) → major (minor before 1.0.0).

A commit is marked breaking when it meets the major rule above, not merely when it
changes an API inside the code base. The release notes start with a
**"Update required"** section when the release is a major one (minor before 1.0.0)
with incompatible changes.

Pre-releases keep the SemVer suffix `-beta.N` (ADR-0021).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **SemVer with setDING-specific rules** (chosen) | The number tells bands whether they must update; fits the existing tags, the release workflow and the platform formats; Conventional Commits already mark features, fixes and breaking changes | Needs discipline in the release PR; "breaking" must be judged against the rules, not by feel |
| CalVer `YY.M.MICRO` (e.g. `26.11.0`) | Users see at a glance how old a version is; no judgement needed for the bump | Says nothing about compatibility, the main question for offline clients; releases have no fixed cadence; a separate compatibility marker would be needed anyway |
| Hybrid (CalVer plus a compatibility number, e.g. `26.11` with "protocol 3") | Shows age and compatibility | Two numbers to explain and maintain; unusual for an app |
| SemVer without written rules (status quo) | No effort | The number means nothing reliable; breaking changes reach bands unannounced |

## Consequences

- Bands can read from the version whether they must update all devices before the
  next gig; the release notes repeat it.
- Server changes need care: they must not break released clients of the current
  major version, since the server is deployed from `main`.
- The release PR has to look at the commits since the last tag and justify the bump.
- The convention is not enforced technically yet; an old client against an
  incompatible server fails in unspecified ways (see open points).

## Decision log

- 2026-11-17: Proposed (#330) as ADR-0026, renumbered to ADR-0028 because ADR-0026 and ADR-0027 were taken in the meantime. CalVer was considered and not chosen, because the
  version number should tell bands whether their devices remain compatible.
- 2026-11-17: Accepted by the owner (#337).
- 2026-11-17: Open point "minimum client version" resolved by ADR-0029 (#339):
  clients send their version, the server refuses outdated ones with HTTP 426 and
  the app asks for an update.
- 2026-11-17: Open point "server deploys and releases" resolved (#345): production
  runs released versions only, deployed with `make server-release` from the tag after
  its release build passed; the server reports its version (`serverVersion`).

## Open points

- None.
