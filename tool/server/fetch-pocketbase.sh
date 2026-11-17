#!/usr/bin/env bash
# Downloads the pinned PocketBase binary for the local machine into a cache and
# prints its path. Used by the server tests (tool/check.sh) and `make backend`.
#
#   fetch-pocketbase.sh <pocketbase-version>     e.g. fetch-pocketbase.sh 0.40.6
#
# The cache is ${SETDING_CACHE:-${XDG_CACHE_HOME:-~/.cache}/setding}; the
# download is verified against the release's checksums.txt.
set -euo pipefail

PB_VERSION="${1:?usage: fetch-pocketbase.sh <pocketbase-version>}"
PB_VERSION="${PB_VERSION#v}"

cache="${SETDING_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/setding}/pocketbase/$PB_VERSION"
bin="$cache/pocketbase"

if [ -x "$bin" ]; then
  echo "$bin"
  exit 0
fi

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

zip="pocketbase_${PB_VERSION}_${os}_${arch}.zip"
base="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/$zip" "$base/$zip"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"
(cd "$tmp" && grep " $zip\$" checksums.txt | sha256sum -c - >/dev/null)
unzip -q -o "$tmp/$zip" pocketbase -d "$tmp"
mkdir -p "$cache"
install -m 755 "$tmp/pocketbase" "$bin"
echo "$bin"
