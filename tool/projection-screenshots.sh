#!/usr/bin/env bash
# Renders the projected page of the lyrics projection (ADR-0068) into
# docs/screenshots with a headless Chromium: the page runs in a browser, so
# it is not part of the Flutter screenshot tests (make screenshots).
# CHROMIUM=<path> picks the browser; chromium or google-chrome by default.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROMIUM="${CHROMIUM:-$(command -v chromium || command -v google-chrome || true)}"
if [ -z "$CHROMIUM" ]; then
  echo "projection-screenshots: no chromium or google-chrome found (set CHROMIUM)" >&2
  exit 1
fi
cd "$ROOT/app"
flutter pub get >/dev/null
dart --packages=.dart_tool/package_config.json tool/projection_screenshots.dart \
  "$ROOT/app" "$ROOT/docs/screenshots" "$CHROMIUM"
