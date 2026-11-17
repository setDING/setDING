#!/usr/bin/env bash
# Measures performance on a connected Android device (make perf, issue #270,
# docs/development/performance.md): builds the app in profile mode, seeds a
# large library on the device and records timelines of the stage-relevant
# paths. Results: app/build/perf/.
#
# The scenarios run in the app's own data directory. A setDING release
# installation (not debuggable, e.g. from Obtainium) would be replaced by the
# test build together with its data, so the script refuses to run then.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
ADB="${ADB:-${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb}"
PACKAGE=app.setding

device=(${DEVICE:+-s "$DEVICE"})
if ! "$ADB" "${device[@]}" get-state >/dev/null 2>&1; then
  echo "perf: no Android device connected (USB debugging on, set DEVICE=<id> for several)" >&2
  exit 1
fi
flags="$("$ADB" "${device[@]}" shell dumpsys package "$PACKAGE" | sed -n 's/^ *pkgFlags=//p' | head -1)"
if [ -n "$flags" ] && [[ "$flags" != *DEBUGGABLE* ]]; then
  echo "perf: $PACKAGE is installed as a release build on this device." >&2
  echo "perf: the measurement would replace it and delete its data; uninstall it first or use another device." >&2
  exit 1
fi

cd "$ROOT/app"
rm -rf build/perf
flutter drive --profile --no-dds ${DEVICE:+-d "$DEVICE"} \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/performance_test.dart
python3 "$ROOT/tool/perf-summary.py" build/perf
