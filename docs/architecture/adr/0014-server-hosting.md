# ADR-0014: Server hosting and operations

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

ADR-0004 chose a self-hosted PocketBase on an "existing server" and left open the
server details (OS, Docker, domain/HTTPS) and the backup concept. They are now known:

- The owner runs a **Proxmox** server and has a domain managed at **Cloudflare**.
- PocketBase is a single Go binary with SQLite; the load is small (a few bands with
  3–10 members each, PDFs up to 20 MB, ADR-0009).
- The server must be reachable from the internet over HTTPS: the apps sync from
  anywhere, and invitation links need a public landing page and deep-link
  verification files (ADR-0005).
- The server should be set up and maintained by agents from the repository, in a
  reproducible way. The tablets work offline (ADR-0001), so a short server outage
  only delays syncing.

## Decision

1. **Runtime:** an **unprivileged Debian LXC container** on the Proxmox server
   (1 vCPU, 1 GB RAM, 16 GB disk), with PocketBase as a **native systemd service**
   (own system user, data in `/var/lib/pocketbase/pb_data`), bound to
   `127.0.0.1:8090`. No Docker.
2. **Publication:** a **Cloudflare Tunnel** (`cloudflared` in the same container)
   publishes PocketBase under a hostname of the owner's domain. No open ports, no port
   forwarding, TLS handled by Cloudflare. This replaces the reverse proxy (Caddy)
   mentioned in ADR-0004.
   - Cloudflare Access protects **only the admin UI** (`/_/*`); the API stays open to
     the apps, which cannot complete an Access login.
   - Bot protection/challenges are disabled for this hostname, so they do not block
     API calls.
   - PocketBase trusts the `CF-Connecting-IP` header to see client IPs.
3. **Provisioning as code:** the idempotent script [`tool/server/install.sh`](../../../tool/server/install.sh)
   installs and updates the server: pinned PocketBase version (`PB_VERSION` in the
   `Makefile`, checksum verified), hooks and migrations from `server/`, systemd units,
   `cloudflared` from Cloudflare's apt repository, unattended security updates and SSH
   with keys only. It is run from the development machine via `make server-install`
   over SSH as root; further `make server-*` targets cover status, logs and backups.
4. **Secrets stay with the owner:** the tunnel token, the Cloudflare account, the
   Access policy and the PocketBase superuser password are set up by the owner, never
   by agents and never stored in the repository.
5. **Backups:** a systemd timer creates a daily backup on the server (SQLite online
   backup of `data.db` plus the `storage/` files, integrity checked, kept 14 days).
   Off-host copies: Proxmox backups of the whole container (vzdump/Proxmox Backup
   Server) and `make server-fetch-backup` to the development machine.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **LXC + native systemd service** (chosen) | Smallest footprint, simple updates (one binary), Proxmox snapshots/backups of the container | Tied to Debian/systemd; less isolation than a VM |
