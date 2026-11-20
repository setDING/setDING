#!/usr/bin/env bash
# Runs the web integration tests (make web-test, issue #650,
# docs/development/web-tests.md): app/integration_test/web/*_test.dart in
# headless Chrome.
#
#   make web-test
#   make web-test TESTS=integration_test/web/web_test.dart
#   make web-test WEB_TEST_WINDOW=1      show the browser window
#
# Each test is built as the web client (tool/build-web.sh, profile mode) into
# app/build/web-itest and served by a local PocketBase with the repository's
# schema and hooks (server/bin/itest_backend.dart), like in production: same
# origin as the API, with the isolation headers (ADR-0018). chromedriver opens
# it in Chrome and test_driver/web_driver.dart waits for the result.
#
# Needs Chrome or Chromium and a chromedriver of the same major version
# (CHROME_BINARY, CHROMEDRIVER override them).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
OUT="$ROOT/app/build/web-itest"

log() { printf 'web-test: %s\n' "$*"; }
die() { printf 'web-test: %s\n' "$*" >&2; exit 1; }

cleanup_steps=()
cleanup() {
  local i
  for ((i = ${#cleanup_steps[@]} - 1; i >= 0; i--)); do eval "${cleanup_steps[$i]}" || true; done
}
trap cleanup EXIT

# --- Browser ----------------------------------------------------------------

CHROMEDRIVER="${CHROMEDRIVER:-$(command -v chromedriver || true)}"
[ -n "$CHROMEDRIVER" ] || die "chromedriver not found (install it or set CHROMEDRIVER)"
if [ -z "${CHROME_BINARY:-}" ]; then
  for browser in chromium google-chrome-stable google-chrome chrome; do
    CHROME_BINARY="$(command -v "$browser" || true)"
    [ -n "$CHROME_BINARY" ] && break
  done
fi
[ -n "${CHROME_BINARY:-}" ] || die "Chrome or Chromium not found (set CHROME_BINARY)"
export CHROME_BINARY
major() { "$1" --version | grep -oE '[0-9]+\.[0-9.]+' | head -1 | cut -d. -f1; }
[ "$(major "$CHROME_BINARY")" = "$(major "$CHROMEDRIVER")" ] ||
  die "$CHROME_BINARY $(major "$CHROME_BINARY") and $CHROMEDRIVER $(major "$CHROMEDRIVER") differ (set CHROME_BINARY or CHROMEDRIVER)"

# --- Backend ----------------------------------------------------------------

# PocketBase serves the directory as it is when a file is requested: the
# test builds go into it after the start.
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT/server"
dart pub get >/dev/null
backend_out="$(mktemp)"
backend_info="$(mktemp)"
cleanup_steps+=("rm -f '$backend_out' '$backend_info'")
log "starting local PocketBase"
dart run bin/itest_backend.dart --public-dir "$OUT" >"$backend_out" &
backend_pid=$!
cleanup_steps+=("kill -TERM $backend_pid 2>/dev/null; wait $backend_pid 2>/dev/null")
for _ in $(seq 600); do
  grep -m1 '^{' "$backend_out" >"$backend_info" && break
  kill -0 "$backend_pid" 2>/dev/null || die "the local PocketBase did not start"
  sleep 0.1
done
[ -s "$backend_info" ] || die "the local PocketBase did not start within 60s"
port="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["port"])' "$backend_info")"
defines=()
while IFS= read -r define; do defines+=("--dart-define=$define"); done < <(
  python3 -c '
import json, sys
info = json.load(open(sys.argv[1]))
for key in ("email", "password", "song", "sheet"):
    print("SETDING_ITEST_%s=%s" % (key.upper(), info[key]))
' "$backend_info"
)

# --- chromedriver -----------------------------------------------------------

driver_port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
"$CHROMEDRIVER" --port="$driver_port" --log-level=SEVERE >/dev/null 2>&1 &
driver_pid=$!
cleanup_steps+=("kill $driver_pid 2>/dev/null; wait $driver_pid 2>/dev/null")
for _ in $(seq 100); do
  curl -sf "http://127.0.0.1:$driver_port/status" >/dev/null && break
  sleep 0.1
done
curl -sf "http://127.0.0.1:$driver_port/status" >/dev/null || die "chromedriver did not start"

# --- Tests ------------------------------------------------------------------

cd "$ROOT/app"
if [ -n "${TESTS:-}" ]; then
  read -r -a tests <<<"$TESTS"
else
  tests=(integration_test/web/*_test.dart)
fi
failed=()
for test in "${tests[@]}"; do
  log "building $test"
  WEB_OUT="$OUT" "$ROOT/tool/build-web.sh" --profile --target "$test" "${defines[@]}"
  log "running $test in $("$CHROME_BINARY" --version)"
  dart test_driver/web_driver.dart "http://127.0.0.1:$driver_port/" "http://127.0.0.1:$port/" ||
    failed+=("$test")
done
if [ "${#failed[@]}" -gt 0 ]; then
  die "failed: ${failed[*]}"
fi
log "all web integration tests passed"
