#!/usr/bin/env bash
# Validates CycloneDX SBOMs against the specification with the official
# cyclonedx-cli (ADR-0037), in its newest release (owner rule), downloaded once
# per version into ~/.cache/setding (Linux x64).
#
#   tool/sbom/validate.sh <file>.cdx.json…
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: validate.sh <file>.cdx.json…" >&2; exit 64; }

base=https://github.com/CycloneDX/cyclonedx-cli/releases
asset=cyclonedx-linux-x64
# The latest/download redirect names the newest version.
version="$(curl -fsSI "$base/latest/download/$asset" |
  sed -n 's#^[Ll]ocation: .*/download/\(v[^/]*\)/.*#\1#p' | tr -d '\r')"
[ -n "$version" ] || { echo "validate.sh: could not find the newest cyclonedx-cli" >&2; exit 1; }

cache="${XDG_CACHE_HOME:-$HOME/.cache}/setding/cyclonedx-cli/$version"
cli="$cache/$asset"
if [ ! -x "$cli" ]; then
  mkdir -p "$cache"
  curl -fsSL -o "$cli.tmp" "$base/download/$version/$asset"
  chmod +x "$cli.tmp"
  mv "$cli.tmp" "$cli"
fi

for sbom in "$@"; do
  echo "validate: $sbom (cyclonedx-cli $version)"
  "$cli" validate --input-file "$sbom" --input-format json --input-version v1_6 --fail-on-errors
done
