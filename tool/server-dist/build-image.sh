#!/usr/bin/env bash
# Builds the Docker image of the setDING server from server bundles
# (ADR-0063 §2b).
#
# Environment:
#   BUNDLE     the bundle (.tar.gz) to package (default: built now with
#              tool/server-dist/build-bundle.sh, which takes ARCH, WEB_DIR,
#              SERVER_VERSION and PB_VERSION)
#   BUNDLES    several bundles of one version (one per architecture) for a
#              multi-platform build; needs PLATFORMS
#   PLATFORMS  e.g. linux/amd64,linux/arm64: a multi-platform build with
#              docker buildx (no --load: set PUSH=1 to push it)
#   PUSH       1: push the image (multi-platform builds)
#   IMAGE      image name(s) with tag, separated by spaces (default:
#              setding-server:<version>)
#   DOCKER     container tool (default: docker)
#
# Without PLATFORMS the image is built for the bundle's architecture and
# loaded into the local image store (docker buildx if available, else the
# legacy builder, which only builds for this machine). Prints the first image
# name.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER="${DOCKER:-docker}"
fail() { echo "build-image: $*" >&2; exit 1; }

command -v "$DOCKER" >/dev/null || fail "$DOCKER is not installed"
if [ -n "${BUNDLES:-}" ]; then
  [ -n "${PLATFORMS:-}" ] || fail "BUNDLES needs PLATFORMS"
  read -r -a bundles <<<"$BUNDLES"
else
  bundles=("${BUNDLE:-$("$HERE/build-bundle.sh")}")
fi

ctx="$(mktemp -d)"
trap 'rm -rf "$ctx"' EXIT
version=""
arch=""
for bundle in "${bundles[@]}"; do
  [ -f "$bundle" ] || fail "no bundle at $bundle"
  arch="$(basename "$bundle" .tar.gz)"
  arch="${arch##*-linux-}"
  case "$arch" in amd64 | arm64) ;; *) fail "no architecture in the name of $bundle" ;; esac
  mkdir "$ctx/unpack"
  tar -xzf "$bundle" -C "$ctx/unpack"
  src="$(find "$ctx/unpack" -mindepth 1 -maxdepth 1 -type d -name 'setding-server-*' | head -n 1)"
  [ -n "$src" ] || fail "$bundle holds no setding-server-* directory"
  v="$(cat "$src/VERSION")"
  [ -z "$version" ] || [ "$version" = "$v" ] || fail "the bundles have different versions ($version, $v)"
  version="$v"
  mv "$src" "$ctx/setding-$arch"
  rm -rf "$ctx/unpack"
done
mkdir "$ctx/pb_data"
cp "$HERE/Dockerfile" "$ctx/Dockerfile"

read -r -a images <<<"${IMAGE:-setding-server:${version//+/_}}"
tags=()
for image in "${images[@]}"; do tags+=(-t "$image"); done

if [ -n "${PLATFORMS:-}" ]; then
  out=()
  [ "${PUSH:-0}" = 1 ] && out=(--push)
  "$DOCKER" buildx build --platform "$PLATFORMS" "${out[@]}" \
    --build-arg "VERSION=$version" "${tags[@]}" "$ctx" >&2
elif "$DOCKER" buildx version >/dev/null 2>&1; then
  "$DOCKER" buildx build --platform "linux/$arch" --load \
    --build-arg "VERSION=$version" "${tags[@]}" "$ctx" >&2
else
  "$DOCKER" build -q --build-arg "TARGETARCH=$arch" \
    --build-arg "VERSION=$version" "${tags[@]}" "$ctx" >&2
fi
echo "${images[0]}"
