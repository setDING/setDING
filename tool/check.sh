#!/usr/bin/env bash
# Runs all local checks: format, static analysis and tests.
# Used by agents before every PR and merge (docs/development/git-workflow.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

step() { printf '\n==> %s\n' "$*"; }

# TEST_CONCURRENCY limits parallel test processes (default: one per CPU core).
# CI sets it because containers see all host cores but have little memory.
concurrency=()
if [ -n "${TEST_CONCURRENCY:-}" ]; then
  concurrency=(--concurrency="$TEST_CONCURRENCY")
fi

# External libraries must be the newest versions (owner rule,
# docs/development/dependencies.md).
step "dependencies"
"$ROOT/tool/check-deps.sh"

step "packages/chordpro"
cd "$ROOT/packages/chordpro"
dart pub get >/dev/null
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test "${concurrency[@]}"

# Server: PocketBase schema, access rules and hooks, tested against a real
# PocketBase of the pinned version (PB_VERSION in the Makefile, downloaded once).
# The app's integration tests use the same binary.
step "server"
pb_version="$(sed -n 's/^PB_VERSION *?= *//p' "$ROOT/Makefile")"
POCKETBASE_BIN="$("$ROOT/tool/server/fetch-pocketbase.sh" "$pb_version")"
export POCKETBASE_BIN
cd "$ROOT/server"
dart pub get >/dev/null
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test "${concurrency[@]}"

if [ -d "$ROOT/app" ]; then
  step "app"
  cd "$ROOT/app"
  flutter pub get >/dev/null
  python3 - <<'PY'
import json, sys
keys = lambda f: {k for k in json.load(open(f)) if not k.startswith('@')}
de, en = keys('lib/l10n/app_de.arb'), keys('lib/l10n/app_en.arb')
if de != en:
    print('l10n: keys differ between app_de.arb and app_en.arb:', sorted(de ^ en))
    sys.exit(1)
if 'ß' in open('lib/l10n/app_de.arb', encoding='utf-8').read():
    print('l10n: app_de.arb must use Swiss spelling (no ß)')
    sys.exit(1)
print('l10n: OK (%d keys)' % len(de))
PY
  dart format --output=none --set-exit-if-changed lib test test_screenshots integration_test test_driver
  flutter analyze --fatal-infos
  flutter test "${concurrency[@]}"
  # The screenshot tests drive and render the real screens; without
  # WRITE_SCREENSHOTS (make screenshots) they write no files. Running them
  # here keeps UI changes from breaking them silently.
  step "app (screenshots)"
  flutter test test_screenshots
  # The web client is a build of the same app (ADR-0018): code that only
  # works on native platforms must not break it.
  step "app (web build)"
  "$ROOT/tool/build-web.sh"
fi

step "All checks passed"
