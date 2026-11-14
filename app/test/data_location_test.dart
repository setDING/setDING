import 'dart:io';

import 'package:bandchords/data/data_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory legacy;

  setUp(() {
    root = Directory.systemTemp.createTempSync('bandchords_location');
    support = Directory('${root.path}/support');
    legacy = Directory('${root.path}/Documents')..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('uses the support directory', () async {
    final file = await resolveDatabaseFile(support, legacyDir: legacy);
    expect(file.path, '${support.path}/$databaseFileName');
    expect(support.existsSync(), isTrue);
  });

  test('moves a legacy database including side files', () async {
    File('${legacy.path}/$databaseFileName').writeAsStringSync('db');
    File('${legacy.path}/$databaseFileName-wal').writeAsStringSync('wal');

    final file = await resolveDatabaseFile(support, legacyDir: legacy);

    expect(file.readAsStringSync(), 'db');
    expect(File('${file.path}-wal').readAsStringSync(), 'wal');
    expect(File('${legacy.path}/$databaseFileName').existsSync(), isFalse);
  });

  test('never overwrites an existing database', () async {
    support.createSync();
    File('${support.path}/$databaseFileName').writeAsStringSync('new');
    File('${legacy.path}/$databaseFileName').writeAsStringSync('old');

    final file = await resolveDatabaseFile(support, legacyDir: legacy);

    expect(file.readAsStringSync(), 'new');
    expect(File('${legacy.path}/$databaseFileName').existsSync(), isTrue);
  });
}
