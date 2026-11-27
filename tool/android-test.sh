#!/usr/bin/env bash
# Runs the Android integration tests (make android-test, issue #647,
# docs/development/android-tests.md): app/integration_test/*_test.dart except
# the performance scenarios of make perf.
#
#   make android-test                     own headless emulator (default)
#   make android-test DEVICE=<id>         USB-connected device (id from `adb devices`)
#   make android-test TESTS=integration_test/app_test.dart
#   make android-test EMULATOR_WINDOW=1   show the emulator window
#
# The emulator uses its own AVD (ANDROID_AVD, default setding-itest). It is
# created from the newest installed Google APIs system image if missing,
# started headless with a fresh data partition and stopped afterwards; an
# already running emulator of that AVD is reused and kept running.
#
# The tests are built as their own app (app.setding.itest, "setDING Test"):
# a release (app.setding) or beta (app.setding.beta) installation and its data
# are never touched. The test app is removed before and after the run.
#
# The sync tests sign in to a local PocketBase with the repository's schema,
# started on this machine (server/bin/itest_backend.dart) and reached by the
# device through `adb reverse`.
#
# The deep link tests ask for a link from outside the app by logging
# "setding-itest-open-link: <link>" (integration_test/support.dart, openLink);
# a watcher of the device's log fires it with `adb shell am start`, as a chat
# or the browser would.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_HOME
ADB="${ADB:-$ANDROID_HOME/platform-tools/adb}"
EMULATOR="$ANDROID_HOME/emulator/emulator"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
AVD="${ANDROID_AVD:-setding-itest}"
PACKAGE=app.setding.itest
BOOT_TIMEOUT="${BOOT_TIMEOUT:-300}"

log() { printf 'android-test: %s\n' "$*"; }
die() { printf 'android-test: %s\n' "$*" >&2; exit 1; }

[ -x "$ADB" ] || die "adb not found in $ANDROID_HOME (set ANDROID_HOME)"

