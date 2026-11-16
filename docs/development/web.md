# Web client (development)

The web client is a Flutter web build of the same app (ADR-0018). Everything
above the platform layer is shared with the native apps.

## Build and run

```bash
make web          # build into app/build/web (also part of `make check`)
make web-serve    # build and serve on http://127.0.0.1:8090
```

`tool/build-web.sh` checks `web/sqlite3.wasm`, compiles the drift worker and
runs `flutter build web`. For hot reload, run `tool/build-web.sh` once (it
creates `app/web/drift_worker.js`) and then `flutter run -d chrome` in `app/`.

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
`Cross-Origin-Embedder-Policy: require-corp` it uses OPFS (`opfsLocks`);
without them it falls back to IndexedDB in a shared worker
(`sharedIndexedDb`). Both work; `sqlite3` older than the version drift was
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

State of issue #27: the web client opens the local database and runs the
shared UI. Web sessions, hiding the local library and import/export, PDF
attachments on demand and hosting follow in their own steps; until then the
session lasts as long as the page and attachments are kept in memory.
