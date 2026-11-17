#!/usr/bin/env bash
# Builds the website and user documentation (website/, ADR-0030) into
# website/dist. Installs the locked npm packages first; the build fails on
# broken internal links (starlight-links-validator).
#
#   build-site.sh [checkout]     (default: the repository root)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT}"

command -v npm >/dev/null || { echo "build-site: Node.js with npm is required (docs/development/website.md)" >&2; exit 1; }
cd "$SRC/website"
npm ci --no-audit --no-fund --loglevel=error
ASTRO_TELEMETRY_DISABLED=1 npx --no-install astro build
