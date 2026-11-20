# Web integration tests

The widget tests (`make check`) cover the web client's behaviour with
`TestApp.create(web: true)` and fakes (memory database, memory session
storage, no network). The integration tests in
[`app/integration_test/web/`](../../app/integration_test/web/) run the real
web client in a browser instead (issue #650), set up like in production
([web.md](web.md), ADR-0018). They are the web counterpart of
[`make android-test`](android-tests.md) and, like it, **not part of
`make check`**; run them before a release and after changes to the web
platform code (drift WASM, browser session store, attachment fetching, web
build, server headers).

## Running

```bash
make web-test                                          # headless Chrome or Chromium
make web-test BROWSER=firefox                          # headless Firefox
make web-test TESTS=integration_test/web/web_test.dart
make web-test WEB_TEST_WINDOW=1                        # watch the browser
```

Requirements: Flutter, Python 3 and

- **Chrome** (default): Chrome or Chromium and a **chromedriver of the same
  major version** (on Arch Linux both come with the `chromium` package);
  `CHROMEDRIVER` selects another chromedriver.
- **Firefox**: Firefox; geckodriver is taken from `GECKODRIVER`, else from
  the `PATH`, else `tool/fetch-tool.sh geckodriver` downloads the pinned
  release into the cache (MPL-2.0, a check tool like ShellCheck: verified by
  its SHA-256 sum, never copied into the repository or shipped).

`BROWSER_BINARY` selects the browser's binary. `make release-gate` runs the
tests in both browsers before a release ([releases.md](releases.md)).

**Safari** cannot be tested: safaridriver only runs on macOS, and the
development machine and CI run Linux.

## How it works

[`tool/web-test.sh`](../../tool/web-test.sh)

1. starts a local PocketBase with the repository's schema and hooks
   ([`server/bin/itest_backend.dart`](../../server/bin/itest_backend.dart))
   with a user, a band and two songs, one with a two-page PDF. It serves
   `app/build/web-itest` like the production server serves the web client:
   **same origin as the API, with the isolation headers** of
   `server/pb_hooks/lib/web.js`;
2. builds each test as the web client into that directory
   (`tool/build-web.sh` with `WEB_OUT`, `--profile --target <test>`), with
   the account as `--dart-define`;
3. opens the page in the browser through its WebDriver (chromedriver,
   geckodriver);
   [`app/test_driver/web_driver.dart`](../../app/test_driver/web_driver.dart)
   prints the browser console (the test's output) and waits for the result.
   On a failure it saves a screenshot to `app/build/web-itest-failure.png`.

A test whose first line is `// web-test: no-isolation` is served by a plain
static server (`python3 -m http.server`) on another port instead: without the
isolation headers, with the API on PocketBase cross-origin
(`SETDING_SERVER_URL`). That is how a server without the headers behaves.

### Several page loads and tabs

Every load of the page starts the test again. A test that reloads the page or
opens tabs reads its current `step` and, when it has passed, tells the driver
what to do next with `then(...)`
([`web_support.dart`](../../app/integration_test/web/web_support.dart)):

| `then` | The driver |
|---|---|
| `reload` | reloads the tab |
| `open` | opens a new tab with `?step=<tabStep>`; this tab stays open in the background |
| `replace` | closes this tab and opens a new one with `?step=<tabStep>` |
| `back` | closes this tab and waits for the previous tab to load again (it reloads by itself) |

`nextStep` is the step of the tab's next load, kept in its `sessionStorage`.
Chrome runs with background throttling off, so a tab in the background keeps
answering its other tabs.

Why not `flutter drive -d chrome`: it serves the app from Flutter's own
development server, on another origin than the API and without the isolation
headers. drift would then fall back from OPFS to IndexedDB, and the test would
not see what users get. `web_driver.dart` speaks the W3C WebDriver protocol
directly and asks the page for the result the same way `flutter drive` does
(`window.$flutterDriver`, `request_data`).

## The tests

| File | What runs in the browser |
|---|---|
| `web/web_test.dart` | The sign-in gate and sign-in through the real UI against the page's own origin; drift's WASM database in OPFS (`webDatabaseStorage`: `opfsLocks` in Chrome, `opfsShared` in Firefox); the first sync brings the band and its songs; the session is in `sessionStorage` only (no "Stay signed in"); the synced song in the library and on the song screen; a set in live mode with the web notice, page turns with keys and the PDF fetched from the server when it is shown; signing out deletes the local data and the session and shows the gate again |
| `web/tabs_test.dart` | Four loads in two tabs: reloading keeps the session (`sessionStorage`) and the data in OPFS; a new tab gets the session from the open tab over the `BroadcastChannel` without signing in; signing out there reloads the first tab, which shows the gate and deletes its local data |
| `web/keep_signed_in_test.dart` | "Stay signed in" keeps the session in `localStorage`: after closing the tab, a new tab (no other tab to ask) is still signed in with its data; signing out removes the kept session |
| `web/no_isolation_test.dart` | Without the isolation headers (`no-isolation`): the page is not cross-origin isolated, drift cannot use `opfsLocks` (Chrome falls back to IndexedDB; Firefox keeps `opfsShared`, OPFS through a shared worker, as with the headers), sign-in and sync work cross-origin, the data survives a reload |

Each file is built and loaded as its own page with a fresh browser profile.
All of them run in Chrome and in Firefox.

## Adding tests

- Put them in `app/integration_test/web/`; the Android runner only takes
  `integration_test/*_test.dart`. Shared steps (sign in, wait for the sync,
  sign out, press a key) are in `web_support.dart`.
- Texts go in with `fillIn` and keys with `pressKey` (real browser events):
  `enterText` and flutter_test's key simulation do not work in a web build.
- Use `pumpUntil` / `pumpFor` from
  [`integration_test/support.dart`](../../app/integration_test/support.dart)
  and run database work inside `tester.runAsync`, as on Android.
- Set `language` to `en` in the shared preferences before `main()` when the
  test looks for texts.
- One `testWidgets` per file that calls `main()`.

## Not covered

Two clients changing each other's data: that is what the end-to-end tests
do ([e2e-tests.md](e2e-tests.md)). Safari (macOS only, see above).
