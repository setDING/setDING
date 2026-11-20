#!/usr/bin/env bash
# Runs all local checks: format, static analysis and tests – the test gate.
# Used by agents before every PR and merge (docs/development/git-workflow.md).
#
# Most tools (analyzer, test compiler, dart2js) use only one or a few cores, so
# the independent parts run in parallel: each job writes its output to its own
# log, which is printed when the job fails. CHECK_PARALLEL=0 runs the jobs one
# after another and streams their output (e.g. on a small machine).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

step() { printf '\n==> %s\n' "$*"; }

# TEST_CONCURRENCY limits parallel test processes per test run (default: the
# test runner's own default). CI sets it because containers see all host cores
# but have little memory.
concurrency=()
if [ -n "${TEST_CONCURRENCY:-}" ]; then
  concurrency=(--concurrency="$TEST_CONCURRENCY")
fi
parallel="${CHECK_PARALLEL:-1}"

# --- Jobs -------------------------------------------------------------------
# Each job runs in its own subshell with `set -e`; the first failing command
# fails the job.

# Python tools: the coverage summary of make coverage (it does not run here:
# measuring coverage slows the tests down).
job_tools() {
  cd "$ROOT/tool/coverage"
  python3 -m unittest -q test_summary
}

# A pure Dart package: format, analysis, tests.
dart_package() {
  cd "$ROOT/$1"
  dart pub get >/dev/null
  dart format --output=none --set-exit-if-changed .
  dart analyze --fatal-infos
  dart test "${concurrency[@]}"
}

job_chordpro() { dart_package packages/chordpro; }

# Server: PocketBase schema, access rules and hooks, tested against a real
# PocketBase of the pinned version (POCKETBASE_BIN, fetched below). Every test
# PocketBase listens on a free port, so the server and app tests can run at the
# same time.
job_server() { dart_package server; }

# SBOM generator of the release assets (ADR-0037).
job_sbom() { dart_package tool/sbom; }

# CHANGELOG.md: the source of the GitHub Release notes. Its format, and a
# section for the version in app/pubspec.yaml (added by the release PR).
job_changelog() {
  cd "$ROOT/tool/release"
  python3 -m unittest -q test_changelog
  ./changelog.py check --version pubspec
}

job_app_static() {
  cd "$ROOT/app"
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
}

# Unit and widget tests, and the screenshot tests in the same run (one test
# runner, so they do not compete for the test assets in build/). The screenshot
# tests drive and render the real screens; without WRITE_SCREENSHOTS
# (make screenshots) they write no files. Running them here keeps UI changes
# from breaking them silently.
job_app_tests() {
  cd "$ROOT/app"
  flutter test "${concurrency[@]}" test test_screenshots
}

# The web client is a build of the same app (ADR-0018): code that only works
# on native platforms must not break it.
job_app_web() { "$ROOT/tool/build-web.sh"; }

# Website and user documentation (ADR-0030): the build fails on broken internal
# links and on pages that do not compile.
job_website() { "$ROOT/tool/build-site.sh"; }

# --- Runner -----------------------------------------------------------------

logs="$(mktemp -d "${TMPDIR:-/tmp}/setding-check.XXXXXX")"
trap 'rm -rf "$logs"' EXIT
names=()
pids=()

# run_job NAME: runs job_NAME, in the background unless CHECK_PARALLEL=0.
run_job() {
  local name="$1"
  if [ "$parallel" = 0 ]; then
    step "$name"
    local start=$SECONDS
    ( set -e; "job_${name//-/_}" )
    printf -- '--- %s: OK (%ds)\n' "$name" $((SECONDS - start))
    return
  fi
  # The job records its own duration: the jobs end in any order.
  ( set -e; "job_${name//-/_}"; echo "$SECONDS" >"$logs/$name.end" ) >"$logs/$name.log" 2>&1 &
  names+=("$name")
  pids+=("$!")
}

# External libraries must be the newest versions (owner rule,
# docs/development/dependencies.md). First and alone: it needs the website's
# node_modules, which the website build reinstalls.
step "dependencies"
"$ROOT/tool/check-deps.sh"

step "preparing"
pb_version="$(sed -n 's/^PB_VERSION *?= *//p' "$ROOT/Makefile")"
POCKETBASE_BIN="$("$ROOT/tool/server/fetch-pocketbase.sh" "$pb_version")"
export POCKETBASE_BIN
# Before the app jobs, which all need the packages and must not fetch them at
# the same time.
(cd "$ROOT/app" && flutter pub get >/dev/null)

jobs=(chordpro server sbom changelog tools website app-static app-tests app-web)

[ "$parallel" = 0 ] || step "running in parallel: ${jobs[*]}"
start=$SECONDS
for name in "${jobs[@]}"; do run_job "$name"; done

failed=()
for i in "${!pids[@]}"; do
  name="${names[$i]}"
  if wait "${pids[$i]}"; then
    printf -- '--- %-11s OK      (%ds)\n' "$name" $(($(cat "$logs/$name.end") - start))
  else
    printf -- '--- %-11s FAILED\n' "$name"
    failed+=("$name")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  for name in "${failed[@]}"; do
    step "$name failed – output:"
    cat "$logs/$name.log"
  done
  step "Checks failed: ${failed[*]}"
  exit 1
fi

step "All checks passed (${SECONDS}s)"
