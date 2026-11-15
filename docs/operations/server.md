# Server operations

How the PocketBase backend of RealChord is set up and run. Decisions:
[ADR-0004](../architecture/adr/0004-backend-and-sync.md) (backend and sync) and
[ADR-0014](../architecture/adr/0014-server-hosting.md) (hosting and operations).

```
Tablets ──HTTPS──▶ Cloudflare ──tunnel──▶ cloudflared ──▶ PocketBase 127.0.0.1:8090
                                          └──────── Debian LXC on Proxmox ────────┘
```

All `make server-*` targets need `SERVER`, the SSH target (root), e.g.
`SERVER=root@realchord`. Export it once (`export SERVER=root@realchord`) or add a
host alias in `~/.ssh/config`.

| Target | What it does |
|---|---|
| `make server-install` | Install or update everything (idempotent) |
| `make server-status` | Services, PocketBase version, health, latest backups, disk |
| `make server-logs` | Follow the PocketBase and tunnel logs |
| `make server-backup` | Run a backup now |
| `make server-fetch-backup` | Copy the latest backup to `.server-backups/` (off-host copy) |
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
unattended security updates, and switches SSH to keys only (only if root has an
authorized key). It ends with a health check.

## 3. Cloudflare tunnel (owner)

Tokens and account settings stay with the owner (ADR-0014).

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels** → create a tunnel
   (cloudflared), e.g. `realchord`.
2. On the server, run the shown install command once:
   `cloudflared service install <TOKEN>`.
3. **Public hostname:** e.g. `api.<domain>` → service `HTTP` → `localhost:8090`.
4. **Access:** create an Access application for the path `api.<domain>/_/*` only
   (admin UI), allowing only the owner's email. Do not protect the whole hostname.
5. **Security → Bots:** make sure Bot Fight Mode or challenges do not apply to this
   hostname (add a WAF skip rule if needed).

`make server-status` should now show `cloudflared` as active.

## 4. PocketBase superuser and settings (owner)

1. Create the superuser on the server:
   `runuser -u pocketbase -- /opt/pocketbase/pocketbase superuser upsert <email> <password> --dir=/var/lib/pocketbase/pb_data`
   (or open the installer link from `journalctl -u pocketbase` through an SSH tunnel:
   `ssh -L 8090:127.0.0.1:8090 root@<ip>`).
2. Log in at `https://api.<domain>/_/` and enable MFA for superusers.
3. **Settings → Application:** set the application URL to `https://api.<domain>`.
4. **Settings → Trusted proxy:** header `CF-Connecting-IP`.

## Updates

- **Debian security updates:** automatic (unattended-upgrades).
- **PocketBase:** read the release notes, change `PB_VERSION` in the `Makefile` in a PR,
  run `make server-install` (on a staging container first, once there is one).
- **Hooks and migrations:** change `server/pb_hooks` / `server/pb_migrations` in a PR,
  then `make server-install`; PocketBase is restarted and applies new migrations.
- **cloudflared:** updated with the Debian packages (apt repository of Cloudflare).

## Backups

- **Daily on the server** (`realchord-backup.timer`, 03:30): SQLite online backup of
  `data.db` (integrity checked) plus the `storage/` files (PDF attachments) as
  `/var/lib/pocketbase/backups/realchord-<timestamp>.tar.gz`, kept 14 days.
- **Off-host:** include the container in the Proxmox backup job (snapshot mode), and
  fetch copies with `make server-fetch-backup`.

### Restore

On the server (`make server-ssh`):

```bash
systemctl stop pocketbase
cd /var/lib/pocketbase/pb_data
rm -f data.db-wal data.db-shm
tar -xzf /var/lib/pocketbase/backups/realchord-<timestamp>.tar.gz
chown -R pocketbase:pocketbase /var/lib/pocketbase/pb_data
systemctl start pocketbase
```

Tested on a Debian 13 container: the restored database starts and answers
`/api/health`.
