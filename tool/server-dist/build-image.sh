#!/usr/bin/env bash
# Builds the Docker image of the setDING server from a server bundle
# (ADR-0063 §2b) for the architecture of the bundle.
#
# Environment:
#   BUNDLE   the bundle (.tar.gz) to package (default: built now with
#            tool/server-dist/build-bundle.sh, which takes ARCH, WEB_DIR,
#            SERVER_VERSION and PB_VERSION)
#   IMAGE    image name and tag (default: setding-server:<version>)
#   DOCKER   container tool (default: docker)
#
# Prints the image name.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER="${DOCKER:-docker}"
fail() { echo "build-image: $*" >&2; exit 1; }

command -v "$DOCKER" >/dev/null || fail "$DOCKER is not installed"
BUNDLE="${BUNDLE:-$("$HERE/build-bundle.sh")}"
[ -f "$BUNDLE" ] || fail "no bundle at $BUNDLE"

ctx="$(mktemp -d)"
trap 'rm -rf "$ctx"' EXIT
tar -xzf "$BUNDLE" -C "$ctx"
src="$(find "$ctx" -mindepth 1 -maxdepth 1 -type d -name 'setding-server-*' | head -n 1)"
[ -n "$src" ] || fail "$BUNDLE holds no setding-server-* directory"
mv "$src" "$ctx/setding"
mkdir "$ctx/pb_data"
cp "$HERE/Dockerfile" "$ctx/Dockerfile"
version="$(cat "$ctx/setding/VERSION")"
IMAGE="${IMAGE:-setding-server:${version//+/_}}"

"$DOCKER" build -q --build-arg "VERSION=$version" -t "$IMAGE" "$ctx" >&2
echo "$IMAGE"