| VM with Docker (Compose) | Strong isolation, common deployment format | More resources and moving parts for a single binary |
| Docker inside the LXC | Container image as deployment unit | Nesting in unprivileged LXC is fiddly; no benefit for one binary |
| Port forwarding + Caddy (Let's Encrypt) | No dependency on Cloudflare, no upload limits | Open port, public home IP, certificate and router setup |
| Cloudflare Tunnel (chosen) | No open port, IP hidden, TLS and DDoS protection included | Dependency on Cloudflare; 100 MB upload limit per request (free plan) and ~100 s idle timeout for realtime (SSE) connections |
| PocketBase's built-in backups only | Configured in the admin UI, optional S3 upload | Needs superuser configuration by hand; not reproducible from the repository |

## Consequences

- The server can be rebuilt from scratch with `make server-install`; changes to the
  setup go through PRs like code.
- PDF uploads (max. 20 MB) stay well below Cloudflare's upload limit.
- The client must tolerate dropped realtime connections (the PocketBase SDK
  reconnects; the delta sync of ADR-0004 catches up anyway).
- PocketBase updates are deliberate: change `PB_VERSION`, read the release notes,
  run `make server-install` (ideally on a staging container first).
- Operations guide: [`docs/operations/server.md`](../../operations/server.md).

## Decision log

- 2026-11-15: Proposed after the owner chose Proxmox LXC + Cloudflare and asked for
  provisioning from the repository via `make`.
- 2026-11-15: Accepted by the owner.
- 2026-11-15: Production instance installed on an LXC container, public hostname `api.realchord.app`.
- 2026-11-15: The web client (ADR-0018, accepted) is served by the same PocketBase from `pb_public`, deployed with the server targets and published as a second tunnel hostname `app.realchord.app` (tunnel and DNS entry by the owner).
- 2026-11-15: The container time zone is set to `Europe/Zurich` by `install.sh` (it was `Etc/UTC`, so logs, backup names and the backup timer were an hour off). The clock comes from the Proxmox host; PocketBase keeps storing UTC.
- 2026-11-16: Web client hosting implemented (#27): `make server-install` builds it from the same commit and installs it to `/opt/pocketbase/pb_public` (`--publicDir`); `REALCHORD_WEB_URL` goes into `pocketbase.env` once the hostname exists (docs/operations/server.md step 6).
- 2026-11-17: **ADR-0024** (accepted): `pocketbase.env` gains `REALCHORD_REGISTRATION` (`invite_only` default / `open`) and `REALCHORD_EMAIL_VERIFICATION` (`off` default / `required`, needs SMTP); a `make` target creates founder invitations; rate limits for sign-up and invitation routes.
- 2026-11-17: App renamed to **setDING** (#318): public hostnames `api.setding.app` and `app.setding.app`, settings in `/etc/setding/pocketbase.env` with `SETDING_*` variables, backup units `setding-backup.*`. The RealChord installation on the production container is replaced by a fresh one (#320).
- 2026-11-17: Production is updated with `make server-release` after a release (#345): it waits for the tag's green release build and the GitHub Release, deploys from a clean checkout of the tag and stamps the version (`pb_hooks/setding-version.txt`, reported as `serverVersion` by `/api/setding/config`). `make server-install` deploys the working tree, stamped `X.Y.Z-dev+<commit>`, for the first install, test instances and emergencies.
- 2026-11-19: `make server-install` generates `SETDING_INVITE_KEY` in `pocketbase.env` once if it is missing (#579, ADR-0005); it encrypts the stored invitation tokens and is not part of the `pb_data` backups. The rest of the file stays the owner's.
- 2026-11-22: Host-specific details of the owner's installation (LAN address, container number and size) removed from the repository (#947). `SERVER` has no default any more; each machine sets it in the git-ignored `local.mk`.
- 2026-11-24: **ADR-0063** (accepted, #1048) changes runtime, provisioning and backups: production on a rented VPS and this LXC as staging, both running the published server bundle natively with systemd; `make server-release` installs the published bundle; `install.sh` becomes internal operations tooling; backups through PocketBase's own backup function in a hook cron job; the website deployed independently of the backend. The sections above describe the current installation until #1055 moves it.

- 2026-11-26: Operations tooling for ADR-0063 §7 (#1055): `tool/server/install.sh` installs a **server bundle** (`/opt/setding/current`, `/var/lib/setding/pb_data`, `/etc/setding/setding.env`, the systemd unit of the self-hosting docs, `/usr/local/bin/setding` and `setding-backup-now`), with cloudflared, unattended updates, SSH hardening and a backup before every version change; `pocketbase.service` and the `setding-backup` timer are gone, the built-in backups replace them. `make server-release` installs the bundle published with the release (checked against `SHA256SUMS`); `make server-install` builds one from the working tree for the test server. The targets use `SERVER_PROD`, `SERVER_STAGING` and `SERVER_SITE` (`TARGET=prod|staging`; `server-install` on production only with `FORCE=1`) and run as root or with `sudo -n`. Production moves to a Hostpoint VPS (Debian 13, amd64, own Cloudflare Tunnel, also serving the website), the LXC becomes the test server under `setding.dev` (owner, 2026-11-26); this resolves the open point of a staging server.
## Open points

- Monitoring/alerting (e.g. an uptime check on `/api/health`).
- Encrypting the PocketBase settings (`--encryptionEnv`) once SMTP/S3 credentials are stored there.
