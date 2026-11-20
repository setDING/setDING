#!/usr/bin/env bash
# Runs the web integration tests (make web-test, issues #650 and #652,
# docs/development/web-tests.md): app/integration_test/web/*_test.dart in a
# headless browser.
#
#   make web-test                         headless Chrome or Chromium
#   make web-test BROWSER=firefox         headless Firefox (geckodriver)
#   make web-test TESTS=integration_test/web/web_test.dart
#   make web-test WEB_TEST_WINDOW=1       show the browser window
#
# Each test is built as the web client (tool/build-web.sh, profile mode) and
# served by a local PocketBase with the repository's schema and hooks
# (server/bin/itest_backend.dart), like in production: same origin as the
# API, with the isolation headers (ADR-0018). A test whose first line is
# `// web-test: no-isolation` is served by a plain static server on another
# port instead (no isolation headers, the API cross-origin). The browser's
# WebDriver opens it and test_driver/web_driver.dart waits for the result.
#
# Chrome needs a chromedriver of the same major version (CHROMEDRIVER);
# Firefox uses geckodriver (GECKODRIVER, else the one on the PATH, else the
# pinned one of tool/fetch-tool.sh). BROWSER_BINARY selects the browser.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
OUT="$ROOT/app/build/web-itest"
PLAIN_OUT="$ROOT/app/build/web-itest-plain"
BROWSER="${BROWSER:-chrome}"
export BROWSER

log() { printf 'web-test: %s\n' "$*"; }
die() { printf 'web-test: %s\n' "$*" >&2; exit 1; }

cleanup_steps=()
cleanup() {
  local i
  for ((i = ${#cleanup_steps[@]} - 1; i >= 0; i--)); do eval "${cleanup_steps[$i]}" || true; done
}
trap cleanup EXIT

free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

# Waits until a server answers on the URL.
wait_for() {
  local _
  for _ in $(seq 150); do
    curl -s -o /dev/null "$1" && return 0
    sleep 0.1
  done
  die "$2 did not start"
}

# --- Browser and WebDriver --------------------------------------------------

# shellcheck source=tool/webdriver.sh
. "$ROOT/tool/webdriver.sh"

# --- Servers ----------------------------------------------------------------

# Both serve their directory as it is when a file is requested: the test
# builds go into it after the start.
rm -rf "$OUT" "$PLAIN_OUT"
mkdir -p "$OUT" "$PLAIN_OUT"
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

# Plain static server without the isolation headers.
plain_port="$(free_port)"
python3 -m http.server "$plain_port" --bind 127.0.0.1 --directory "$PLAIN_OUT" >/dev/null 2>&1 &
plain_pid=$!
cleanup_steps+=("kill $plain_pid 2>/dev/null; wait $plain_pid 2>/dev/null")
wait_for "http://127.0.0.1:$plain_port/" "the static server"

# --- Tests ------------------------------------------------------------------

cd "$ROOT/app"
if [ -n "${TESTS:-}" ]; then
  read -r -a tests <<<"$TESTS"
else
  tests=(integration_test/web/*_test.dart)
fi
browser_version="$("$BROWSER_BINARY" --version 2>/dev/null | head -1)"
failed=()
for test in "${tests[@]}"; do
  if head -1 "$test" | grep -qx '// web-test: no-isolation'; then
    out="$PLAIN_OUT" url="http://127.0.0.1:$plain_port/"
    extra=("--dart-define=SETDING_SERVER_URL=http://127.0.0.1:$port")
  else
    out="$OUT" url="http://127.0.0.1:$port/" extra=()
  fi
  log "building $test"
  WEB_OUT="$out" "$ROOT/tool/build-web.sh" --profile --target "$test" "${defines[@]}" "${extra[@]}"
  log "running $test in $browser_version"
  dart test_driver/web_driver.dart "http://127.0.0.1:$driver_port/" "$url" ||
    failed+=("$test")
done
if [ "${#failed[@]}" -gt 0 ]; then
  die "failed: ${failed[*]}"
fi
log "all web integration tests passed in $browser_version"
