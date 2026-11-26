#!/usr/bin/env bash
# Writes and checks the CycloneDX SBOM of server bundles (ADR-0037,
# ADR-0063): <bundle>.cdx.json next to each bundle, with the web client's
# Dart packages (from the source map of its main.dart.js), PocketBase with
# the Go modules of its binary (`go version -m`) and the bundle's SHA-256.
# Needs Go, Flutter (pub deps) and network access (pub.dev, deps.dev).
#
#   tool/server-dist/sbom.sh <main.dart.js.map> <bundle.tar.gz>…
#
# Environment: BUILD (build number), COMMIT (commit), optional.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "server-sbom: $*" >&2; exit 1; }

map="${1:?usage: sbom.sh <main.dart.js.map> <bundle.tar.gz>…}"
shift
[ $# -gt 0 ] || fail "no bundle"
[ -f "$map" ] || fail "no source map at $map"
command -v go >/dev/null || fail "go is needed (go version -m)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for bundle in "$@"; do
  [ -f "$bundle" ] || fail "no bundle at $bundle"
  arch="$(basename "$bundle" .tar.gz)"
  arch="${arch##*-linux-}"
  version="$(tar -xzOf "$bundle" --wildcards '*/VERSION')"
  rm -rf "$tmp/x" && mkdir "$tmp/x"
  tar -xzf "$bundle" -C "$tmp/x" --wildcards '*/pocketbase'
  go version -m "$tmp"/x/*/pocketbase >"$tmp/buildinfo.txt"
  "$ROOT/tool/sbom.sh" generate-server --arch "$arch" --app "$ROOT/app" \
    --artifact "$bundle" --web-source-map "$map" --go-buildinfo "$tmp/buildinfo.txt" \
    --version "$version" ${BUILD:+--build "$BUILD"} ${COMMIT:+--commit "$COMMIT"}
  "$ROOT/tool/sbom.sh" check --sbom "$bundle.cdx.json" --artifact "$bundle" --version "$version"
done
