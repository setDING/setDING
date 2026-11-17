import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/data_location_io.dart';

void main() {
  late Directory root;
  late Directory support;

  setUp(() {
    root = Directory.systemTemp.createTempSync('setding_location');
    support = Directory('${root.path}/support');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('uses the support directory', () async {
    final file = await resolveDatabaseFile(support);
    expect(file.path, '${support.path}/setding.sqlite');
    expect(support.existsSync(), isTrue);
  });

  test('keeps an existing database', () async {
    support.createSync();
    File('${support.path}/$databaseFileName').writeAsStringSync('db');

    final file = await resolveDatabaseFile(support);

    expect(file.readAsStringSync(), 'db');
  });
}
