# Server operations

How the PocketBase backend of setDING is set up and run. Decisions:
[ADR-0004](../architecture/adr/0004-backend-and-sync.md) (backend and sync) and
[ADR-0014](../architecture/adr/0014-server-hosting.md) (hosting and operations).
The same container serves the website and user documentation
([ADR-0030](../architecture/adr/0030-website-and-user-docs.md)).

```
Tablets ──HTTPS──▶ Cloudflare ──tunnel──▶ cloudflared ──▶ PocketBase 127.0.0.1:8090
Browsers ─HTTPS──▶  (setding.app)             └─────────▶ Caddy      127.0.0.1:8081
                                          └──────── Debian LXC on Proxmox ────────┘
```

## Production instance

| | |
|---|---|
| Public URL | `https://api.setding.app` (Cloudflare Tunnel) |
| Container | Proxmox CT 600, Debian 13, 2 vCPU, 2 GB RAM, 16 GB disk |
| LAN address | `192.168.1.40` (SSH as root with key) |
| Installed | 2026-11-15, PocketBase 0.40.6 |

The `make server-*` targets use `SERVER` as the SSH target; it defaults to the
production instance (`root@192.168.1.40`). Override it for another instance, e.g.
`make server-install SERVER=root@<staging-ip>`.

| Target | What it does |
|---|---|
| `make server-release [VERSION=X.Y.Z]` | **Production updates:** after a release, wait for its green build, then deploy from the tag and stamp the version (default: newest tag) |
| `make server-install` | Install or update everything from the working tree (idempotent); stamped `X.Y.Z-dev+<commit>` unless it is a clean release tag. First install, test instances, emergencies |
| `make server-site` | Build the website from the working tree and deploy only the website (documentation fixes between releases) |
| `make server-status` | Services, PocketBase version, health, latest backups, disk |
| `make server-logs` | Follow the PocketBase, Caddy and tunnel logs |
| `make server-backup` | Run a backup now |
| `make server-fetch-backup` | Copy the latest backup to `.server-backups/` (off-host copy) |
| `make server-founder-invite NAME="…"` | One-time link that founds the organization `NAME` (section 7) |
| `make server-ssh` | Shell on the server |

## 1. Create the container (owner, Proxmox)

- Template: Debian 13 standard. **Unprivileged**, nesting on (default).
- 1 vCPU, 1 GB RAM, 512 MB swap, 16 GB disk, start at boot.
- Network: DHCP reservation or static IP. No port forwarding needed.
- **SSH public key:** paste the public key of the development machine
  (`~/.ssh/id_ed25519.pub`) so agents can log in as root with a key.

Check the login from the development machine: `ssh root@<ip> true`.

## 2. Install (agent or owner)

```bash
make server-install SERVER=root@<ip>
```

The script ([`tool/server/install.sh`](../../tool/server/install.sh)) installs the
pinned PocketBase version (`PB_VERSION` in the `Makefile`), hooks and migrations from
[`server/`](../../server), the systemd units, the backup timer, `cloudflared`,
unattended security updates, sets the time zone to `Europe/Zurich` (the clock itself
comes from the Proxmox host), and switches SSH to keys only (only if root has an
authorized key). It ends with a health check.

## 3. Cloudflare tunnel (owner)

Tokens and account settings stay with the owner (ADR-0014).

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels** → create a tunnel
   (cloudflared), e.g. `setding`.
2. On the server, run the shown install command once:
   `cloudflared service install <TOKEN>`.
3. **Public hostname:** e.g. `api.setding.app` → service `HTTP` → `localhost:8090`.
4. **Access:** create an Access application for the path `api.setding.app/_/*` only
   (admin UI), allowing only the owner's email. Do not protect the whole hostname.
5. **Security → Bots:** make sure Bot Fight Mode or challenges do not apply to this
   hostname (add a WAF skip rule if needed).

`make server-status` should now show `cloudflared` as active.

## 4. PocketBase superuser and settings (owner)

1. Create the superuser on the server:
   `runuser -u pocketbase -- /opt/pocketbase/pocketbase superuser upsert <email> <password> --dir=/var/lib/pocketbase/pb_data`
   (or open the installer link from `journalctl -u pocketbase` through an SSH tunnel:
   `ssh -L 8090:127.0.0.1:8090 root@<ip>`).
2. Log in at `https://api.setding.app/_/` and enable MFA for superusers.
3. **Settings → Application:** set the application URL to `https://api.setding.app`.
4. **Settings → Trusted proxy:** header `CF-Connecting-IP`.
5. **Settings → Mail settings (SMTP):** needed for password reset emails from the
   app (ADR-0016) and for email verification (section 7). Until it is configured,
   reset requests are accepted but no email is sent.

## 5. Deep links for invitations (owner, once the apps are signed)

Invitation links are `https://api.setding.app/invite/<token>` (ADR-0005, ADR-0017).
Without the app, the link shows a landing page; with the app, Android opens it
directly once the domain is verified. The server serves the verification files from
settings in `/etc/setding/pocketbase.env` (read by `pocketbase.service`):

