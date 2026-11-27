# ADR-0063: Self-hosting distribution of the backend

- **Status:** Accepted
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

- **Production** moves to a small rented VPS (Infomaniak; first planned as Hostpoint, Switzerland) with a public
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
for `amd64` and `arm64`, attached to the GitHub Release together with a
`SHA256SUMS` file:

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

### 2. Two supported ways: the bundle and a Docker image

Both release artifacts are **supported and equally tested** (section 6); operators
pick the one that fits their host.

**a) The bundle, run natively** on a Linux host (any distribution with systemd):
unpack it, create an own system user, run it as a service. The documentation
shows an **example systemd unit** (hardened like today's `pocketbase.service`) and
the update steps (replace the bundle directory, keep `pb_data`, restart). Like
the compose file, the unit is an example in the docs, not a file in the release.
Configuration through environment variables (an `EnvironmentFile`), as in the
image. The owner's production server runs this way (section 7).

**b) The Docker image** `ghcr.io/setding/setding-server:X.Y.Z`
(multi-arch, also tagged `X.Y` and `latest` for final releases), built from the
bundle:

- Base image **`gcr.io/distroless/static-debian*:nonroot`**, pinned by digest; the
  digest is checked for updates like every other dependency (`make upgrade`,
  `make check-full`).
- Runs as the non-root user 65532; `pb_data` is a volume, created with that owner
  in the image, so named volumes work out of the box (bind mounts need a `chown`,
  documented).
- Listens on **plain HTTP** on port 8090 inside the container.
- `HEALTHCHECK` calls the binary itself (`pocketbase healthcheck`, a console
  command in the hooks), because distroless has no shell, `curl` or `wget`.

For both ways, configuration is only through **environment variables** (the
existing `SETDING_*` variables, `SETDING_INVITE_KEY` included); the server refuses
to start with a clear message when a required one is missing, instead of
generating secrets into the data directory.

### 3. No installer, no reverse proxy, no compose file in the package

- There is **no install script** for self-hosters.
- The package contains **no reverse proxy and no tunnel**, not even as an option.
  TLS and publication are the operator's choice.
- There is **no `docker-compose.yml` and no systemd unit in the release**; the
  documentation shows both as examples (and a matching `docker run`).

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
- Two installation pages of equal rank: **native with the bundle** (download,
  checksum, unpack, system user, example systemd unit, updates) and **Docker**
  (example `docker-compose.yml` and `docker run`).
- **Requirements for any reverse proxy:** HTTPS; forward the client IP and
  configure PocketBase's trusted proxy header (otherwise the rate limits of
  ADR-0004 hit all users behind the proxy at once); request bodies of at least
  25 MB; no response buffering and long timeouts for server-sent events; restrict
  the admin UI `/_/` (by IP or authentication), not the whole host.
- **Caddy as an example** configuration; other proxies (e.g. Zoraxy, Traefik,
  Nginx) only named.
- Configuration (`SETDING_*`), first superuser, founding the first organization,
  connecting the apps (server setting) with a screenshot, updates, backups and
  restore for both ways.
- The landing page names self-hosting as a feature and links the chapter.

### 6. Both ways are tested automatically on every release

Nothing about the bundle or the image is tested by hand:

- **Server smoke tests** (`tool/server-dist/`, part of `make check` when the
  server, the bundle or the image files change, and of `make check-full` and
  `make release-gate`) build the bundle and the image for the host architecture
  and check:
  - the **bundle** started natively: health, `serverVersion` equals `VERSION`,
    the web client is served, a sign-up and a sync round trip through the API,
    `founder-invite`, a backup and its restore; the **systemd unit taken from the
    documentation page** is checked with `systemd-analyze verify` and its
    `ExecStart` is the command the test starts;
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

### 7. The owner's servers use the published bundle

- **Production** (VPS) and **staging** (LXC) run the **bundle natively** with
  systemd, set up like the documented example, so staging mirrors production.
  The Docker image is not run by the owner; the automatic tests of section 6 cover
  it.
