# ADR-0031: Self-hosted servers for other operators

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

setDING is open source (MIT) and its server is PocketBase with the repository's
hooks and migrations (ADR-0004, ADR-0015). So far only the owner runs a server
(`api.setding.app`, ADR-0014), set up with `make server-*` targets from a
development checkout over SSH; the operations guide assumes Proxmox and a Cloudflare
Tunnel. The website promised "your own server", but:

- the app labels the server setting "Only change for testing";
- an invitation link carries only a token, so the app looks it up on whatever server
  it is set to; a link from another server fails;
- Android App Links are declared for `api.setding.app` only;
- installing needs a checkout with Flutter (the web client is built during the
  deploy), and `install.sh` always installs `cloudflared`.

The owner decided (2026-11-17) that organizations may run their own server, with an
installation guide on the website (ADR-0030).

## Decision

1. **Supported, not required.** `api.setding.app` stays the default server of the
   apps. Any organization may run its own server; people choose it in the app.
2. **Server package as a release asset.** Every release (ADR-0021) also publishes
   `setding-server-X.Y.Z.tar.gz` with its SHA-256: the hooks, the migrations, the
   built web client, the installer and its systemd units, stamped with the version.
   No Flutter, Node.js or checkout is needed on the server.
3. **One installer for everyone.** `install.sh` (ADR-0014) gets options instead of
   the owner's assumptions:
   - `--domain <host>` – the public hostname of the server;
   - `--tls caddy` (default for other operators) – Caddy from Debian on ports 80/443
     with an automatic Let's Encrypt certificate in front of PocketBase;
     `--tls cloudflare` – a Cloudflare Tunnel as today (no open ports);
     `--tls none` – PocketBase on `127.0.0.1:8090` behind the operator's own proxy;
   - `--website` – the setDING website (ADR-0030), only for `setding.app`.
   Supported targets: Debian 12 and 13, amd64 and arm64 (VM, LXC container or VPS).
   The guide installs with one command that downloads the package of a release,
   checks its checksum and runs the installer; updating is the same command with a
   newer version. The owner's `make server-*` targets keep working and use the same
   installer with `--tls cloudflare --website`.
4. **Operator commands on the server** instead of `make` targets: `setding-status`,
   `setding-backup` (exists), `setding-founder-invite "<name>"` and
   `setding-update [X.Y.Z]`, installed by `install.sh`.
5. **Invitation links name their server.** The links stay
   `https://<server>/invite/<token>`; the app reads the server from the link. If it
   differs from the app's server, the app asks before switching ("This invitation is
   for <server>. Switch server?"), which signs out like changing the server today. The
   landing page's `setding://` fallback carries the server as well
   (`setding://invite/<token>?server=<url>`). Android App Links stay verified for
   `api.setding.app` only; other servers open the landing page, whose button opens
   the app.
6. **The server setting becomes a real choice** in the app: "setDING server
   (api.setding.app)" or "Own server" with its address, checked against
   `/api/setding/config` before switching. The hint "Only change for testing" goes.
7. **Versions.** Operators update their server after each release; the release notes
   say when the server must be updated (major version, ADR-0028). The app's existing
   update prompt (ADR-0029) covers outdated apps; an app that is newer than its server
   shows "The server runs an older version of setDING – ask its operator to update"
   when the server's major version is lower.
8. **Operator guide** on the website (ADR-0030), chapter "Own server" (de-CH and en):
   requirements, installation, the settings in `pocketbase.env` (registration, email,
   web client URL), the first organization (founder invitation), backups and restore,
   updates. `docs/operations/server.md` stays the owner's runbook and links to it.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Release package + installer** (chosen) | One command, no build tools on the server, same installer as production | Debian/systemd only |
| Docker image | Runs anywhere with Docker, common for self-hosters | Second deployment path to build, test and document; the owner runs no Docker (ADR-0014) |
| Guide based on a checkout and `make server-install` | No new release artifact | Needs Flutter and Node.js; operators must SSH from a development machine |
| Only change the website text, no support | No work | Contradicts the decision; servers would still be possible but undocumented |
| Server chosen only in the settings, links unchanged | Simpler app | Invitations from own servers fail unless people configure the server first |

## Consequences

- Each release builds one more asset (the web client is already built for the
  server); the release workflow and `docs/development/releases.md` change.
- `install.sh` gets options and tests for them; the Caddy configuration of the
  website (ADR-0030) and the new reverse proxy share one Caddy.
- The app gets UI texts for the server choice, the invitation server switch and the
  "server too old" notice (both ARB files).
- Support questions from operators may come up; the guide and the GitHub issues are
  the channel.

## Decision log

- 2026-11-17: Proposed (#419) after the owner decided to support own servers with a
  guide.

## Open points

- Whether to offer a Docker image later.
- Email (SMTP) is needed for password reset and verification; the guide explains it,
  but there is no test mail command yet.
- iOS: Universal Links for other domains are not possible; the `setding://` fallback
  applies once there is an iOS app.
