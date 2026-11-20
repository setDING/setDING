#!/usr/bin/env bash
# Runs the end-to-end tests (make e2e, issue #692,
# docs/development/e2e-tests.md): two clients run the real app at the same
# time against one local PocketBase and influence each other.
#
#   make e2e                              every story
#   make e2e STORIES=basics               one story
#   make e2e BROWSER=firefox              the web client in Firefox
#   make e2e E2E_WINDOW=1                 show the browser (and, with
#                                         xvfb-run installed, the desktop app)
#
# A story is a pair of files in app/integration_test/e2e/:
#   <story>_a_test.dart   client a, the Linux desktop app (flutter test -d linux)
#   <story>_b_test.dart   client b, the web client in a headless browser
#
# Per story, server/bin/e2e_backend.dart starts a fresh PocketBase with the
# fixture and one proxy per client, which also carries the coordination
# endpoints of the clients (server/lib/e2e_coordinator.dart). The web client
# is built (tool/build-web.sh) into the directory PocketBase serves and
# opened through its proxy; the Linux client runs with its own data
# directory, so the developer's installation is never touched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
OUT="$ROOT/app/build/web-e2e"
BROWSER="${BROWSER:-chrome}"
export BROWSER
if [ "${E2E_WINDOW:-}" = 1 ]; then export WEB_TEST_WINDOW=1; fi

log() { printf 'e2e: %s\n' "$*"; }
die() { printf 'e2e: %s\n' "$*" >&2; exit 1; }

cleanup_steps=()
cleanup() {
  local i
  for ((i = ${#cleanup_steps[@]} - 1; i >= 0; i--)); do eval "${cleanup_steps[$i]}" || true; done
}
trap cleanup EXIT

free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

wait_for() {
  local _
  for _ in $(seq 150); do
    curl -s -o /dev/null "$1" && return 0
    sleep 0.1
  done
  die "$2 did not start"
}

json() { python3 -c 'import json, sys; v = json.load(open(sys.argv[1])); [v := v[k] for k in sys.argv[2:]]; print(v)' "$@"; }

# The Linux client needs a display: a virtual one with xvfb-run unless
# E2E_WINDOW=1, else the session's own (its window opens while it runs).
linux_runner=()
if [ "${E2E_WINDOW:-}" != 1 ] && command -v xvfb-run >/dev/null 2>&1; then
  linux_runner=(xvfb-run -a)
elif [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  die "the Linux client needs a display: install xvfb-run (package xorg-server-xvfb or xvfb)"
fi

# shellcheck source=tool/webdriver.sh
. "$ROOT/tool/webdriver.sh"

cd "$ROOT/server"
dart pub get >/dev/null
cd "$ROOT/app"
flutter pub get >/dev/null

if [ -n "${STORIES:-}" ]; then
  read -r -a stories <<<"$STORIES"
else
  stories=()
  for a in integration_test/e2e/*_a_test.dart; do
    a="$(basename "$a")"
    stories+=("${a%_a_test.dart}")
  done
fi
browser_version="$("$BROWSER_BINARY" --version 2>/dev/null | head -1)"

work="$(mktemp -d)"
cleanup_steps+=("rm -rf '$work'")

# Runs one story; returns non-zero when a client failed.
run_story() {
  local story="$1" a="integration_test/e2e/${1}_a_test.dart" b="integration_test/e2e/${1}_b_test.dart"
  [ -f "$a" ] && [ -f "$b" ] || die "story $story needs $a and $b"
  local dir="$work/$story"
  mkdir -p "$dir/linux-data" "$dir/xdg"
  rm -rf "$OUT"
  mkdir -p "$OUT"

  log "$story: starting the backend"
  (cd "$ROOT/server" && exec dart run bin/e2e_backend.dart --public-dir "$OUT" --clients a,b) \
    >"$dir/backend.log" 2>&1 &
  local backend_pid=$!
  local _
  for _ in $(seq 600); do
    grep -m1 '^{' "$dir/backend.log" >"$dir/backend.json" && break
    kill -0 "$backend_pid" 2>/dev/null || { cat "$dir/backend.log" >&2; die "the backend did not start"; }
    sleep 0.1
  done
  [ -s "$dir/backend.json" ] || die "the backend did not start within 60s"
  local port_a port_b
  port_a="$(json "$dir/backend.json" clients a)"
  port_b="$(json "$dir/backend.json" clients b)"
  local defines=(
    "--dart-define=SETDING_E2E_ANNA_EMAIL=$(json "$dir/backend.json" accounts anna email)"
    "--dart-define=SETDING_E2E_BEN_EMAIL=$(json "$dir/backend.json" accounts ben email)"
    "--dart-define=SETDING_E2E_PASSWORD=$(json "$dir/backend.json" accounts anna password)"
    "--dart-define=SETDING_E2E_SONG=$(json "$dir/backend.json" song)"
    "--dart-define=SETDING_E2E_SHEET=$(json "$dir/backend.json" sheet)"
  )

  log "$story: building client b (web)"
  WEB_OUT="$OUT" "$ROOT/tool/build-web.sh" --profile --target "$b" \
    "${defines[@]}" --dart-define=SETDING_E2E_CLIENT=b >"$dir/build-web.log" 2>&1 ||
    { cat "$dir/build-web.log" >&2; kill -TERM "$backend_pid"; wait "$backend_pid" 2>/dev/null; return 1; }

  log "$story: starting client a (Linux desktop)"
  SETDING_DATA_DIR="$dir/linux-data" XDG_DATA_HOME="$dir/xdg" \
    "${linux_runner[@]}" flutter test -d linux "$a" "${defines[@]}" \
    --dart-define=SETDING_E2E_CLIENT=a \
    "--dart-define=SETDING_E2E_SERVER=http://127.0.0.1:$port_a" \
    > >(sed -u 's/^/[a] /') 2>&1 &
  local a_pid=$!

  # Client b starts once client a has signed in: building and starting the
  # desktop app takes longer than loading the page.
  local ready=0
  for _ in $(seq 600); do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port_a/__e2e/wait/a-ready?timeout=1")" = 200 ]; then
      ready=1
      break
    fi
    kill -0 "$a_pid" 2>/dev/null || break
  done
  local status_a=0 status_b=0
  if [ "$ready" = 1 ]; then
    log "$story: running client b in $browser_version"
    dart test_driver/web_driver.dart "http://127.0.0.1:$driver_port/" "http://127.0.0.1:$port_b/" \
      > >(sed -u 's/^/[b] /') 2>&1 || status_b=$?
    if [ "$status_b" != 0 ]; then
      # Client a stops waiting for b.
      curl -s -o /dev/null -X POST --data "client b failed (see its output)" \
        "http://127.0.0.1:$port_a/__e2e/abort" || true
    fi
  else
    log "$story: client a did not get ready"
    status_b=1
  fi
  wait "$a_pid" || status_a=$?

  kill -TERM "$backend_pid" 2>/dev/null || true
  wait "$backend_pid" 2>/dev/null || true
  if [ "$status_a" != 0 ] || [ "$status_b" != 0 ]; then
    log "$story: FAILED (client a: $status_a, client b: $status_b; backend log: below)"
    tail -n 40 "$dir/backend.log" >&2 || true
    return 1
  fi
  log "$story: passed"
}

failed=()
for story in "${stories[@]}"; do
  run_story "$story" || failed+=("$story")
done
if [ "${#failed[@]}" -gt 0 ]; then
  die "failed: ${failed[*]} (a screenshot of client b: app/build/web-itest-failure.png)"
fi
log "all end-to-end stories passed (Linux desktop + $browser_version)"
