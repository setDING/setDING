#!/usr/bin/env bash
# Creates a consistent backup of a running setDING server now, in the format
# of PocketBase's own backups (a ZIP of the data directory, ADR-0063 §4), so
# the admin UI lists it and can restore it. Installed by install.sh as
# /usr/local/bin/setding-backup-now; used by `make server-backup` and before
# every update.
#
#   setding-backup-now [name]     default: manual-<timestamp>
#
# The database is copied with SQLite's online backup API (safe while the
# server runs, also in WAL mode) and checked; the stored files are added.
# Environment (for the tests): PB_DATA (default /var/lib/setding/pb_data),
# OWNER (default setding, if that user exists).
set -euo pipefail

PB_DATA="${PB_DATA:-/var/lib/setding/pb_data}"
OWNER="${OWNER:-setding}"
# PocketBase accepts backup names of [a-z0-9_-] with .zip.
name="$(printf '%s' "${1:-manual-$(date +%Y%m%d-%H%M%S)}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '_')"
archive="$PB_DATA/backups/$name.zip"

if [ ! -f "$PB_DATA/data.db" ]; then
  echo "no database yet ($PB_DATA/data.db), nothing to back up"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
sqlite3 "$PB_DATA/data.db" ".backup '$tmp/data.db'"
[ "$(sqlite3 "$tmp/data.db" 'PRAGMA integrity_check;')" = ok ] || {
  echo "integrity check of the backup failed" >&2
  exit 1
}

mkdir -p "$PB_DATA/backups"
(cd "$tmp" && zip -q "$archive.part" data.db)
if [ -d "$PB_DATA/storage" ]; then
  (cd "$PB_DATA" && zip -q -r "$archive.part" storage)
fi
mv "$archive.part" "$archive"
if id "$OWNER" >/dev/null 2>&1; then chown "$OWNER:" "$PB_DATA/backups" "$archive"; fi
echo "backup written: $archive ($(du -h "$archive" | cut -f1))"
