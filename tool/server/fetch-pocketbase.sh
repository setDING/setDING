#!/usr/bin/env bash
# Downloads the pinned PocketBase binary into a cache and prints its path; its
# licence is cached next to it as LICENSE.md. Used by the server tests
# (tool/check.sh), `make backend` and the server bundle
# (tool/server-dist/build-bundle.sh).
#
#   fetch-pocketbase.sh <pocketbase-version> [<os>_<arch>]
#       e.g. fetch-pocketbase.sh 0.40.6              (this machine)
#            fetch-pocketbase.sh 0.40.6 linux_arm64  (another platform)
#
# The cache is ${SETDING_CACHE:-${XDG_CACHE_HOME:-~/.cache}/setding}; the
# download is verified against the release's checksums.txt.
set -euo pipefail

PB_VERSION="${1:?usage: fetch-pocketbase.sh <pocketbase-version>}"
PB_VERSION="${PB_VERSION#v}"
PLATFORM="${2:-}"

cache="${SETDING_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/setding}/pocketbase/$PB_VERSION"
if [ -n "$PLATFORM" ]; then
  case "$PLATFORM" in
    linux_amd64 | linux_arm64 | darwin_amd64 | darwin_arm64) ;;
    *) echo "unsupported platform: $PLATFORM" >&2; exit 1 ;;
  esac
  os="${PLATFORM%_*}"
  arch="${PLATFORM#*_}"
  cache="$cache/$PLATFORM"
fi
bin="$cache/pocketbase"

if [ -x "$bin" ] && [ -f "$cache/LICENSE.md" ]; then
  echo "$bin"
  exit 0
fi

if [ -z "$PLATFORM" ]; then
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
fi

zip="pocketbase_${PB_VERSION}_${os}_${arch}.zip"
# PocketBase releases live on ganigeorgiev.com since v0.41 (GitHub is archived at
# v0.40.6). This documented URL redirects to the release file.
base="https://ganigeorgiev.com/meta/pocketbase/pocketbase/download/v${PB_VERSION}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/$zip" "$base/$zip"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"
(cd "$tmp" && grep " $zip\$" checksums.txt | sha256sum -c - >/dev/null)
unzip -q -o "$tmp/$zip" pocketbase LICENSE.md -d "$tmp"
mkdir -p "$cache"
install -m 644 "$tmp/LICENSE.md" "$cache/LICENSE.md"
install -m 755 "$tmp/pocketbase" "$bin"
echo "$bin"
