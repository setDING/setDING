# Server operations

How the owner's setDING servers are set up and run. Decisions:
[ADR-0004](../architecture/adr/0004-backend-and-sync.md) (backend and sync),
[ADR-0014](../architecture/adr/0014-server-hosting.md) (hosting and operations) and
[ADR-0063](../architecture/adr/0063-self-hosting-distribution.md) (server bundle and
self-hosting). The owner's servers run the published **server bundle** in the layout
of the self-hosting documentation (*Without Docker*), plus what only they get: the
Cloudflare Tunnel, unattended updates, SSH hardening and a backup before every
update. The website (ADR-0030) is deployed on its own.

```
Tablets ──HTTPS──▶ Cloudflare ──tunnel──▶ cloudflared ──▶ setDING (PocketBase) 127.0.0.1:8090
Browsers ─HTTPS──▶                  └─────────────────▶ Caddy (website)      127.0.0.1:8081
```

| Server | Host | Hostnames |
|---|---|---|
| Production (`SERVER_PROD`) | VPS Lite at Infomaniak (Debian 13, amd64) | `api.setding.app`, `app.setding.app` |
| Website (`SERVER_SITE`) | the same VPS, installed separately | `setding.app`, `www.setding.app` |
| Test server (`SERVER_STAGING`) | LXC on the owner's Proxmox | `setding.dev` (e.g. `api.setding.dev`) |

## Servers and targets

The SSH targets have no defaults; put them into the git-ignored `local.mk` in the
project folder:

```make
SERVER_PROD    = debian@<vps>
SERVER_STAGING = root@<lxc>
SERVER_SITE    = debian@<vps>
```

A non-root user needs `sudo` without a password on its host; the targets run their
commands with `sudo -n` then. `TARGET=prod|staging` picks the server; the old names
`SERVER` and `SITE_SERVER` are refused with a hint.

| Target | What it does |
|---|---|
| `make server-release [VERSION=X.Y.Z]` | **Production updates** (default `TARGET=prod`): after a release, wait for its green build, then install the bundle published with it (default: newest tag) |
| `make server-install` | Install a bundle built from the working tree, stamped `X.Y.Z-dev+<commit>`, on the **test server** (default `TARGET=staging`). On production only with `TARGET=prod FORCE=1`, in an emergency |
| `make server-site [VERSION=X.Y.Z]` | Build the website and deploy it to `SERVER_SITE`: from the release tag after a release, from the working tree for documentation fixes (section 8) |
| `make server-status` | Services, version, health, latest backups, disk |
| `make server-logs` | Follow the setDING and tunnel logs |
| `make server-backup` | Create a backup now |
| `make server-fetch-backup` | Copy the latest backup to `.server-backups/` (off-host copy) |
| `make server-founder-invite NAME="…"` | One-time link that founds the organization `NAME` (section 7) |
| `make server-ssh` | Shell on the server |

All but `server-install` and `server-site` work on production unless
`TARGET=staging` is given.

## 1. Prepare a host (owner)

- **Debian 13**, 1 vCPU, 1–2 GB RAM, enough disk for the PDFs (production VPS: 20 GB).
  An LXC on Proxmox is **unprivileged** with nesting on (default).
- **SSH key** of the development machine (`~/.ssh/id_ed25519.pub`) for a user with
  `sudo` without a password (VPS: `debian`), or for `root` (LXC).
- No open ports: the Cloudflare Tunnel connects outwards.

Check from the development machine: `ssh <target> sudo -n true` (or `ssh root@<host> true`).

**Infomaniak blocks IP addresses** (banip/ipban) after repeated failed connection
attempts, e.g. many SSH connections that are reset in a row; port 22 then times out
from that address for a while (about 5 minutes in #1055). The `make server-*` targets
therefore reuse one SSH connection per server for 60 s (`ControlMaster`, see `SSH` in
the `Makefile`). If an address stays blocked, Infomaniak's support lifts it (with the
public IP address from <https://infomaniak.com/ip>). The VPS's own firewall (Manager →
Firewall) must allow port 22; the tunnel needs no incoming port.

## 2. Install (agent)

```bash
make server-release                 # production, the newest release
make server-install                 # test server, the working tree
```

