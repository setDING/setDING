// Web worker that runs the local database in the browser (ADR-0018).
// Compiled to web/drift_worker.js by tool/build-web.sh with the package
// versions of pubspec.lock, so it matches web/sqlite3.wasm.
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
