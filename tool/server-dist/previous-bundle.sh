#!/usr/bin/env bash
# Prints the path of the previous release's server bundle, for the upgrade
# test (server/test/upgrade_test.dart, ADR-0063 §6).
#
# The previous release is the newest final release tag (vX.Y.Z, no suffix)
# that does not contain HEAD, so on a release tag it is the one before. Its published bundle is downloaded
# from the GitHub Release (with gh); releases from before the bundles existed
# (or without gh access) get one built from the tag's source with this
# repository's build script and a stub web client, which is enough for the
# data: hooks and migrations are the tag's.
#
# Environment:
#   PREVIOUS  the tag to use instead (e.g. v0.20.0)
#   ARCH      amd64 or arm64 (default: this machine)
#   PREVIOUS_OUT  output directory (default: build/server-dist/previous); its
#             own name, so a caller's OUT (the release's bundles) is never
#             used for it (#1073)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "previous-bundle: $*" >&2; exit 1; }

if [ -z "${ARCH:-}" ]; then
  case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) fail "unsupported architecture: $(uname -m); set ARCH" ;;
  esac
fi
OUT="${PREVIOUS_OUT:-$ROOT/build/server-dist/previous}"
# Absolute, so the printed path works from any directory (#1064).
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

tag="${PREVIOUS:-}"
if [ -z "$tag" ]; then
  git -C "$ROOT" fetch -q --tags origin 2>/dev/null || true
  # Tags at HEAD (the release being built) or after it do not count.
  tag="$(git -C "$ROOT" tag --list 'v*' --no-contains HEAD --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
fi
[ -n "$tag" ] || fail "no release before HEAD"
version="${tag#v}"
mkdir -p "$OUT"
asset="setding-server-$version-linux-$ARCH.tar.gz"

if [ -f "$OUT/$asset" ]; then
  echo "$OUT/$asset"
  exit 0
fi

if command -v gh >/dev/null &&
  gh release download "$tag" --repo tafli/setDING --pattern "$asset" --dir "$OUT" >/dev/null 2>&1; then
  echo "previous-bundle: downloaded $asset from the GitHub Release $tag" >&2
  echo "$OUT/$asset"
  exit 0
fi

echo "previous-bundle: $tag has no published bundle; building one from its source" >&2
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/src" "$tmp/web"
git -C "$ROOT" archive "$tag" server/pb_hooks server/pb_migrations LICENSE | tar -x -C "$tmp/src"
echo "<!doctype html><html><body>setDING $version</body></html>" >"$tmp/web/index.html"
SRC="$tmp/src" WEB_DIR="$tmp/web" SERVER_VERSION="$version" ARCH="$ARCH" OUT="$OUT" \
  "$ROOT/tool/server-dist/build-bundle.sh" >/dev/null
echo "$OUT/$asset"
