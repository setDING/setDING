#!/usr/bin/env bash
# Sets up or updates the RealChord server (PocketBase backend, ADR-0004/ADR-0014).
#
# Runs as root ON the server (a Debian LXC container). Idempotent: the same script
# installs a fresh container and updates an existing one. Normally started from the
# development machine with `make server-install`, which copies this directory and
# server/pb_hooks + server/pb_migrations to the server first.
#
#   install.sh <pocketbase-version>     e.g. install.sh 0.40.6
set -euo pipefail

PB_VERSION="${1:?usage: install.sh <pocketbase-version>}"
PB_VERSION="${PB_VERSION#v}"

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$SETUP_DIR/tool/server"

PB_USER=pocketbase
PB_HOME=/opt/pocketbase
PB_DATA=/var/lib/pocketbase/pb_data
BACKUP_DIR=/var/lib/pocketbase/backups

step() { printf '\n==> %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "install.sh must run as root" >&2; exit 1; }
. /etc/os-release
[ "${ID:-}" = debian ] || echo "warning: tested on Debian only (found: ${PRETTY_NAME:-unknown})" >&2

restart_pb=0

# --- System packages and automatic security updates -------------------------
step "System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl unzip sqlite3 unattended-upgrades >/dev/null
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# --- Time zone ----------------------------------------------------------------
# The clock comes from the Proxmox host (LXC); only the zone is set here, so logs,
# backup names and the backup timer use Swiss time. PocketBase stores UTC anyway.
TIMEZONE="${TIMEZONE:-Europe/Zurich}"
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "$TIMEZONE" ]; then
  step "Time zone $TIMEZONE"
  timedatectl set-timezone "$TIMEZONE"
fi

# --- SSH: keys only ----------------------------------------------------------
# Only when root has an authorized key, so the script never locks anyone out.
if [ -s /root/.ssh/authorized_keys ] && [ -d /etc/ssh/sshd_config.d ]; then
  step "SSH hardening"
  conf=/etc/ssh/sshd_config.d/10-realchord.conf
  new=$'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n'
  if [ "$(cat "$conf" 2>/dev/null)" != "${new%$'\n'}" ]; then
    printf '%s' "$new" >"$conf"
    sshd -t && systemctl reload ssh
  fi
fi

# --- PocketBase user and directories -----------------------------------------
step "PocketBase user and directories"
id "$PB_USER" >/dev/null 2>&1 ||
  useradd --system --home-dir /var/lib/pocketbase --shell /usr/sbin/nologin "$PB_USER"
install -d -o "$PB_USER" -g "$PB_USER" -m 750 /var/lib/pocketbase "$PB_DATA" "$BACKUP_DIR"
install -d -m 755 "$PB_HOME"

# --- PocketBase binary (pinned version, verified checksum) --------------------
step "PocketBase $PB_VERSION"
current="$("$PB_HOME/pocketbase" --version 2>/dev/null | awk '{print $NF}' || true)"
if [ "$current" != "$PB_VERSION" ]; then
  case "$(dpkg --print-architecture)" in
    amd64) arch=amd64 ;;
    arm64) arch=arm64 ;;
    *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
  esac
  zip="pocketbase_${PB_VERSION}_linux_${arch}.zip"
  base="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$zip" "$base/$zip"
  curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"
  (cd "$tmp" && grep " $zip\$" checksums.txt | sha256sum -c -)
  unzip -q -o "$tmp/$zip" pocketbase -d "$tmp"
  install -m 755 "$tmp/pocketbase" "$PB_HOME/pocketbase"
  echo "PocketBase ${current:-not installed} -> $PB_VERSION"
  restart_pb=1
else
  echo "already installed"
fi

# --- Hooks and migrations from the repository ---------------------------------
step "Hooks and migrations"
for dir in pb_hooks pb_migrations; do
  src="$SETUP_DIR/server/$dir"
  dst="$PB_HOME/$dir"
  mkdir -p "$src"
  if ! diff -r -q --exclude=.gitkeep "$src" "$dst" >/dev/null 2>&1; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
    rm -f "$dst/.gitkeep"
    echo "$dir updated"
    restart_pb=1
  fi
done

# --- systemd units -------------------------------------------------------------
step "systemd units"
install_unit() {
  if ! cmp -s "$HERE/$1" "/etc/systemd/system/$1"; then
    install -m 644 "$HERE/$1" "/etc/systemd/system/$1"
    echo "$1 updated"
    return 0
  fi
  return 1
}
install_unit pocketbase.service && restart_pb=1
install_unit realchord-backup.service || true
install_unit realchord-backup.timer || true
install -m 755 "$HERE/realchord-backup.sh" /usr/local/bin/realchord-backup
systemctl daemon-reload
systemctl enable --now pocketbase.service realchord-backup.timer >/dev/null
if [ "$restart_pb" -eq 1 ]; then
  systemctl restart pocketbase.service
fi

# --- cloudflared (the tunnel itself is connected by the owner, see docs) ------
step "cloudflared"
if [ ! -f /etc/apt/sources.list.d/cloudflared.list ]; then
  install -d -m 755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
    -o /usr/share/keyrings/cloudflare-public-v2.gpg
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    >/etc/apt/sources.list.d/cloudflared.list
  apt-get update -q
fi
apt-get install -y -q cloudflared >/dev/null
cloudflared --version

# --- Health check --------------------------------------------------------------
step "Health check"
for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8090/api/health >/dev/null 2>&1; then
    echo "PocketBase is up on 127.0.0.1:8090"
    break
  fi
  sleep 0.5
done
curl -fsS http://127.0.0.1:8090/api/health >/dev/null || {
  echo "PocketBase does not answer; see: journalctl -u pocketbase" >&2
  exit 1
}
if systemctl is-active --quiet cloudflared; then
  echo "Cloudflare tunnel: running"
else
  echo "Cloudflare tunnel: not connected yet (run 'cloudflared service install <TOKEN>', see docs/operations/server.md)"
fi