```bash
# SHA-256 fingerprint(s) of the Android signing certificate (Play App Signing:
# Play Console → App integrity), comma-separated.
SETDING_ANDROID_CERT_SHA256=AB:CD:…
# Apple Developer Team ID (for Universal Links, once the iOS app has the
# Associated Domains capability).
SETDING_APPLE_TEAM_ID=ABCDE12345
```

Then `systemctl restart pocketbase` and check
`https://api.setding.app/.well-known/assetlinks.json`. Without the file, both URLs
return 404 and links still work through the landing page, the `setding://` scheme,
pasting and the QR code. Cloudflare must not challenge `/invite/*` and `/.well-known/*`
(only `/_/*` is behind Access, see step 3).

**Invitation key:** `make server-install` adds a random `SETDING_INVITE_KEY` to
`/etc/setding/pocketbase.env` once if it is missing. The server encrypts the stored
invitation tokens with it, so admins can show an active link again (ADR-0005). Keep
the line when editing the file; the backups (`pb_data`) do not contain it. A new or
lost key only means that links created before cannot be shown again; they keep
working.

## 6. Web client (owner, once)

The web client (ADR-0018) is a Flutter web build that `make server-install` builds
(`make web`) and copies to `/opt/pocketbase/pb_public`; PocketBase serves it
(`--publicDir`, set in `pocketbase.service`) on every hostname of the tunnel, with
the headers `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: credentialless` (hook `web.pb.js`), so browsers keep
its database in OPFS, and `Cache-Control: no-cache`, so browsers and Cloudflare
revalidate its files after a deploy instead of keeping the old build for hours. Do not
add a Cloudflare cache rule with a fixed edge TTL for `app.setding.app`; after the
first deploy with this header, purge the hostname's cache once. The web client calls the API on the hostname it was loaded
from, so no CORS setting is needed.

1. Tunnel → **Public hostname:** `app.setding.app` → service `HTTP` →
   `localhost:8090` (the same PocketBase as `api.setding.app`). No Access policy
   for this hostname; the same bot rules as for the API apply.
2. Add the web client's URL to `/etc/setding/pocketbase.env`:

   ```bash
   # Public URL of the web client (ADR-0018).
   SETDING_WEB_URL=https://app.setding.app
   ```