cleanup_steps=()
cleanup() {
  local i
  for ((i = ${#cleanup_steps[@]} - 1; i >= 0; i--)); do eval "${cleanup_steps[$i]}" || true; done
}
trap cleanup EXIT

# --- Device -----------------------------------------------------------------

# The serial of a running emulator of $AVD, if any.
running_emulator() {
  local serial
  for serial in $("$ADB" devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1}'); do
    if [ "$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "$AVD" ]; then
      echo "$serial"
      return
    fi
  done
}

create_avd() {
  [ -x "$AVDMANAGER" ] || die "avdmanager not found ($AVDMANAGER); install the Android SDK command-line tools"
  local arch image
  case "$(uname -m)" in
    aarch64 | arm64) arch=arm64-v8a ;;
    *) arch=x86_64 ;;
  esac
  # Newest installed Google APIs image of the host's architecture.
  image="$(find "$ANDROID_HOME/system-images" -mindepth 3 -maxdepth 3 -type d -path "*/google_apis*/$arch" 2>/dev/null |
    sed "s|^$ANDROID_HOME/system-images/||" | sort -t- -k2 -n | tail -1)"
  [ -n "$image" ] || die "no Google APIs system image ($arch) installed; e.g. sdkmanager 'system-images;android-36;google_apis;$arch'"
  log "creating AVD $AVD from ${image//\//;} (Pixel Tablet)"
  echo no | "$AVDMANAGER" create avd --name "$AVD" --package "system-images;${image//\//;}" --device pixel_tablet >/dev/null
}

start_emulator() {
  [ -x "$EMULATOR" ] || die "emulator not found ($EMULATOR); install the Android Emulator package"
  "$EMULATOR" -list-avds | grep -qx "$AVD" || create_avd
  local port=5580
  while "$ADB" devices | grep -q "^emulator-$port"; do port=$((port + 2)); done
  serial="emulator-$port"
  local window=(-no-window)
  [ "${EMULATOR_WINDOW:-0}" = 1 ] && window=()
  log "starting emulator $AVD ($serial)"
  "$EMULATOR" -avd "$AVD" -port "$port" "${window[@]}" -no-audio -no-boot-anim \
    -no-snapshot -wipe-data -gpu swiftshader_indirect >"${TMPDIR:-/tmp}/setding-emulator-$port.log" 2>&1 &
  cleanup_steps+=("log 'stopping emulator $serial'; '$ADB' -s $serial emu kill >/dev/null 2>&1")
  "$ADB" -s "$serial" wait-for-device
  local waited=0
  until [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
    sleep 2
    waited=$((waited + 2))
    [ "$waited" -lt "$BOOT_TIMEOUT" ] || die "emulator did not boot within ${BOOT_TIMEOUT}s"
  done
  # Animations off: fewer flaky timings.
  for setting in window_animation_scale transition_animation_scale animator_duration_scale; do
    "$ADB" -s "$serial" shell settings put global "$setting" 0
  done
  log "emulator booted after ${waited}s"
}

if [ -n "${DEVICE:-}" ]; then
  serial="$DEVICE"
  "$ADB" -s "$serial" get-state >/dev/null 2>&1 ||
    die "device $serial not connected (USB debugging on? see adb devices)"
  log "device $serial ($("$ADB" -s "$serial" shell getprop ro.product.model | tr -d '\r'))"
else
  serial="$(running_emulator)"
  if [ -n "$serial" ]; then
    log "reusing running emulator $AVD ($serial)"
  else
    start_emulator
  fi
fi
adb_device() { "$ADB" -s "$serial" "$@"; }

# --- Backend ----------------------------------------------------------------

cd "$ROOT/server"
dart pub get >/dev/null
backend_out="$(mktemp)"
backend_info="$(mktemp)"
cleanup_steps+=("rm -f '$backend_out' '$backend_info'")
log "starting local PocketBase"
dart run bin/itest_backend.dart >"$backend_out" &
backend_pid=$!
cleanup_steps+=("kill -TERM $backend_pid 2>/dev/null; wait $backend_pid 2>/dev/null")
for _ in $(seq 600); do
  grep -m1 '^{' "$backend_out" >"$backend_info" && break
  kill -0 "$backend_pid" 2>/dev/null || die "the local PocketBase did not start"
  sleep 0.1
done
[ -s "$backend_info" ] || die "the local PocketBase did not start within 60s"
port="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["port"])' "$backend_info")"
adb_device reverse "tcp:$port" "tcp:$port" >/dev/null
cleanup_steps+=("'$ADB' -s $serial reverse --remove tcp:$port >/dev/null 2>&1")
defines=()
while IFS= read -r define; do defines+=("--dart-define=$define"); done < <(
  python3 -c '
import json, sys
info = json.load(open(sys.argv[1]))
print("SETDING_ITEST_SERVER=http://127.0.0.1:%d" % info["port"])
for key in ("email", "password", "song"):
    print("SETDING_ITEST_%s=%s" % (key.upper(), info[key]))
' "$backend_info"
)

# --- Tests ------------------------------------------------------------------

cd "$ROOT/app"
adb_device uninstall "$PACKAGE" >/dev/null 2>&1 || true
cleanup_steps+=("'$ADB' -s $serial uninstall $PACKAGE >/dev/null 2>&1")
if [ -n "${TESTS:-}" ]; then
  read -r -a tests <<<"$TESTS"
else
  tests=()
  for test in integration_test/*_test.dart; do
    # The performance scenarios run with make perf (profile build).
    [ "$test" = integration_test/performance_test.dart ] || tests+=("$test")
  done
fi

# --- Links from outside the app ---------------------------------------------

# Only the app's own links: https on its hosts and setding://, with nothing
# the device's shell would interpret.
link_pattern='^(https://(app|api)\.setding\.app/|setding://)[A-Za-z0-9/_-]+$'
watch_links() {
  local line link
  adb_device logcat -T 1 -v raw -s flutter:I | while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
      *'setding-itest-open-link: '*) link="${line#*setding-itest-open-link: }" ;;
      *) continue ;;
    esac
    if [[ ! "$link" =~ $link_pattern ]]; then
      log "ignoring link $link"
      continue
    fi
    log "opening $link"
    adb_device shell am start -W -a android.intent.action.VIEW \
      -c android.intent.category.BROWSABLE -d "'$link'" "$PACKAGE" >/dev/null </dev/null ||
      log "could not open $link"
  done
}
watch_links &
watcher_pid=$!
cleanup_steps+=("pkill -P $watcher_pid 2>/dev/null; kill $watcher_pid 2>/dev/null")
defines+=(--dart-define=SETDING_ITEST_LINKS=true)

log "running ${tests[*]} on $serial"
SETDING_ANDROID_ITEST=1 flutter test "${tests[@]}" -d "$serial" "${defines[@]}"
