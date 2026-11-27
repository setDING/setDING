# ADR-0036: Unobtrusive update check at the start

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

The installed apps are updated by each person, whenever they like: Android via
Obtainium, Linux and Windows by downloading a package from the GitHub Releases
(ADR-0021). Obtainium only helps people who set it up; on Linux and Windows
nobody learns about a new version. ADR-0029 covers the hard case (the server no
longer accepts the app); people should also hear about a new version **before**
that, so fixes reach them and the step to a new major release is small.

The hint must not disturb: setDING runs on stage, often offline, and a dialog or
a banner in the middle of a set is not acceptable (ADR-0007).

## Decision

### Where the newest version comes from

- `GET /api/setding/config` reports **`latestClientVersion`**: the version the
  server was deployed from with `make server-release`, which only runs after the
  GitHub Release with the packages is published (ADR-0014, ADR-0029). A server
  deployed from a working tree (`x.y.z-dev+<commit>`), the local backend and older
  servers report nothing.
- No request to GitHub or another third party: the app already talks to its
  server, nobody else learns who uses setDING, and there are no rate limits.

### When the app asks

- Only **installed release builds** (Android, Linux, Windows, iOS): not the web
  client (the server always serves the current build), debug builds or the
  Android beta build (`app.setding.beta`).
- **5 seconds after the start**, at most **once in 24 hours**. The answer is kept
  on the device (`shared_preferences`), so a known update is still shown while
  offline. Errors and missing network are silent.
- An update is a version that is newer by SemVer precedence (ADR-0028);
  pre-releases are only offered to people already running a pre-release.

### How it is shown

- A **dot** on the settings in the main navigation and on *Storage & info*.
- Under *Settings → Storage & info* a tile **"setDING x.y.z is available"** with
  the installed version and how to update (Obtainium on Android, the GitHub
  Releases otherwise); a tap opens the release page of that version.
- **Once per new version** a short SnackBar with *Details* (opens the release
  page). It goes away by itself after a few seconds, also with its action
  (`persist: false`), and is shown only while the main navigation is on top, so
  never in live mode or while editing; otherwise it is shown at a later start.
- No dialog and no coloured banner: those stay reserved for "Please update
  setDING" (ADR-0029).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **`latestClientVersion` from the own server** (chosen) | Already reachable, no third party, no rate limit, the deploy order guarantees the packages exist | A late server deploy delays the hint; self-hosted operators report the version they deployed |
| GitHub API `releases/latest` | Independent of the server deploy | Every client contacts GitHub (privacy), 60 requests/h per IP, another host that may be blocked |
| `version.json` on setding.app | Simple, cacheable | Another deploy step that can be forgotten |
| Dialog or banner at the start | Hard to miss | Disturbs, especially before a gig; the banner is reserved for ADR-0029 |
| Only on Linux/Windows | Obtainium covers Android | Obtainium is optional; one behaviour for all apps is simpler |

## Consequences

- People learn about new versions on every platform without being interrupted.
- Installing stays manual; an in-app installer (e.g. for Windows, #494/#495) can
  build on this check and add an *Install* action to the tile and the SnackBar.
- The hint depends on the server deploy: production must be updated with
  `make server-release` after each release, as the release process already says.

## Decision log

- 2026-11-18: Proposed (#498), implemented in #499.
- 2026-11-18: Accepted by the owner.
- 2026-11-19: Release notes in the app moved to ADR-0041 (#544).
- 2026-11-27: Google Play installs (ADR-0067, #1140): the app asks Android
  which store installed it (`app.setding/install_source`,
  `getInstallSourceInfo`); for Google Play (`com.android.vending`) the tile
  says to update in Google Play, the tile and the SnackBar's *Details* open
  the Play listing instead of the GitHub release, and the "Please update"
  banner (ADR-0029) offers *Open in Google Play* instead of copying the
  download link. The check itself is unchanged: the server's
  `latestClientVersion` may name a version Play does not offer yet (review,
  manual promotion), which is why it stays a hint.

## Open points

- A setting to switch the check off, if anyone asks for it.
