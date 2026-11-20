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
make web-test                                          # headless Chrome
make web-test TESTS=integration_test/web/web_test.dart
make web-test WEB_TEST_WINDOW=1                        # watch the browser
```

Requirements: Chrome or Chromium and a **chromedriver of the same major
version** (on Arch Linux both come with the `chromium` package), Flutter and
Python 3. `CHROME_BINARY` and `CHROMEDRIVER` select others.

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
3. opens the page in Chrome through chromedriver;
   [`app/test_driver/web_driver.dart`](../../app/test_driver/web_driver.dart)
   prints the browser console (the test's output) and waits for the result.

Why not `flutter drive -d chrome`: it serves the app from Flutter's own
development server, on another origin than the API and without the isolation
headers. drift would then fall back from OPFS to IndexedDB, and the test would
not see what users get. `web_driver.dart` speaks the W3C WebDriver protocol
directly and asks the page for the result the same way `flutter drive` does
(`window.$flutterDriver`, `request_data`).

## The tests

| File | What runs in the browser |
|---|---|
| `web/web_test.dart` | The sign-in gate and sign-in through the real UI against the page's own origin; drift's WASM database in OPFS (`webDatabaseStorage` is `opfsLocks`); the first sync brings the band and its songs; the session is in `sessionStorage` only (no "Stay signed in"); the synced song in the library and on the song screen; a set in live mode with the web notice, page turns with keys and the PDF fetched from the server when it is shown; signing out deletes the local data and the session and shows the gate again |

Each file is built and loaded as its own page with a fresh browser profile.

## Adding tests

- Put them in `app/integration_test/web/`; the Android runner only takes
  `integration_test/*_test.dart`.
- Use `pumpUntil` / `pumpFor` from
  [`integration_test/support.dart`](../../app/integration_test/support.dart)
  and run database work inside `tester.runAsync`, as on Android.
- Set `language` to `en` in the shared preferences before `main()` when the
  test looks for texts.
- One `testWidgets` per file that calls `main()`.

## Not covered (yet)

Several tabs (the `BroadcastChannel` between tabs, signing out in another
tab), reloading the page with a kept session, the IndexedDB fallback without
the isolation headers, Firefox and Safari.
