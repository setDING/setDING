#!/usr/bin/env bash
# Runs the local checks: format, static analysis and tests – the test gate.
# Used by agents before every PR and merge (docs/development/git-workflow.md).
#
# By default only the jobs whose area the branch touches run: the changed
# files against origin/main (committed, uncommitted and untracked) are mapped
# to jobs by tool/check_select.py, which runs every job for shared files,
# unknown files and larger changes. CHECK_FULL=1 (make check-full) always runs
# every job; CHECK_BASE=<ref> compares against another ref (issue #684).
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

# TEST_REPORT_DIR=<dir> also writes each test run's results as JSON to
# <dir>/<job>.json (the nightly CI summary, tool/ci/test_report.py, #1249).
# report NAME prints the flag for job NAME, or nothing.
report() {
  if [ -n "${TEST_REPORT_DIR:-}" ]; then
    mkdir -p "$TEST_REPORT_DIR"
    printf '%s\n' "--file-reporter=json:$TEST_REPORT_DIR/$1.json"
  fi
}

# --- Jobs -------------------------------------------------------------------
# Each job runs in its own subshell with `set -e`; the first failing command
# fails the job.

# Python tools: the coverage summary of make coverage (it does not run here:
# measuring coverage slows the tests down).
# And the job selection of this script (tool/check_select.py) and the
# parallel-upgrade check of make upgrade (tool/upgrade_guard.py).
job_tools() {
  cd "$ROOT/tool/coverage"
  python3 -m unittest -q test_summary
  cd "$ROOT/tool"
  python3 -m unittest -q test_check_select
  python3 -m unittest -q test_upgrade_guard
  # Which server the make server-* targets work on (#1055).
  python3 -m unittest -q test_server_targets
  # The systemd check of check-ops.sh ignores other units' problems (#1254).
  python3 -m unittest -q test_systemd_verify_filter
  # The test summary of the nightly CI run (#1249).
  cd "$ROOT/tool/ci"
  python3 -m unittest -q test_test_report
  cd "$ROOT/tool/server-dist"
  python3 -m unittest -q test_doc_example
  python3 -m unittest -q test_previous_bundle
}

# A pure Dart package: format, analysis, tests.
dart_package() {
  cd "$ROOT/$1"
  dart pub get >/dev/null
  dart format --output=none --set-exit-if-changed .
  dart analyze --fatal-infos
  local flags=()
  mapfile -t flags < <(report "$(basename "$1")")
  dart test "${concurrency[@]}" "${flags[@]}"
}

job_chordpro() { dart_package packages/chordpro; }

# Server: PocketBase schema, access rules and hooks, tested against a real
# PocketBase of the pinned version (POCKETBASE_BIN, fetched below). Every test
# PocketBase listens on a free port, so the server and app tests can run at the
# same time.
job_server() { dart_package server; }

# Operations files (issue #644): ShellCheck on all shell scripts, the
# Caddyfile and the systemd units. Their behaviour (backup restore, website
# server) is tested in the server job.
job_ops() { "$ROOT/tool/check-ops.sh"; }

# SBOM generator of the release assets (ADR-0037).
job_sbom() { dart_package tool/sbom; }

# CHANGELOG.md: the source of the GitHub Release notes. Its format, and a
# section for the version in app/pubspec.yaml (added by the release PR).
job_changelog() {
  cd "$ROOT/tool/release"
  python3 -m unittest -q test_changelog
  # Google Play release notes from whats_new.json (ADR-0067).
  python3 -m unittest -q test_play_notes
  # The tag make server-release deploys: no pre-release on production (ADR-0069).
  python3 -m unittest -q test_release_tag
  ./changelog.py check --version pubspec
}

job_app_static() {
  cd "$ROOT/app"
  python3 - <<'PY'
import json, sys
keys = lambda f: {k for k in json.load(open(f)) if not k.startswith('@')}
import glob
de = keys('lib/l10n/app_de.arb')
for f in sorted(glob.glob('lib/l10n/app_*.arb')):
    if keys(f) != de:
        print('l10n: keys differ between app_de.arb and', f, sorted(de ^ keys(f)))
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
# tests drive, lay out and paint the real screens; without WRITE_SCREENSHOTS
# (make screenshots) they neither rasterise nor write the images. Running them here keeps UI changes
# from breaking them silently.
job_app_tests() {
  cd "$ROOT/app"
  local flags=()
  mapfile -t flags < <(report app)
  flutter test "${concurrency[@]}" "${flags[@]}" test test_screenshots
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

# --- Job selection ----------------------------------------------------------

all_jobs=(chordpro server ops sbom changelog tools website app-static app-tests app-web)

# changed_files: the files the branch changes against the merge base with
# CHECK_BASE (default origin/main), including uncommitted and untracked ones.
# Prints nothing when there is no base or no change; the selection then runs
# every job.
changed_files() {
  local base
  base="$(git -C "$ROOT" merge-base HEAD "${CHECK_BASE:-origin/main}" 2>/dev/null)" || return 0
  {
    git -C "$ROOT" diff --name-only "$base"
    git -C "$ROOT" ls-files --others --exclude-standard
  } | sort -u
}

if [ "${CHECK_FULL:-0}" = 1 ]; then
  # The image smoke test (server/test/image_test.dart) must not be skipped.
  export SETDING_REQUIRE_DOCKER=1
  jobs=("${all_jobs[@]}")
  deps_mode=strict
  echo "full check (CHECK_FULL=1)"
else
  selection="$(changed_files | python3 "$ROOT/tool/check_select.py")"
  read -r -a jobs <<<"$(sed -n 's/^jobs: *//p' <<<"$selection")"
  deps_mode="$(sed -n 's/^deps: *//p' <<<"$selection")"
  if [ ${#jobs[@]} -lt ${#all_jobs[@]} ]; then
    skipped=()
    for name in "${all_jobs[@]}"; do
      [[ " ${jobs[*]} " == *" $name "* ]] || skipped+=("$name")
    done
    echo "affected jobs only (make check-full runs all); skipped: ${skipped[*]}"
  fi
fi

# External libraries must be the newest versions (owner rule,
# docs/development/dependencies.md). First and alone: it needs the website's
# node_modules, which the website build reinstalls. It fails the full check
# and changes to pinned libraries; otherwise a new upstream release only
# warns, so it does not block unrelated changes (#684).
step "dependencies"
if [ "$deps_mode" = strict ]; then
  "$ROOT/tool/check-deps.sh"
elif ! "$ROOT/tool/check-deps.sh"; then
  echo "WARNING: outdated libraries (not fatal for this change; make upgrade in its own PR, make check-full fails)"
fi

if [ ${#jobs[@]} -eq 0 ]; then
  step "No job is affected by this change (make check-full runs all)"
  exit 0
fi

step "preparing"
pb_version="$(sed -n 's/^PB_VERSION *?= *//p' "$ROOT/Makefile")"
POCKETBASE_BIN="$("$ROOT/tool/server/fetch-pocketbase.sh" "$pb_version")"
export POCKETBASE_BIN
# Check tools (tool/fetch-tool.sh), fetched once before the jobs that use them.
CADDY_BIN="$("$ROOT/tool/fetch-tool.sh" caddy)"
export CADDY_BIN
"$ROOT/tool/fetch-tool.sh" shellcheck >/dev/null
# Before the app jobs, which all need the packages and must not fetch them at
# the same time.
(cd "$ROOT/app" && flutter pub get >/dev/null)

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
