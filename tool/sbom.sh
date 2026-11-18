#!/usr/bin/env bash
# Runs the SBOM tool (ADR-0037, tool/sbom):
#   tool/sbom.sh generate --platform <p> --app app --artifact <file> --instruction-sizes <file> …
#   tool/sbom.sh check --sbom <file>.cdx.json --artifact <file> --version X.Y.Z
# See docs/development/releases.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v dart >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/dart" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

(cd "$ROOT/tool/sbom" && dart pub get >/dev/null)
exec dart run "$ROOT/tool/sbom/bin/sbom.dart" "$@"
