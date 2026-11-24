# ADR-0063: Self-hosting distribution of the backend

- **Status:** Proposed
- **Date:** 2026-11-24

## Context

Self-hosting is a central promise of setDING: a band, music school or association
keeps its songs and sets on its own server (ADR-0004, data protection in the
architecture README). So far there is only the owner's own installation
(ADR-0014): `tool/server/install.sh` sets up a Debian LXC over SSH with PocketBase
as a systemd service, a Cloudflare Tunnel, Caddy for the website (ADR-0030), a
backup timer using the `sqlite3` binary, unattended upgrades and SSH hardening.
That script is tailored to the owner's Proxmox and Cloudflare setup; for anyone
else it is not a self-hosting offer, and the website gives no guidance.

At the same time the owner's own operations change:

- **Production** moves to a small rented VPS (Hostpoint, Switzerland) with a public
  IP address.
- The current **LXC** stays as a **staging** server for testing branches,
  PocketBase updates and migrations (an open point of ADR-0014).
- The **website** (`setding.app`) stays on the owner's server, but must not depend
  on the backend installation any more.

Forces:

- People who self-host usually already run a reverse proxy (Caddy, Traefik,
  Nginx Proxy Manager, Zoraxy, a Cloudflare Tunnel …) and do not want a second one.
- The server and the apps must stay compatible (`MIN_CLIENT_VERSION`, ADR-0029);
  a self-hoster must be able to tell which server version goes with which app.
- The owner wants the releases tested **without manual steps**: every way of
  running the server that we hand out must be exercised automatically before a
  release is published.
- External dependencies are always used in their newest version
  (docs/development/dependencies.md); new dependencies must be MIT-compatible.
- PocketBase is one statically linked Go binary (pure-Go SQLite, no cgo); it
  finds `pb_hooks`, `pb_migrations` and `pb_public` next to its data directory by
  default and lets hooks register console commands (`founder-invite` already
  exists, ADR-0024) and cron jobs.
- The app uses PocketBase realtime (server-sent events) besides the delta sync,
  and uploads PDF attachments of up to 20 MB (ADR-0009).

## Decision

### 1. One server bundle per release

Every release produces a **server bundle** `setding-server-X.Y.Z-linux-<arch>.tar.gz`
for `amd64` and `arm64`, attached to the GitHub Release:

```
setding-server-X.Y.Z/
  pocketbase        the pinned PocketBase version (PB_VERSION, checksum verified)
  pb_hooks/         from server/, stamped with the version
  pb_migrations/    from server/
  pb_public/        the Flutter web client of the same commit (ADR-0018)
  VERSION
  LICENSES/         licence notices of PocketBase and the bundled parts
```

The bundle runs as it is: `./pocketbase serve --http=127.0.0.1:8090` creates
`pb_data/` next to it. Its version is the app version, so "server X.Y.Z goes with
app X.Y.Z" is always true. It is the single source for every way of running the
server, including the owner's.

### 2. Docker image as the one supported way

A **Docker image** `ghcr.io/tafli/setding-server:X.Y.Z` (multi-arch, also tagged
`X.Y` and `latest` for final releases) is built from the bundle:

- Base image **`gcr.io/distroless/static-debian*:nonroot`**, pinned by digest; the
  digest is checked for updates like every other dependency (`make upgrade`,
  `make check-full`).
- Runs as the non-root user 65532; `pb_data` is a volume, created with that owner
  in the image, so named volumes work out of the box (bind mounts need a `chown`,
  documented).
- Listens on **plain HTTP** on port 8090 inside the container.
- `HEALTHCHECK` calls the binary itself (`pocketbase healthcheck`, a console
  command in the hooks), because distroless has no shell, `curl` or `wget`.
- Configuration only through **environment variables** (the existing `SETDING_*`
  variables, `SETDING_INVITE_KEY` included); the server refuses to start with a
  clear message when a required one is missing, instead of generating secrets
  into the data volume.

Docker is the **only supported** installation. Running the bundle without Docker
is documented as a manual installation (unpack, own user, a systemd unit as an
example), but it is not a second supported product.

### 3. No installer, no reverse proxy, no compose file in the package

- There is **no install script** for self-hosters.
- The package contains **no reverse proxy and no tunnel**, not even as an option.
  TLS and publication are the operator's choice.
- There is **no `docker-compose.yml` in the release**; the documentation shows one
  as an example (and a matching `docker run`).

### 4. Admin tasks and backups inside the server

Everything an operator needs works the same in the container and with the bundle,
as PocketBase console commands registered in `pb_hooks`:

- `pocketbase founder-invite "<name>"` (exists, ADR-0024),
- `pocketbase healthcheck`,
- further commands only when an operation needs them.

**Backups** move into the server: a hook cron job creates a consistent backup of
the database and the stored files into `pb_data/backups` on a configurable
schedule with a configurable number kept (defaults: daily, 14), using PocketBase's
own backup function instead of the `sqlite3` binary, which a distroless image does
not have. Restoring is documented (and tested, see 6). Off-host copies stay the
operator's job; the documentation says so clearly.

### 5. Documentation for self-hosters

A **"Self-hosting"** chapter on the website (de-CH and en, ADR-0030), separate from
the owner's operations guide `docs/operations/server.md`:

- What you get, requirements (a Linux host with Docker, a domain, a reverse proxy
  with TLS) and the version rule (update the apps first, then the server; ADR-0029).
