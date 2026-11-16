#!/usr/bin/env bash
# Builds the Linux release inside the release container (make release-linux,
# ADR-0019), with tool/release mounted at /release. Expects the committed sources
# as a tar archive on stdin and writes the packed bundle to /out/<name>.tar.gz.
# BUILD_NUMBER (optional, set by CI) overrides the build number of pubspec.yaml.
#
#   git archive HEAD | docker run -i ... build-linux.sh <name>
set -euo pipefail

name="${1:?usage: build-linux.sh <name>}"
src=/tmp/realchord

mkdir -p "$src"
tar -C "$src" -xf -

cd "$src/app"
flutter config --no-analytics >/dev/null
flutter pub get
build_args=()
if [ -n "${BUILD_NUMBER:-}" ]; then
  build_args+=(--build-number "$BUILD_NUMBER")
fi
flutter build linux --release "${build_args[@]}"

bundle="$src/app/build/linux/x64/release/bundle"
/release/check-isa.sh "$bundle"

staging="$(mktemp -d)"
cp -a "$bundle" "$staging/$name"
tar -C "$staging" -czf "/out/$name.tar.gz" "$name"
chown "${HOST_UID:-0}:${HOST_GID:-0}" "/out/$name.tar.gz"