`tool/server/deploy.sh` copies the bundle (downloaded from the GitHub Release and
checked against its `SHA256SUMS`, or built now for the host's architecture), the
systemd unit **of the self-hosting docs** and
[`tool/server/install.sh`](../../tool/server/install.sh) to the host and runs it as
root. It sets up:

| Path | What |
|---|---|
| `/opt/setding/setding-server-<version>/` | unpacked bundles (the newest three are kept for a rollback) |
| `/opt/setding/current` | symlink to the bundle in use |
| `/var/lib/setding/pb_data` | data: database, files, `backups/` |
| `/etc/setding/setding.env` | settings (`SETDING_*`), read by the unit |
| `/etc/systemd/system/setding.service` | the unit of the self-hosting docs |
| `/usr/local/bin/setding` | admin commands: `pocketbase …` as user `setding` on the installed data |
| `/usr/local/bin/setding-backup-now` | a backup now ([`backup-now.sh`](../../tool/server/backup-now.sh)) |

Besides that: `cloudflared`, unattended security updates, the time zone
`Europe/Zurich`, SSH with keys only (only if the login user has an authorized key),
a backup before every version change (`pre-update-<old version>`), and a health
check at the end. It refuses to run next to the installation from before the
bundles (`pocketbase.service`), which listens on the same port.

## 3. Cloudflare tunnel (owner)

Tokens and account settings stay with the owner (ADR-0014). Every host has its own
tunnel.

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels** → create a tunnel
   (cloudflared), e.g. `setding-prod`.
2. On the host, run the shown install command once:
   `sudo cloudflared service install <TOKEN>`.
3. **Public hostname:** e.g. `api.setding.app` → service `HTTP` → `localhost:8090`.
4. **Access:** create an Access application for the path `api.setding.app/_/*` only
   (admin UI), allowing only the owner's email. Do not protect the whole hostname.
5. **Security → Bots:** make sure Bot Fight Mode or challenges do not apply to this
   hostname (add a WAF skip rule if needed).

`make server-status` should now show `cloudflared` as active.

## 4. PocketBase superuser and settings (owner)

1. Create the superuser on the host:
   `sudo setding superuser upsert <email> <password>`
   (or open the installer link from `journalctl -u setding` through an SSH tunnel:
   `ssh -L 8090:127.0.0.1:8090 <target>`).
2. Log in at `https://api.setding.app/_/` and enable MFA for superusers.
3. **Settings → Application:** set the application URL to `https://api.setding.app`.
   Invitation links are built from it, never from the request's `Host` header;
   without it they point to `http://127.0.0.1:8090` and cannot be used by others.
4. **Settings → Trusted proxy:** header `CF-Connecting-IP`.
5. **Settings → Mail settings (SMTP):** needed for password reset emails from the
   app (ADR-0016) and for email verification (section 7). Until it is configured,
   reset requests are accepted but no email is sent.

## 5. Deep links for invitations (owner, once the apps are signed)

Invitation links are `https://api.setding.app/invite/<token>` (ADR-0005, ADR-0017).
Without the app, the link shows a landing page; with the app, Android opens it
directly once the domain is verified. The server serves the verification files from
settings in `/etc/setding/setding.env` (read by `setding.service`):

```bash
# SHA-256 fingerprint(s) of the Android signing certificate (Play App Signing:
# Play Console → App integrity), comma-separated.
SETDING_ANDROID_CERT_SHA256=AB:CD:…
# Apple Developer Team ID (for Universal Links, once the iOS app has the
# Associated Domains capability).
SETDING_APPLE_TEAM_ID=ABCDE12345
```

Then `sudo systemctl restart setding` and check
`https://api.setding.app/.well-known/assetlinks.json` and, with the web client,
`https://app.setding.app/.well-known/assetlinks.json`: links to sets and songs
(ADR-0065) use the web client's hostname, so Android verifies the app there too. Without the file, both URLs
return 404 and links still work through the landing page, the `setding://` scheme,
pasting and the QR code. Cloudflare must not challenge `/invite/*`, `/sets/*`, `/songs/*` and `/.well-known/*`
(only `/_/*` is behind Access, see step 3).

**Invitation key:** `install.sh` adds a random `SETDING_INVITE_KEY` to
`/etc/setding/setding.env` once if it is missing. The server encrypts the stored
invitation tokens with it, so admins can show an active link again (ADR-0005). Keep
the line when editing the file; the backups (`pb_data`) do not contain it. A new or
lost key only means that links created before cannot be shown again; they keep
working. **The server does not start without it** (ADR-0063): `pocketbase serve`
stops with `missing environment variable(s) SETDING_INVITE_KEY`; console commands
such as `founder-invite` still work. A host that takes over existing data gets the
key of the old host (see [Moving production](#moving-production-1055)).

## 6. Web client (owner, once)

The web client (ADR-0018) is a Flutter web build that comes with the server bundle
(`/opt/setding/current/pb_public`); PocketBase serves it
(`--publicDir`, set in `setding.service`) on every hostname of the tunnel, with
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
2. Add the web client's URL to `/etc/setding/setding.env`:

   ```bash
   # Public URL of the web client (ADR-0018).
   SETDING_WEB_URL=https://app.setding.app
   ```

3. `sudo systemctl restart setding`.
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

Who may create accounts is set in `/etc/setding/setding.env` (ADR-0024);
`install.sh` only adds a missing `SETDING_INVITE_KEY` (section 5) and leaves the rest of this file alone:

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

Then `sudo systemctl restart setding`. Check the effective settings with
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
asks for an update. `SETDING_MIN_CLIENT_VERSION=1.2.0` in `setding.env` can raise
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

The website and user documentation (`website/`, ADR-0030) is project
infrastructure, independent of the backend (ADR-0063 §8): it lives on
`SERVER_SITE` (the production VPS, installed separately), and only
`make server-site` deploys it. `make server-site VERSION=X.Y.Z` builds it from the
release tag (after a release), `make server-site` from the working tree
(documentation fixes between releases); both copy the build to
`/var/www/setding-site`. Caddy from Debian serves it on `127.0.0.1:8081`
([`tool/site/Caddyfile`](../../tool/site/Caddyfile), installed by
[`tool/site/install-site.sh`](../../tool/site/install-site.sh)): files under
`/_astro/` are cached for a year (their names change with their content), all others
are revalidated, and `www.` redirects to the bare domain. The website needs nothing
from the backend; it only links to the web client. `make server-install` and
`make server-release` never deploy it.

1. Tunnel of the website's host → **Public hostname:** `setding.app` (empty
   subdomain) → service `HTTP` → `localhost:8081`.
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
  `make server-release` installs the bundle published with it once its release build
  passed (git workflow section 10). The running version is in
  `/opt/setding/current/VERSION` and in `/api/setding/config` (`serverVersion`).
  Before switching, `install.sh` writes the backup `pre-update-<old version>`.
- **Rollback:** point `/opt/setding/current` back to the previous bundle
  (`sudo ln -sfn /opt/setding/setding-server-<old> /opt/setding/current`), restore
  the `pre-update-…` backup ([Restore](#restore)) if the new version has migrated the
  data, `sudo systemctl restart setding`.
- **Test server:** `make server-install` installs the working tree on
  `setding.dev`; `make server-release TARGET=staging` tries a release there first.
- **PocketBase:** releases are published at
  <https://ganigeorgiev.com/pocketbase/pocketbase/releases> (the GitHub repository is
  archived since v0.40.6, so watching it no longer announces updates). Read the release
  notes, change `PB_VERSION` in the `Makefile` in a PR (the bundle takes it from
  there); try it on the test server with `make server-install`; it reaches
  production with the next release. Its internal migrations cannot be undone by going
  back to the older binary, so the `pre-update-…` backup matters here.
- **Hooks and migrations:** change `server/pb_hooks` / `server/pb_migrations` in a PR
  (data model: ADR-0015, tests in `server/test`, run by `make check`); they reach
  production with the next release. The server is restarted and applies new
  migrations. Never edit collections in the admin UI: such changes are not in the
  repository and are lost or conflict with the next migration.
- **Local instance for development:** `make backend` starts PocketBase with the
  repository's schema and hooks on `127.0.0.1:8090` (data in `.dev-data/pb_data`);
  it also serves the last web build (`make web-serve` builds it first). Sign-up is
  open there (`BACKEND_REGISTRATION=open`; `make backend BACKEND_REGISTRATION=invite_only`
  tries the invite-only mode).
- **Web client:** part of the bundle (`pb_public`), so it always has the server's
  version.
- **cloudflared:** comes from Cloudflare's apt repository, which unattended-upgrades
  does not cover. `install.sh` updates it with every `make server-release` or
  `make server-install` and restarts a running tunnel when the version changed (a
  second without the tunnel). In between, by hand on the host:
  `sudo apt-get update && sudo apt-get install --only-upgrade cloudflared && sudo systemctl restart cloudflared`.

## Backups

- **Automatic, built into PocketBase** (ADR-0063): the server sets PocketBase's
  automatic backups (Settings → Backups) from `/etc/setding/setding.env` at every
  start, so changes in the admin UI are overwritten:

  ```bash
  # Cron expression (server time zone), default "0 3 * * *"; "off" turns them off.
  SETDING_BACKUP_CRON="0 3 * * *"
  # Number of automatic backups kept, default 14.
  SETDING_BACKUP_KEEP=14
  ```

  The request logs (Settings → Logs, with IP addresses) are set the same way:
  `SETDING_LOG_DAYS` (default 7, `0` keeps none). The privacy policy on the
  website names this value; change both together.

  They are ZIP files of `pb_data` (database and files, without the backups
  themselves) in `/var/lib/setding/pb_data/backups/`. An invalid value stops the
  start with a message.
- **Now and before updates:** `make server-backup` (and `install.sh` before every
  version change) runs `setding-backup-now`: SQLite's online backup of `data.db`
  (integrity checked) plus `storage/`, as a ZIP in the same format and folder, so
  the admin UI lists and restores it too. It is not counted against
  `SETDING_BACKUP_KEEP`; delete old ones by hand.
- **Off-host:** `make server-fetch-backup` copies the newest backup to
  `.server-backups/` on the development machine; do it regularly. The test server
  is also in the Proxmox backup job. Keep `SETDING_INVITE_KEY` safe separately.

### Restore

On the host (`make server-ssh`), with a backup from `/var/lib/setding/pb_data/backups/`:

```bash
sudo systemctl stop setding
cd /var/lib/setding/pb_data
sudo find . -mindepth 1 -maxdepth 1 ! -name backups -exec rm -rf {} +
sudo unzip -q backups/<backup>.zip
sudo chown -R setding:setding .
sudo systemctl start setding
```

`make check` runs `setding-backup-now` and exactly these restore steps against a test
PocketBase and checks records, users and attachment files
(`server/test/backup_test.dart`, `server/test/operations_test.dart`;
[operations tests](../development/operations-tests.md)). Alternatively the admin UI
restores a backup (Settings → Backups), and restarts the server itself.

### Health check

`sudo setding healthcheck` (or `pocketbase healthcheck [url]`, default
`http://127.0.0.1:8090` or `SETDING_HEALTH_URL`) exits with 0 when the server answers
`/api/health` and with 1 otherwise, e.g. for monitoring (ADR-0063).

## Moving production (#1055)

Production moves from the LXC (installation from before the bundles: `/opt/pocketbase`,
`/var/lib/pocketbase`, `/etc/setding/pocketbase.env`, `pocketbase.service`) to the VPS;
the LXC then becomes the test server. Plan and decisions:
[#1055](https://github.com/setDING/setDING/issues/1055).

1. **VPS installed:** `make server-release` (or, before the first release with
   bundles, `make server-install TARGET=prod FORCE=1`); `make server-status`.
2. **Settings:** copy every `SETDING_*` line of the LXC's
   `/etc/setding/pocketbase.env` into the VPS's `/etc/setding/setding.env`, replacing
   the generated `SETDING_INVITE_KEY` with the LXC's (otherwise existing invitation
   links cannot be shown again).
3. **Rehearsal** (production keeps running): on the LXC, `sqlite3 data.db ".backup …"`
   plus `storage/` (or the newest `setding-*.tar.gz` of the old backup timer); unpack
   it into an emptied `/var/lib/setding/pb_data` on the VPS, `chown -R setding:`,
   restart; compare record counts, a sign-in and a PDF through
   `ssh -L 8090:127.0.0.1:8090`. Reset the VPS's data afterwards.
4. **Switch-over** (about 15 minutes without sync; tell the band): on the LXC
   `systemctl stop pocketbase`, take the final backup as in step 3, restore it on the
   VPS, start, check; then the owner moves the public hostnames `api.setding.app` and
   `app.setding.app` (and the Access policy for `/_/*`) to the VPS's tunnel. Check
   from outside: `/api/health`, `/api/setding/config`, the web client, a sync, an
   invitation link.
5. **Afterwards:** `systemctl disable pocketbase setding-backup.timer` on the LXC, but
   keep `/var/lib/pocketbase` for 14 days (rollback: hostnames back, start
   `pocketbase`). Then remove the old installation and set the LXC up as the test
   server (`make server-install`, hostnames under `setding.dev`).

## Trash

Deleted songs, sets and attachments stay restorable for 30 days (ADR-0043). A
PocketBase cron job (`setding_trash_purge`, daily at 03:17, before the backup)
then purges them: the song text, set items and attachment files are removed, the
records stay as tombstones (`purged`) so that devices still learn about the
deletion. The log shows `Trash purged` with the number of records. A superuser
can run the purge at once with `POST /api/setding/trash/purge`. A file purged
from the trash is still in the backups of the last 14 days (`SETDING_BACKUP_KEEP`).

Deleted bands (ADR-0044) are in the same trash: after 30 days the purge marks the
band `purged`, purges its sets and removes its memberships and arrangements. A
superuser deleting a band in the admin UI also only moves it to the trash. To
remove one deleted band at once (abuse, a deletion request), a superuser sends
`POST /api/setding/trash/purge` with `{"collection": "bands", "id": "<band id>"}`.

Closed organizations (ADR-0044) are in the trash too. After 30 days the purge
**deletes everything of them for good**: bands, sets, arrangements, songs with their
attachment files, everybody's personal adjustments and annotations for its songs,
the mistake reports with their screenshots (ADR-0060),
invitations and the memberships with names and roles. Only a tombstone of the
organization without its name stays (`purged`); user accounts stay. A superuser
closing an organization in the admin UI also only moves it to the trash; to purge one
at once, send `{"collection": "organizations", "id": "<organization id>"}`. Because the
backups are kept for 14 days (`SETDING_BACKUP_KEEP`), the data of a closed organization is
gone from the server and its backups at the latest 30 + 14 days after the closing.