3. `systemctl restart pocketbase`.
4. Cloudflare → **Caching → Configuration → Browser Cache TTL:** **Respect Existing
   Headers**, then **Purge Everything** once. With any other value, Cloudflare
   replaces `no-cache` with `max-age=<TTL>` (default 4 hours, `max-age=14400`) on
   the files it caches by extension (`.js`, `.otf`, …), but not on `/`. Browsers
   then combine a new `main.dart.js` with an old, tree-shaken
   `assets/fonts/MaterialIcons-Regular.otf`, so icons added in the new build are
   missing and the console reports "Could not find a set of Noto fonts" (#171).
   Check it with:

   ```bash
   curl -sI https://app.setding.app/main.dart.js | grep -i cache-control
   ```

   which must print `cache-control: no-cache`. Users who still see missing icons
   reload once without the cache (Ctrl+Shift+R).

With `SETDING_WEB_URL`, the invitation landing page offers **Open in the browser**
(`https://app.setding.app/invite/<token>`), and on that hostname `/invite/<token>`
opens the web client, which takes the token from the URL. Without it, the web client
is still reachable on `https://api.setding.app/`, but the landing page does not
link to it.

## 7. Registration and email verification (owner)

Who may create accounts is set in `/etc/setding/pocketbase.env` (ADR-0024);
`make server-install` only adds a missing `SETDING_INVITE_KEY` (section 5) and leaves the rest of this file alone:

```bash
# invite_only (default): accounts only with an invitation link, new
# organizations only with a founder invitation. open: anyone may sign up and
# found organizations.
SETDING_REGISTRATION=invite_only
# off (default) or required: new accounts confirm their email address before
# they can sign in. Needs SMTP (section 4); without it the server logs an
# error at start and keeps it off.
SETDING_EMAIL_VERIFICATION=off
```

Then `systemctl restart pocketbase`. Check the effective settings with
`curl -s https://api.setding.app/api/setding/config`.

**New organizations on an invite-only server:** create a founder invitation and send
the link to the person who will run the organization:

```bash
make server-founder-invite NAME="Music school"
```

It prints the link (`url`), valid for 7 days and usable once. Opening it in the
app lets the person sign up (or sign in) and founds the organization with them as
its admin; they then create bands and invite people. A fresh server starts the
same way. To revoke an unused founder invitation, set `revoked` on it in the
admin UI (collection `invites`, rows without an organization).

**Existing accounts** keep working when the mode or verification changes. When
turning verification on, mark accounts that were created before as verified in the
admin UI (collection `users`, field `verified`), or let them confirm their address
at their next sign-in (they get a mail).

**Minimum app version** (ADR-0029): the server refuses apps older than
`MIN_CLIENT_VERSION` in `server/pb_hooks/lib/compat.js` with HTTP 426, and the app
asks for an update. `SETDING_MIN_CLIENT_VERSION=1.2.0` in `pocketbase.env` can raise
it further, e.g. to lock out a broken release; it never lowers it. The admin UI and
superusers are never refused. After a release with a raised minimum, deploy the
server only once the GitHub Release is published
([releases](../development/releases.md#releases-that-require-an-update)).

**Rate limits** (Settings → Rate limits) are enabled by a migration: sign-up 5 per
minute, sign-in 20 per minute and invitation routes 30 per minute per IP address.
They rely on the trusted proxy header (section 4, `CF-Connecting-IP`); without it,
all requests seem to come from the tunnel and share one limit.
PocketBase's default rules stay active as well, e.g. `*:create` 20 requests per
5 s and `/api/` 300 per 10 s. The app waits and retries when it hits them (up to
about half a minute per request), so a large import syncs more slowly but completes.

## 8. Website (owner, once)

The website and user documentation (`website/`, ADR-0030) is a static build that
`make server-install`, `make server-release` and `make server-site` build
(`make site`) and copy to `/var/www/setding-site`. Caddy from Debian serves it on
`127.0.0.1:8081` ([`tool/server/Caddyfile`](../../tool/server/Caddyfile), installed by
[`tool/server/install-site.sh`](../../tool/server/install-site.sh)): files under
`/_astro/` are cached for a year (their names change with their content), all others
are revalidated, and `www.` redirects to the bare domain. The website comes last
in a server deploy: if building or installing it fails, the deploy prints a warning
and still finishes the PocketBase upgrade; fix the cause and run `make server-site`.

1. Tunnel → **Public hostname:** `setding.app` (empty subdomain) → service `HTTP` →
   `localhost:8081`.
2. Tunnel → **Public hostname:** `www.setding.app` → service `HTTP` →
   `localhost:8081` (Caddy redirects it to `https://setding.app`).
3. No Access policy for these hostnames. Bot protection may stay on; the website is
   only read by browsers.
4. Check `https://setding.app/` and `https://www.setding.app/en/`.

If Cloudflare already has DNS records for `setding.app` or `www`, delete them first;
the tunnel creates its own CNAME records.

## Updates

- **Debian security updates:** automatic (unattended-upgrades).
- **setDING versions:** production runs released versions only. After a release,
  `make server-release` deploys the tag once its release build passed (git workflow
  section 10). The deployed version is in `/opt/pocketbase/pb_hooks/setding-version.txt`
  and in `/api/setding/config` (`serverVersion`).
- **PocketBase:** releases are published at
  <https://ganigeorgiev.com/pocketbase/pocketbase/releases> (the GitHub repository is
  archived since v0.40.6, so watching it no longer announces updates). Read the release
  notes, change `PB_VERSION` in the `Makefile` in a PR;
  it reaches production with the next release (`make server-release`). Test it with
  `make server-install` on a staging container first, once there is one. Take a
  backup right before deploying a PocketBase update: its internal migrations cannot be
  undone by going back to the older binary.
- **Hooks and migrations:** change `server/pb_hooks` / `server/pb_migrations` in a PR
  (data model: ADR-0015, tests in `server/test`, run by `make check`); they reach
  production with the next release. PocketBase is restarted and applies new migrations.
  Never edit collections in the admin UI: such changes are not in the repository and
  are lost or conflict with the next migration.
- **Local instance for development:** `make backend` starts PocketBase with the
  repository's schema and hooks on `127.0.0.1:8090` (data in `.dev-data/pb_data`);
  it also serves the last web build (`make web-serve` builds it first). Sign-up is
  open there (`BACKEND_REGISTRATION=open`; `make backend BACKEND_REGISTRATION=invite_only`
  tries the invite-only mode).
- **Web client:** built from the same checkout by every deploy (from the tag with
  `make server-release`), so it always has the server's version.
- **cloudflared:** updated with the Debian packages (apt repository of Cloudflare).

## Backups

- **Daily on the server** (`setding-backup.timer`, 03:30 Swiss time): SQLite online backup of
  `data.db` (integrity checked) plus the `storage/` files (PDF attachments) as
  `/var/lib/pocketbase/backups/setding-<timestamp>.tar.gz`, kept 14 days.
- **Off-host:** include the container in the Proxmox backup job (snapshot mode), and
  fetch copies with `make server-fetch-backup`.

### Restore

On the server (`make server-ssh`):

```bash
systemctl stop pocketbase
cd /var/lib/pocketbase/pb_data
rm -f data.db-wal data.db-shm
tar -xzf /var/lib/pocketbase/backups/setding-<timestamp>.tar.gz
chown -R pocketbase:pocketbase /var/lib/pocketbase/pb_data
systemctl start pocketbase
```

Tested on a Debian 13 container: the restored database starts and answers
`/api/health`.
