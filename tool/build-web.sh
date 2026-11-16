#!/usr/bin/env bash
# Builds the web client (ADR-0018) into app/build/web.
#
# drift runs the browser database with two files in app/web/:
# - sqlite3.wasm: release asset of package:sqlite3, checked in and pinned by
#   checksum to the version in app/pubspec.lock (see docs/development/web.md
#   for updating it);
# - drift_worker.js: compiled here from web/drift_worker.dart with the same
#   packages, so it always matches sqlite3.wasm (generated, not checked in).
#
# Usage: tool/build-web.sh [extra flutter build web arguments]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

# Version pinned for web/sqlite3.wasm, and its SHA-256.
SQLITE3_VERSION="3.9.1"
SQLITE3_WASM_SHA256="e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9"

fail() { echo "web: $*" >&2; exit 1; }

cd "$APP"
locked="$(awk '$0 == "  sqlite3:" {p=1; next} p && /version:/ {gsub(/"/, "", $2); print $2; exit}' pubspec.lock)"
[ "$locked" = "$SQLITE3_VERSION" ] ||
  fail "package:sqlite3 is $locked, but web/sqlite3.wasm is for $SQLITE3_VERSION (see docs/development/web.md)"
echo "$SQLITE3_WASM_SHA256  web/sqlite3.wasm" | sha256sum --check --status ||
  fail "web/sqlite3.wasm does not match the pinned checksum"

dart compile js -O4 --no-source-maps -o web/drift_worker.js web/drift_worker.dart >/dev/null
rm -f web/drift_worker.js.deps
# Everything from this server: no CanvasKit or fonts from Google's CDN
# (privacy, and cross-origin isolation, ADR-0018).
flutter build web --no-pub --no-wasm-dry-run --no-web-resources-cdn "$@" >/dev/null
echo "web: built app/build/web (sqlite3 $locked)"
