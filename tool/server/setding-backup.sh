#!/usr/bin/env bash
# Consistent backup of the PocketBase data (ADR-0014). Installed as
# /usr/local/bin/setding-backup and run daily by setding-backup.timer.
#
# Uses SQLite's online backup API (safe while PocketBase is running, also in WAL
# mode) for the database and archives the stored files (PDF attachments).
# The auxiliary database (request logs) is not backed up.
#
# PB_DATA and BACKUP_DIR default to the server's paths; the backup test
# (server/test/backup_test.dart) points them at a test instance.
set -euo pipefail

PB_DATA="${PB_DATA:-/var/lib/pocketbase/pb_data}"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/pocketbase/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"

if [ ! -f "$PB_DATA/data.db" ]; then
  echo "no database yet ($PB_DATA/data.db), nothing to back up"
  exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sqlite3 "$PB_DATA/data.db" ".backup '$tmp/data.db'"
[ "$(sqlite3 "$tmp/data.db" 'PRAGMA integrity_check;')" = ok ] || {
  echo "integrity check of the backup failed" >&2
  exit 1
}

files=(-C "$tmp" data.db)
[ -d "$PB_DATA/storage" ] && files+=(-C "$PB_DATA" storage)

archive="$BACKUP_DIR/setding-$stamp.tar.gz"
tar -czf "$archive.part" "${files[@]}"
mv "$archive.part" "$archive"
find "$BACKUP_DIR" -name 'setding-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
echo "backup written: $archive ($(du -h "$archive" | cut -f1))"
