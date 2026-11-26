# Web client (development)

The web client is a Flutter web build of the same app (ADR-0018). Everything
above the platform layer is shared with the native apps.

## Build and run

```bash
make web          # build into app/build/web (also part of `make check`)
make web-serve    # build, then serve it with the local backend (make backend)
make web-test     # integration tests in headless Chrome (web-tests.md)
```

`make web-serve` serves the web client from the local PocketBase on
http://127.0.0.1:8090, like production: same origin as the API, with the
isolation headers. `tool/build-web.sh` checks `web/sqlite3.wasm`, compiles the
drift worker and runs `flutter build web` (CanvasKit from the server, not the
CDN). It then drops `sourceMappingURL` comments that point to source maps the
build does not ship (`flutter.js.map`); otherwise browser devtools fetch them,
get `index.html` from the server's SPA fallback and report a source map error. For hot reload, run `tool/build-web.sh` once (it creates
`app/web/drift_worker.js`), start `make backend`, and run
`flutter run -d chrome --dart-define=SETDING_SERVER_URL=http://127.0.0.1:8090`
in `app/`. Hosting in production: docs/operations/server.md, step 6.

## Local database in the browser

drift runs SQLite as WebAssembly (`package:drift/wasm.dart`), started by
`lib/bootstrap/platform_services_web.dart`. It needs two files in `app/web/`:

| File | Source | In git |
|---|---|---|
| `sqlite3.wasm` | Release asset of `package:sqlite3` (`https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<version>/sqlite3.wasm`) | yes, pinned by version and SHA-256 in `tool/build-web.sh` |
| `drift_worker.js` | Compiled from `app/web/drift_worker.dart` by `tool/build-web.sh` | no (generated) |

Both must match the `sqlite3` and `drift` versions in `app/pubspec.lock`: the
worker is compiled from the locked packages, and `tool/build-web.sh` fails if
`package:sqlite3` moves away from the pinned `sqlite3.wasm`. **When
`package:sqlite3` is upgraded**, download the `sqlite3.wasm` of the new
version into `app/web/` and update `SQLITE3_VERSION` and
`SQLITE3_WASM_SHA256` in `tool/build-web.sh`.

drift picks the storage the browser supports. With the headers
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` Chrome uses OPFS (`opfsLocks`);
without them it falls back to IndexedDB in a shared worker
(`sharedIndexedDb`). Firefox uses OPFS through a shared worker (`opfsShared`)
with or without the headers. All of them work (`make web-test` checks both
cases in both browsers, [web-tests.md](web-tests.md)); `sqlite3` older than the version drift was
built with made the IndexedDB fallback hang without an error (fixed by
upgrading to 3.9.1).

## Platform code

`dart:io` is only used in native-only files named `*_io.dart`, reached
through conditional imports (`if (dart.library.io)`);
`test/architecture_test.dart` enforces this. The pairs are:

| Shared entry point | Native | Web |
|---|---|---|
| `lib/bootstrap/platform_services.dart` | `platform_services_io.dart`: files, secure storage | `platform_services_web.dart`: drift WASM, memory |
| `lib/data/attachment_storage.dart` (interface) | `attachment_storage_io.dart` | `attachment_storage_memory.dart` |
| `lib/ui/platform/stored_file_view.dart` | `Image.file`, `PdfViewer.file` | from bytes |
| `lib/platform/network_error.dart` | `SocketException` | – |

## Web-only behaviour

The UI asks `webClientProvider` (`kIsWeb`, overridden in tests with
`TestApp.create(web: true)`) instead of `kIsWeb`, so the web behaviour is
covered by the normal widget tests (`test/web_client_test.dart`):

- `StartScreen`: sign-in gate, "no band yet" screen, then the `HomeScreen`.
- `bandsProvider` leaves out the local library.
- Export (song and set archives, set list PDF) is a download; a single song
  as a ChordPro file is not offered. Import (ChordPro, ZIP) works as in the
  app, and the imported songs are pushed by the next sync.
- Attachments are not preloaded (`SyncEngine.preloadAttachments`); the live
  view loads a PDF through `attachmentFileProvider` / `AttachmentFetcher`
  when it is opened. "Offline ready" and missing files are not shown.
- Live mode shows "not offline-safe, use the app on stage" in its status bar.
- `AuthNotifier` deletes the local data (`AppDatabase.clearAll`, attachments,
  selected band) when signing out and on a start without a session.

The session is a `BrowserSessionStore` (`sessionStorage`, `localStorage`,
`BroadcastChannel` between tabs, see ADR-0018). Its logic is plain Dart and
tested with fakes (`test/browser_session_store_test.dart`); the browser
adapters are in `lib/platform/browser_storage_web.dart`.

The click of the drummer mode (ADR-0026) uses SoLoud's WebAssembly build,
loaded by `assets/packages/flutter_soloud/web/init_soloud.js` in
`web/index.html` (`test/web_hosting_test.dart` checks the tag). It picks the
AudioWorklet build when the page is cross-origin isolated, else the
single-threaded one. The browser starts the audio only after a user gesture;
the beat is started by a tap.

PDFs on web use pdfrx's own WebAssembly build (`pdfium.wasm`), which
Flutter copies from the package into `build/web/assets/packages/pdfrx/`.

Embedded browsers (e.g. the Electron browser pane of tools) may fail to start
drift's worker under cross-origin isolation; current Chrome, Edge and Firefox
work, Safari uses the IndexedDB fallback.
