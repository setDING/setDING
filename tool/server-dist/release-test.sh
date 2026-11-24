#!/usr/bin/env bash
# Builds the server release artifacts and tests exactly those (ADR-0063 §6):
# for every architecture the bundle, the image built from it, and the update
# from the previous release's bundle and image. Used by `make release-gate`
# and the release workflow (.github/workflows/release.yml), which publishes
# the bundles and the image only when this passes.
#
# Per architecture:
#   1. bundle   tool/server-dist/build-bundle.sh
#   2. image    tool/server-dist/build-image.sh (from that bundle)
#   3. previous the previous release's bundle (tool/server-dist/previous-bundle.sh)
#               and image (pulled from ghcr.io, else built from that bundle)
#   4. tests    server/test/bundle_test.dart, image_test.dart and
#               upgrade_test.dart against these artifacts
#
# Environment:
#   ARCHS           architectures (default: this machine's). Another one needs
#                   QEMU (binfmt) to run its binary, and docker buildx for its
#                   image.
#   OUT             output directory (default: build/server-dist)
#   WEB_DIR         a web build to bundle (default: built once now)
#   SERVER_VERSION  version (default: tool/release/version-stamp.sh)
#
# Prints the paths of the bundles.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tool/server-dist"
OUT="${OUT:-$ROOT/build/server-dist}"
step() { printf '\n==> %s\n' "$*" >&2; }
fail() { echo "release-test: $*" >&2; exit 1; }

case "$(uname -m)" in
  x86_64 | amd64) host=amd64 ;;
  aarch64 | arm64) host=arm64 ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
esac
read -r -a archs <<<"${ARCHS:-$host}"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
if ! command -v docker >/dev/null || ! docker info >/dev/null 2>&1; then
  fail "Docker is needed to test the image"
fi

if [ -z "${WEB_DIR:-}" ]; then
  step "Web client"
  (cd "$ROOT/app" && flutter pub get >/dev/null)
  "$ROOT/tool/build-web.sh" >&2
  WEB_DIR="$ROOT/app/build/web"
fi
export WEB_DIR

(cd "$ROOT/server" && dart pub get >/dev/null)
# Absolute: the tests run in server/ (#1064).
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
rm -f "$OUT"/setding-server-*.tar.gz "$OUT/SHA256SUMS"
bundles=()
images=()
cleanup() {
  local image
  for image in "${images[@]}"; do docker image rm -f "$image" >/dev/null 2>&1 || true; done
}
trap cleanup EXIT

for arch in "${archs[@]}"; do
  if [ "$arch" != "$host" ]; then
    binfmt=/proc/sys/fs/binfmt_misc/qemu-$([ "$arch" = arm64 ] && echo aarch64 || echo x86_64)
    [ -e "$binfmt" ] || fail "$arch binaries cannot run here (no QEMU binfmt: $binfmt)"
    docker buildx version >/dev/null 2>&1 || fail "an $arch image needs docker buildx"
  fi

  step "Bundle ($arch)"
  bundle="$(ARCH="$arch" OUT="$OUT" "$HERE/build-bundle.sh")"
  bundles+=("$bundle")
  version="$(tar -xzOf "$bundle" --wildcards '*/VERSION')"

  step "Image ($arch)"
  image="setding-server-release-test:${version//+/_}-$arch"
  images+=("$image")
  BUNDLE="$bundle" IMAGE="$image" "$HERE/build-image.sh" >/dev/null

  step "Previous release ($arch)"
  previous="$(ARCH="$arch" "$HERE/previous-bundle.sh")"
  previous_version="$(tar -xzOf "$previous" --wildcards '*/VERSION')"
  previous_image="ghcr.io/tafli/setding-server:$previous_version"
  if docker pull -q --platform "linux/$arch" "$previous_image" >/dev/null 2>&1; then
    echo "pulled $previous_image" >&2
  else
    previous_image="setding-server-release-test:$previous_version-$arch"
    echo "no published image of $previous_version; building one from its bundle" >&2
    BUNDLE="$previous" IMAGE="$previous_image" "$HERE/build-image.sh" >/dev/null
  fi
  images+=("$previous_image")

  step "Tests ($arch: $version, update from $previous_version)"
  (cd "$ROOT/server" &&
    SETDING_REQUIRE_DOCKER=1 \
      SETDING_TEST_BUNDLE="$bundle" \
      SETDING_TEST_IMAGE="$image" \
      SETDING_TEST_PREVIOUS_BUNDLE="$previous" \
      SETDING_TEST_PREVIOUS_IMAGE="$previous_image" \
      dart test --concurrency=1 test/bundle_test.dart test/image_test.dart test/upgrade_test.dart >&2)
done

printf '%s\n' "${bundles[@]}"
