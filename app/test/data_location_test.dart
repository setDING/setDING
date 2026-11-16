import 'dart:io';

import 'package:realchord/data/data_location_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory legacy;

  setUp(() {
    root = Directory.systemTemp.createTempSync('realchord_location');
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
    File('${legacy.path}/$legacyDatabaseFileName').writeAsStringSync('db');
    File('${legacy.path}/$legacyDatabaseFileName-wal').writeAsStringSync('wal');

    final file = await resolveDatabaseFile(support, legacyDir: legacy);

    expect(file.path, '${support.path}/$databaseFileName');
    expect(file.readAsStringSync(), 'db');
    expect(File('${file.path}-wal').readAsStringSync(), 'wal');
    expect(
      File('${legacy.path}/$legacyDatabaseFileName').existsSync(),
      isFalse,
    );
  });

  test('renames the database from before the rename to RealChord', () async {
    support.createSync();
    File('${support.path}/$legacyDatabaseFileName').writeAsStringSync('db');
    File('${support.path}/$legacyDatabaseFileName-shm').writeAsStringSync('s');

    final file = await resolveDatabaseFile(support, legacyDir: legacy);

    expect(file.path, '${support.path}/$databaseFileName');
    expect(file.readAsStringSync(), 'db');
    expect(File('${file.path}-shm').readAsStringSync(), 's');
    expect(
      File('${support.path}/$legacyDatabaseFileName').existsSync(),
      isFalse,
    );
  });

  test('never overwrites an existing database', () async {
    support.createSync();
    File('${support.path}/$databaseFileName').writeAsStringSync('new');
    File('${legacy.path}/$legacyDatabaseFileName').writeAsStringSync('old');

    final file = await resolveDatabaseFile(support, legacyDir: legacy);

    expect(file.readAsStringSync(), 'new');
    expect(File('${legacy.path}/$legacyDatabaseFileName').existsSync(), isTrue);
  });

  group('support directory from before the rename', () {
    test('derives the Linux and Windows directories', () {
      expect(
        legacySupportDir(Directory('/data/ch.realchord.realchord'))?.path,
        '/data/ch.bandchords.bandchords',
      );
      expect(
        legacySupportDir(Directory('/roaming/ch.realchord/RealChord'))?.path,
        '/roaming/ch.bandchords/BandChords',
      );
      expect(legacySupportDir(Directory('/data/app_flutter')), isNull);
    });

    test('moves the whole directory', () async {
      final legacyApp = Directory('${root.path}/ch.bandchords.bandchords')
        ..createSync();
      File('${legacyApp.path}/shared_preferences.json').writeAsStringSync('{}');
      Directory('${legacyApp.path}/attachments').createSync();
      final current = Directory('${root.path}/ch.realchord.realchord');

      expect(await migrateLegacySupportDir(current), isTrue);

      expect(legacyApp.existsSync(), isFalse);
      expect(
        File('${current.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
      expect(Directory('${current.path}/attachments').existsSync(), isTrue);
    });

    test('creates the parent directory on Windows', () async {
      final legacyApp = Directory('${root.path}/ch.bandchords/BandChords')
        ..createSync(recursive: true);
      File('${legacyApp.path}/x').writeAsStringSync('x');
      final current = Directory('${root.path}/ch.realchord/RealChord');

      expect(await migrateLegacySupportDir(current), isTrue);
      expect(File('${current.path}/x').existsSync(), isTrue);
    });

    test('replaces an empty directory created by path_provider', () async {
      final legacyApp = Directory('${root.path}/ch.bandchords.bandchords')
        ..createSync();
      File('${legacyApp.path}/x').writeAsStringSync('x');
      final current = Directory('${root.path}/ch.realchord.realchord')
        ..createSync();

      expect(await migrateLegacySupportDir(current), isTrue);
      expect(File('${current.path}/x').existsSync(), isTrue);
      expect(legacyApp.existsSync(), isFalse);
    });

    test('never overwrites a directory with content', () async {
      Directory('${root.path}/ch.bandchords.bandchords').createSync();
      final current = Directory('${root.path}/ch.realchord.realchord')
        ..createSync();
      File('${current.path}/shared_preferences.json').writeAsStringSync('{}');

      expect(await migrateLegacySupportDir(current), isFalse);
      expect(
        Directory('${root.path}/ch.bandchords.bandchords').existsSync(),
        isTrue,
      );
    });

    test('does nothing without a legacy directory', () async {
      final current = Directory('${root.path}/ch.realchord.realchord');
      expect(await migrateLegacySupportDir(current), isFalse);
      expect(current.existsSync(), isFalse);
    });
  });
}
