# ADR-0029: Minimum client version enforced by the server

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

ADR-0028 defines a major release as one after which clients of the previous major
version no longer work correctly with the server or data. Nothing enforced that:

- The server and the web client are deployed from `main` with `make server-install`
  (ADR-0014, ADR-0018); the installed apps are updated by each person, whenever
  they like (Obtainium, ADR-0021). Offline-first clients (ADR-0001) can run an old
  version for weeks.
- The client did not send its version, and the server did not say which versions
  it accepts. An outdated client failed somewhere in the sync with an unclear error,
  or worse, wrote data it no longer understood.

ADR-0028 left this as an open point.

## Decision

### Server

- **The minimum lives in the code:** `MIN_CLIENT_VERSION` in
  `server/pb_hooks/lib/compat.js`, starting at `0.0.0`. It depends on the
  migrations and hooks deployed with it, so the PR that makes an incompatible change
  raises it in the same change. `SETDING_MIN_CLIENT_VERSION` in
  `/etc/setding/pocketbase.env` can only raise it further (tests, or locking out
  clients by hand); the higher of the two applies.
- **Clients send their version** in the header `X-Setding-Version` (the version from
  `pubspec.yaml`, without the build number).
- **A global middleware** answers requests to `/api/collections/*` and
  `/api/setding/*` from clients older than the minimum with **HTTP 426 Upgrade
  Required** and `data.minClientVersion`. Versions are compared by SemVer
  precedence (`1.0.0-beta.1` < `1.0.0`; build metadata ignored).
- **Exceptions:** `GET /api/setding/config` (read before signing in), the superusers'
  collection and requests of superusers (admin UI, operator), `/api/health`,
  realtime and file downloads. They change nothing, and a sync triggered by a
  realtime event is checked anyway.
- **No header counts as `0.0.0`.** Apps before this ADR keep working as long as the
  minimum is `0.0.0` and are refused as soon as it is raised.
- `GET /api/setding/config` also reports `minClientVersion`.

### Client

- Every request carries `X-Setding-Version` (from the platform's package info).
- HTTP 426 becomes `BackendErrorKind.updateRequired`. It **never signs out**: the
  session and the local data stay.
- A sync that ends with `updateRequired` stops the automatic sync (realtime,
  timer, outbox trigger) until the next start; "Sync now" still tries. Local
  changes stay in the outbox and are pushed after the update.
- **"Please update setDING"** banner above the main navigation (sets, songs,
  settings), with the installed and the needed version. The installed apps point to
  Obtainium or the GitHub releases (with a button that copies the link); the web
  client offers **Reload**, since the server serves the current build. The banner is
  never shown in live mode: it opens as its own route above the navigation, and the
  sync is paused there anyway (ADR-0007).
- The sign-in screen compares the server's `minClientVersion` with the app version
  and shows the same hint before anyone tries to sign in.

### Release and deploy

Raising the minimum locks out every older app as soon as the server is deployed.
So, for a release with an incompatible change
([`releases.md`](../../development/releases.md)):

1. The PR with the incompatible change raises `MIN_CLIENT_VERSION` to the coming
   release version.
2. Tag the release and wait until the GitHub Release with the packages is published.
3. Only then run `make server-install`.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Server refuses outdated clients with 426** (chosen) | Old clients cannot damage data; one check for all routes; works for every client, including scripts | Every request carries a header; deploy order matters |
| Hint only: the client compares the config and shows a banner | No server change in the request path | Old clients keep syncing and may damage data, which is exactly what a major release is about |
| Minimum version as an operator setting only (`pocketbase.env`) | Changeable without a deploy | The minimum belongs to the server code, not to the operator; easy to forget after a deploy |
| Separate protocol number instead of the app version | Independent of release numbering | A second number to maintain next to SemVer (ADR-0028) |

## Consequences

- An incompatible server change can no longer reach old apps unnoticed; people see
  why nothing syncs and what to do.
- Apps released before this ADR do not know HTTP 426: they show a general server
  error once the minimum is raised. This ADR must therefore ship before the first
  incompatible change.
- The deploy order (release first, then server) becomes part of the release
  process.
- New server routes under `/api/setding/` are checked automatically; a route that
  must answer outdated clients has to be added to the exceptions.

## Decision log

- 2026-11-17: Proposed (#339). Resolves the open point "minimum client version" of
  ADR-0028.
- 2026-11-17: Accepted by the owner (#341).
- 2026-11-17: The deploy order is enforced (#345): `make server-release` deploys the
  server only after the tag's release build passed and the GitHub Release exists.

## Open points

- A direct link to the release page needs a URL launcher; for now the banner copies
  the link.