- `make server-release` deploys the release's **published bundle** to production
  after a green release build, as before: download from the GitHub Release, verify
  `SHA256SUMS`, swap the bundle directory, restart, check `serverVersion`. A staging
  target deploys a bundle built from the working tree or a branch
  (`SERVER_STAGING` in `local.mk`).
- The reverse proxy or tunnel in front of each of the owner's servers is part of the
  owner's operations tooling in `tool/server/`, not of the product.
- `tool/server/install.sh` becomes internal operations tooling (system user,
  systemd unit, tunnel or proxy, host hardening) and is no longer handed out.

### 8. The website is independent of the backend

The website is project infrastructure, not part of self-hosting. It keeps its own
deployment (`make server-site` with its own `SITE_SERVER`) and its own web server
configuration on the owner's server; installing or updating the backend no longer
touches it, and the website needs nothing from the backend to work (links to the
web client excepted).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Bundle and Docker image both supported, no installer** (chosen) | One source artifact; runs natively on a small VPS (as the owner's production) or in Docker on any VPS, NAS or home server; both tested as published | Two ways to document and test; native operators set up user and unit themselves (with the documented example) |
| Docker image as the only supported way | One way to document and test | The owner's own VPS runs without Docker; small hosts without Docker would be left out |
| Install script for Debian/Ubuntu | Familiar for small VPS users | Assumes distribution, init system and paths; a third thing to test; the bundle with an example unit does the same with less magic |
| Reverse proxy (Caddy) bundled or as an option | Zero-configuration HTTPS for beginners | Most self-hosters already have a proxy; two proxies conflict; ties the package to one proxy and its certificates |
| `docker-compose.yml` shipped in the release | Copy and run | One more file to version; operators change it anyway; the tested example in the docs gives the same |
| Debian or Alpine base image | Shell for debugging, `curl` for health checks | Larger, more packages to patch and more CVE reports for code we do not use |
| `scratch` base image | Smallest | No CA certificates, time zones or non-root user; we would rebuild what distroless has |
| Backups with the `sqlite3` binary (as today) | Proven, own archive format | Not available in distroless; a second tool to ship |
| Manual release checks of the server | No new tooling | The owner explicitly does not want manual steps; untested artifacts would reach self-hosters |

## Consequences

- Self-hosting becomes a documented product: a bundle and an image, tested examples
  for both, a clear list of proxy requirements; the owner runs the published bundle
  exactly as others do.
- The release workflow grows: bundle and image builds, smoke tests and a push to
  the GitHub container registry (`packages: write`).
- `make check` needs Docker for the image smoke test when server files change;
  machines without Docker skip it with a warning, `make release-gate` and the
  release workflow do not.
- The release workflow publishes the bundles with `SHA256SUMS`; `make server-release`
  no longer copies files from a checkout but installs the published bundle.
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
- 2026-11-24: The owner's production VPS runs without Docker: the **bundle becomes
  a second supported way** of equal rank (native with systemd, example unit in the
  docs and tested), released with `SHA256SUMS`; production and staging both run
  the published bundle natively; the image stays supported and is covered by the
  automatic tests.
- 2026-11-24: Accepted by the owner.
- 2026-11-24: §2 and §4 implemented (#1049): `serve` refuses to start without
  `SETDING_INVITE_KEY` (console commands do not need it); `pocketbase healthcheck
  [url]` (default `http://127.0.0.1:8090` or `SETDING_HEALTH_URL`); the server sets
  PocketBase's automatic backups from `SETDING_BACKUP_CRON` (default `0 3 * * *`,
  `off` turns them off) and `SETDING_BACKUP_KEEP` (default 14) at every start, the
  environment winning over the admin UI; invalid values stop the start. A restore
  unpacks the ZIP into an emptied `pb_data` (tested in `server/test/operations_test.dart`).
- 2026-11-24: §1 implemented (#1050): `make server-bundle` /
  `tool/server-dist/build-bundle.sh` builds the bundle (reproducible tar, PocketBase
  for the target architecture from its checksummed release, `SHA256SUMS`). The
  hooks find the bundled web client without `SETDING_PUBLIC_DIR`. The example
  systemd unit is `tool/server-dist/setding.service` (bundle in
  `/opt/setding/current`, data in `/var/lib/setding/pb_data`) until the
  self-hosting docs show it (#1053); `server/test/bundle_test.dart` starts the
  bundle as it is and with that unit's command.
- 2026-11-24: §2b implemented (#1051): `tool/server-dist/Dockerfile` on
  `gcr.io/distroless/static-debian13:nonroot` pinned by digest (checked by
  `tool/check-deps.sh`, including a newer Debian series); single stage, the build
  context holds the unpacked bundle, the program owned by root and only
  `/setding/pb_data` writable; `HEALTHCHECK` every 2 s while starting
  (`--start-interval`), then every 30 s. `make server-image`
  (`tool/server-dist/build-image.sh`) builds it for the bundle's architecture. The
  example compose file is `tool/server-dist/docker-compose.yml` until the docs
  show it (#1053); `server/test/image_test.dart` runs it.
- 2026-11-24: §6 implemented (#1052): `tool/server-dist/release-test.sh` builds
  the bundle and image per architecture and runs `bundle_test`, `image_test` and
  `upgrade_test` against them; the previous release's bundle comes from its GitHub
  Release or is built from its tag, its image from ghcr.io or built from that
  bundle. The release workflow's job `server` runs it for amd64 and arm64 (arm64
  **in full under QEMU**, which resolves that open point) before `publish`, which
  attaches the bundles; the job `server-image` pushes the multi-platform image from
  the same bundles after the GitHub Release (tags `X.Y.Z`, and `X.Y`, `latest` for
  final releases). `make release-gate` runs the release test for its own
  architecture. The bundles are released without an SBOM for now (owner,
  2026-11-24; #1062). The test found that a web build from a private directory made
  the bundle unreadable for the image's user; the bundle's permissions are now
  normalised.
- 2026-11-26: §8 implemented (#1054): the website has its own deployment
  (`make server-site [VERSION=…]` to `SITE_SERVER`, files in `tool/site/`); the server
  deploys no longer touch it.
- 2026-11-26: §5 implemented (#1053): the website chapter *Selbst hosten* /
  *Self-hosting* (overview, Docker, without Docker, reverse proxy, setup and
  operation) in de-CH and en, linked from the landing page, with a screenshot of
  the app's *Server* dialog. The example compose file, systemd unit and Caddyfile
  live only on these pages (the fixtures in `tool/server-dist/` are gone):
  `tool/server-dist/doc-example.py` hands them to the bundle, image and upgrade
  tests and to the ops checks, and fails when the German and English pages differ.

- 2026-11-26: §7 tooling (#1055): the owner's servers install the published bundle with `tool/server/install.sh` in the docs' layout and with the docs' unit; `make server-release` (production) and `make server-install` (test server, `setding.dev`) pick the host with `SERVER_PROD`/`SERVER_STAGING`. The website also lives on the production VPS, installed separately (owner).
- 2026-11-26: SBOMs (#1062, ADR-0037): each bundle has a CycloneDX SBOM as a release asset; the image's SBOM is attested to its digest on ghcr.io (signed with GitHub's attestations), which also resolves the open point of an SBOM per image.
- 2026-11-26: Request logs (#1118): the server also sets how many days PocketBase
  keeps its request logs (Settings → Logs, with IP addresses) from `SETDING_LOG_DAYS`
  (default 7, `0` keeps none) at every start, the environment winning over the admin
  UI; invalid values stop the start. The privacy policy on the website names the
  default (tested in `server/test/operations_test.dart`).
- 2026-11-27: Trusted proxy header (#1195): the server sets PocketBase's trusted
  proxy headers (Settings → Trusted proxy) from `SETDING_TRUSTED_PROXY_HEADER` (a
  header or a comma-separated list, `none` for direct exposure) at every start, the
  environment winning over the admin UI; an invalid value stops the start. Without
  the variable the admin UI's value stays and the server warns at every start while
  no header is trusted, since all clients behind a proxy would share one rate-limit
  bucket. The self-hosting examples set `X-Forwarded-For`; `install.sh` sets
  `CF-Connecting-IP` on the owner's hosts.

## Open points

- Signing the image and the bundles themselves (e.g. cosign); their SBOMs exist (#1062).
- Off-host backup copies for the owner's production VPS.
