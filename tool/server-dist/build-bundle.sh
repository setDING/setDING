#!/usr/bin/env bash
# Builds the server bundle of a release (ADR-0063 §1):
#
#   setding-server-<version>-linux-<arch>.tar.gz
#     setding-server-<version>/
#       pocketbase        the pinned PocketBase (PB_VERSION, checksum verified)
#       pb_hooks/         server/pb_hooks, stamped with the version
#       pb_migrations/    server/pb_migrations
#       pb_public/        the web client (ADR-0018)
#       VERSION
#       LICENSES/         setDING and PocketBase
#
# and (re)writes SHA256SUMS for all bundles in the output directory. The bundle
# runs as it is: `./pocketbase serve --http=127.0.0.1:8090` finds its hooks,
# migrations and web client next to itself and creates pb_data/ there.
#
# Environment:
#   ARCH            amd64 or arm64 (default: this machine)
#   OUT             output directory (default: build/server-dist)
#   WEB_DIR         an existing web build to bundle (default: built with
#                   tool/build-web.sh into app/build/web)
#   SERVER_VERSION  version (default: tool/release/version-stamp.sh)
#   SRC             checkout whose server/, LICENSE and version are bundled
#                   (default: this repository), e.g. an older release for
#                   the upgrade test (tool/server-dist/previous-bundle.sh)
#   PB_VERSION      PocketBase version (default: PB_VERSION in the Makefile)
#
# Prints the path of the bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "build-bundle: $*" >&2; exit 1; }

if [ -z "${ARCH:-}" ]; then
  case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) fail "unsupported architecture: $(uname -m); set ARCH" ;;
  esac
fi
case "$ARCH" in
  amd64 | arm64) ;;
  *) fail "ARCH must be amd64 or arm64, not $ARCH" ;;
esac

SRC="${SRC:-$ROOT}"
OUT="${OUT:-$ROOT/build/server-dist}"
# Absolute, so the printed path works from any directory (#1064).
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
PB_VERSION="${PB_VERSION:-$(sed -n 's/^PB_VERSION *?= *//p' "$ROOT/Makefile")}"
[ -n "$PB_VERSION" ] || fail "no PB_VERSION"
version="${SERVER_VERSION:-$("$ROOT/tool/release/version-stamp.sh" "$SRC")}"

if [ -z "${WEB_DIR:-}" ]; then
  if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
    export PATH="$HOME/development/flutter/bin:$PATH"
  fi
  (cd "$ROOT/app" && flutter pub get >/dev/null)
  "$ROOT/tool/build-web.sh" >&2
  WEB_DIR="$ROOT/app/build/web"
fi
[ -f "$WEB_DIR/index.html" ] || fail "no web build in $WEB_DIR (index.html missing)"

pb="$("$ROOT/tool/server/fetch-pocketbase.sh" "$PB_VERSION" "linux_$ARCH")"

name="setding-server-$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
dir="$tmp/$name"
mkdir -p "$dir/LICENSES"

install -m 755 "$pb" "$dir/pocketbase"
cp -r "$SRC/server/pb_hooks" "$SRC/server/pb_migrations" "$dir/"
# Local stamps and placeholders are not part of a bundle.
rm -f "$dir/pb_hooks/setding-version.txt" "$dir/pb_hooks/.gitkeep" "$dir/pb_migrations/.gitkeep"
echo "$version" >"$dir/pb_hooks/setding-version.txt"
cp -r "$WEB_DIR" "$dir/pb_public"
echo "$version" >"$dir/VERSION"
cp "$SRC/LICENSE" "$dir/LICENSES/setDING.txt"
cp "$(dirname "$pb")/LICENSE.md" "$dir/LICENSES/PocketBase.md"
# Readable for every user (the image runs the server as another user than
# the files' owner), writable only for the owner, whatever the sources had.
chmod -R u+rwX,go+rX,go-w "$dir"

mkdir -p "$OUT"
archive="$OUT/$name-linux-$ARCH.tar.gz"
# Reproducible: sorted, no owners, the commit time as file time.
mtime="$(git -C "$SRC" log -1 --format=%ct 2>/dev/null || date +%s)"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$mtime" \
  -C "$tmp" -cf - "$name" | gzip -n >"$archive.part"
mv "$archive.part" "$archive"

(cd "$OUT" && sha256sum setding-server-*.tar.gz >SHA256SUMS)
echo "$archive"
