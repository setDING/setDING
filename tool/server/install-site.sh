#!/usr/bin/env bash
# Installs or updates the website and user documentation (ADR-0030) on the
# server: Caddy from Debian serves the static build on 127.0.0.1:8081, which the
# Cloudflare Tunnel publishes as setding.app (docs/operations/server.md).
#
# Runs as root ON the server, called by install.sh (make server-install,
# make server-release) and by deploy-site.sh (make server-site). Idempotent.
#
#   install-site.sh <setup-dir>     the website build is expected in <setup-dir>/site
set -euo pipefail

SETUP_DIR="${1:?usage: install-site.sh <setup-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE=/var/www/setding-site

step() { printf '\n==> %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "install-site.sh must run as root" >&2; exit 1; }

step "Website"
if ! command -v caddy >/dev/null; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q caddy >/dev/null
  echo "caddy installed"
fi
caddy_changed=0
if ! cmp -s "$HERE/Caddyfile" /etc/caddy/Caddyfile; then
  caddy validate --config "$HERE/Caddyfile" --adapter caddyfile >/dev/null 2>&1 ||
    { echo "Caddyfile is invalid" >&2; exit 1; }
  install -m 644 "$HERE/Caddyfile" /etc/caddy/Caddyfile
  echo "Caddyfile updated"
  caddy_changed=1
fi
systemctl enable --now caddy.service >/dev/null
[ "$caddy_changed" -eq 0 ] || systemctl restart caddy.service

# Read on every request: swapping the directory needs no restart.
if [ -f "$SETUP_DIR/site/index.html" ]; then
  if ! diff -r -q "$SETUP_DIR/site" "$SITE" >/dev/null 2>&1; then
    install -d -m 755 "$(dirname "$SITE")"
    rm -rf "$SITE.new"
    cp -r "$SETUP_DIR/site" "$SITE.new"
    chmod -R a+rX "$SITE.new"
    rm -rf "$SITE"
    mv "$SITE.new" "$SITE"
    echo "website updated"
  else
    echo "website unchanged"
  fi
else
  echo "no website build in this setup, $SITE left as it is"
fi

for _ in $(seq 1 20); do
  curl -fsS -o /dev/null http://127.0.0.1:8081/ 2>/dev/null && break
  sleep 0.5
done
if [ -f "$SITE/index.html" ]; then
  curl -fsS -o /dev/null http://127.0.0.1:8081/ ||
    { echo "The website does not answer; see: journalctl -u caddy" >&2; exit 1; }
  echo "Website is up on 127.0.0.1:8081"
fi