- Quick start with the example `docker-compose.yml` and `docker run`.
- **Requirements for any reverse proxy:** HTTPS; forward the client IP and
  configure PocketBase's trusted proxy header (otherwise the rate limits of
  ADR-0004 hit all users behind the proxy at once); request bodies of at least
  25 MB; no response buffering and long timeouts for server-sent events; restrict
  the admin UI `/_/` (by IP or authentication), not the whole host.
- **Caddy as an example** configuration; other proxies (e.g. Zoraxy, Traefik,
  Nginx) only named.
- Configuration (`SETDING_*`), first superuser, founding the first organization,
  connecting the apps (server setting) with a screenshot, updates, backups and
  restore, the manual installation without Docker.
- The landing page names self-hosting as a feature and links the chapter.

### 6. Both ways are tested automatically on every release

Nothing about the bundle or the image is tested by hand:

- **Server smoke tests** (`tool/server-dist/`, part of `make check` when the
  server, the bundle or the image files change, and of `make check-full` and
  `make release-gate`) build the bundle and the image for the host architecture
  and check:
  - the **bundle** started natively: health, `serverVersion` equals `VERSION`,
    the web client is served, a sign-up and a sync round trip through the API,
    `founder-invite`, a backup and its restore;
  - the **image**, started with the **`docker-compose.yml` taken from the
    documentation page** (de and en must be identical), so the published example
    cannot rot: health and `HEALTHCHECK` status, runs as non-root, data survives a
    container restart, the same API checks;
  - the **upgrade** from the previous release: the previous release's image and
    bundle with seeded data, replaced by the new one, migrations run, data intact.
- The **release workflow** (ADR-0021) builds the bundles and the multi-arch image
  from the tag, runs the same smoke tests on both (arm64 under emulation, at least
  the health and version checks), and **publishes the image and attaches the
  bundles only when they pass**. The GitHub Release waits for them, so
  `make server-release` (which waits for a green release build) never deploys an
  untested server.

### 7. The owner's servers use the published image

- **Production** (VPS) and **staging** (LXC, Docker with nesting) run the published
  image with a compose file in the owner's operations tooling.
- `make server-release` deploys the release's image tag to production after a green
  release build, as before. A staging target deploys an image built from the working
  tree or a branch (`SERVER_STAGING` in `local.mk`).
- The reverse proxy or tunnel in front of each of the owner's servers is part of the
  owner's operations tooling in `tool/server/`, not of the product.
- `tool/server/install.sh` becomes internal operations tooling (Docker, tunnel,
  host hardening) and is no longer handed out.

### 8. The website is independent of the backend

The website is project infrastructure, not part of self-hosting. It keeps its own
deployment (`make server-site` with its own `SITE_SERVER`) and its own web server
configuration on the owner's server; installing or updating the backend no longer
touches it, and the website needs nothing from the backend to work (links to the
web client excepted).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Docker image + bundle, no installer** (chosen) | One artifact, one supported way; runs on any VPS, NAS or home server; tested as published | People without Docker install by hand |
| Install script for Debian/Ubuntu as a second supported way | Familiar for small VPS users; no Docker needed | A second product to test and maintain; assumes distribution, init system and paths; overlaps with what Docker does |
| Both script and Docker equally supported | Covers every audience | Double effort for every change to the server setup; the script would be the less tested one |
| Reverse proxy (Caddy) bundled or as an option | Zero-configuration HTTPS for beginners | Most self-hosters already have a proxy; two proxies conflict; ties the package to one proxy and its certificates |
| `docker-compose.yml` shipped in the release | Copy and run | One more file to version; operators change it anyway; the tested example in the docs gives the same |
| Debian or Alpine base image | Shell for debugging, `curl` for health checks | Larger, more packages to patch and more CVE reports for code we do not use |
| `scratch` base image | Smallest | No CA certificates, time zones or non-root user; we would rebuild what distroless has |
| Backups with the `sqlite3` binary (as today) | Proven, own archive format | Not available in distroless; a second tool to ship |
| Manual release checks of the server | No new tooling | The owner explicitly does not want manual steps; untested artifacts would reach self-hosters |

## Consequences

- Self-hosting becomes a documented product: one image, one example, a clear list
  of proxy requirements; the owner runs exactly what others run.
- The release workflow grows: bundle and image builds, smoke tests and a push to
  the GitHub container registry (`packages: write`).
- `make check` needs Docker for the image smoke test when server files change;
  machines without Docker skip it with a warning, `make release-gate` and the
  release workflow do not.
- Backups change format (PocketBase backup ZIP instead of the own tar.gz);
  `make server-backup` and `make server-fetch-backup` follow.
- `SETDING_INVITE_KEY` is no longer generated by an installer; operators set it
  (the docs show how to generate one). Existing keys keep working when moved into
  the container's environment.
- ADR-0014 (runtime, provisioning, backups) and ADR-0030 (website hosting) change
  accordingly; their decision logs record it.
- Follow-up decisions: monitoring and alerting of the production server; whether the
  web client keeps its own hostname (`app.setding.app`) or moves to the API host.

## Decision log

- 2026-11-24: Proposed (#1048) after a discussion with the owner: Docker image on a
  distroless base as the one supported way, a server bundle as its source, no
  installer, no proxy and no compose file in the package, the website independent
  of the backend, production on a VPS and the LXC as staging, both artifacts tested
  automatically on every release. Implementation issues: #1049 (healthcheck, configuration check, backups), #1050 (bundle), #1051 (image), #1052 (release workflow), #1053 (website chapter), #1054 (website deployment), #1055 (owner's servers).

## Open points

- Signing the image and the bundles (e.g. cosign, SBOM per image, ADR-0037).
- Whether the image smoke tests run under arm64 emulation in full or only the
  health and version checks.
- Off-host backup copies for the owner's production VPS.
