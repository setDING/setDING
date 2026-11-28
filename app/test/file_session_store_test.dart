import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/sync/session_store_io.dart';

// The session file of isolated test instances (SETDING_DATA_DIR). Until #1247
// no test loaded it, so the coverage ratchet of lib/sync/ did not see it.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('session_store');
    file = File('${dir.path}/nested/session');
  });

  tearDown(() => dir.delete(recursive: true));

  test('without a file there is no session', () async {
    final store = FileSessionStore(file);
    await store.load();
    expect(store.current, isNull);
  });

  test(
    'a written session survives a new store and creates the folder',
    () async {
      await FileSessionStore(file).write('token');
      expect(await file.readAsString(), 'token');

      final again = FileSessionStore(file);
      await again.load();
      expect(again.current, 'token');
    },
  );

  test('delete removes the file and the session', () async {
    final store = FileSessionStore(file);
    await store.write('token');
    await store.delete();
    expect(store.current, isNull);
    expect(await file.exists(), isFalse);
    // Deleting again is harmless.
    await store.delete();
  });
}
