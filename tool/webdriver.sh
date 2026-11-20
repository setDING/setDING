# shellcheck shell=bash
# Shared by tool/web-test.sh and tool/e2e-test.sh (sourced): finds the
# browser of BROWSER (chrome or firefox) and starts its WebDriver on a free
# port. Sets BROWSER_BINARY (exported) and driver_port. The caller defines
# die, free_port, wait_for and the cleanup_steps array, and ROOT.

major() { "$1" --version | grep -oE '[0-9]+\.[0-9.]+' | head -1 | cut -d. -f1; }
case "${BROWSER:?set by the caller}" in
  chrome)
    if [ -z "${BROWSER_BINARY:-}" ]; then
      for browser in chromium google-chrome-stable google-chrome chrome; do
        BROWSER_BINARY="$(command -v "$browser" || true)"
        [ -n "$BROWSER_BINARY" ] && break
      done
    fi
    [ -n "${BROWSER_BINARY:-}" ] || die "Chrome or Chromium not found (set BROWSER_BINARY)"
    webdriver="${CHROMEDRIVER:-$(command -v chromedriver || true)}"
    [ -n "$webdriver" ] || die "chromedriver not found (install it or set CHROMEDRIVER)"
    [ "$(major "$BROWSER_BINARY")" = "$(major "$webdriver")" ] ||
      die "$BROWSER_BINARY $(major "$BROWSER_BINARY") and $webdriver $(major "$webdriver") differ (set BROWSER_BINARY or CHROMEDRIVER)"
    ;;
  firefox)
    BROWSER_BINARY="${BROWSER_BINARY:-$(command -v firefox || true)}"
    [ -n "$BROWSER_BINARY" ] || die "Firefox not found (set BROWSER_BINARY)"
    webdriver="${GECKODRIVER:-$(command -v geckodriver || "$ROOT/tool/fetch-tool.sh" geckodriver)}"
    ;;
  *) die "unknown BROWSER $BROWSER (chrome or firefox)" ;;
esac
export BROWSER_BINARY
driver_port="$(free_port)"
if [ "$BROWSER" = firefox ]; then
  # The page's console comes on geckodriver's output; web_driver.dart prints
  # the test's lines from this file.
  WEBDRIVER_LOG="$(mktemp)"
  export WEBDRIVER_LOG
  cleanup_steps+=("rm -f '$WEBDRIVER_LOG'")
  "$webdriver" --port "$driver_port" --log fatal >"$WEBDRIVER_LOG" 2>&1 &
else
  "$webdriver" --port="$driver_port" --log-level=SEVERE >/dev/null 2>&1 &
fi
driver_pid=$!
cleanup_steps+=("kill $driver_pid 2>/dev/null; wait $driver_pid 2>/dev/null")
wait_for "http://127.0.0.1:$driver_port/status" "$(basename "$webdriver")"
