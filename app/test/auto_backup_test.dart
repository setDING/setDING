import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/platform/backup_folder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backup_folder.dart';

/// Automatic backup of the local library (ADR-0054 section 1).
void main() {
  group('file names', () {
    test('device and minute in the name', () {
      expect(
        autoBackupFileName('Andi\'s iPad', DateTime(2026, 3, 4, 7, 5)),
        "setDING-Backup Andi's iPad 2026-03-04 0705.zip",
      );
      // Characters a file name cannot hold are left out.
      expect(
        autoBackupFileName('Band/Tab:1', DateTime(2026, 11, 22, 18, 30)),
        'setDING-Backup BandTab1 2026-11-22 1830.zip',
      );
    });

    test('only the backups of this device, newest first', () {
      final names = [
        'setDING-Backup iPad 2026-01-02 0800.zip',
        'setDING-Backup iPad Pro 2026-01-03 0800.zip',
        'setDING-Backup iPad 2026-01-03 0900.zip',
        'setDING-Backup iPad 2026-01-01 0800.zip.part',
        'setDING-Backup iPad 2026-01-01.zip',
        'notes.txt',
      ];
      expect(autoBackupsOf('iPad', names), [
        'setDING-Backup iPad 2026-01-03 0900.zip',
        'setDING-Backup iPad 2026-01-02 0800.zip',
      ]);
      expect(autoBackupsOf('iPad Pro', names), [
        'setDING-Backup iPad Pro 2026-01-03 0800.zip',
      ]);
    });

    test('at most once a day', () {
      final now = DateTime(2026, 5, 2, 8);
      expect(autoBackupDayDue(null, now), isTrue);
      expect(autoBackupDayDue(DateTime(2026, 5, 2, 0, 1), now), isFalse);
      expect(autoBackupDayDue(DateTime(2026, 5, 1, 23, 59), now), isTrue);
    });
  });

  group('controller', () {
    late AppDatabase db;
    late Directory dir;
    late SongRepository songs;
    late SharedPreferences prefs;
    late FakeBackupFolder folder;
    late DateTime now;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('setding_auto_backup');
      final storage = FileAttachmentStorage(dir);
      songs = SongRepository(db, storage);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      folder = FakeBackupFolder(
        device: 'Tab',
        choice: (location: '/cloud/Backups', name: 'Backups'),
      );
      now = DateTime(2026, 5, 2, 8, 30);
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    Future<AutoBackupController> controller() async {
      final c = AutoBackupController(
        prefs: prefs,
        folder: folder,
        backups: () => BackupService(db, FileAttachmentStorage(dir)),
        onChanged: (_) {},
        now: () => now,
      );
      await c.loadSystemDeviceName();
      return c;
    }

    Future<AutoBackupController> active() async {
      final c = await controller();
      expect(await c.chooseFolder(), isTrue);
      await c.setEnabled(true);
      return c;
    }

    test('off by default; nothing is written without a folder', () async {
      final c = await controller();
      expect(c.state.enabled, isFalse);
      expect(c.state.keep, 10);
      await c.setEnabled(true);
      expect(await c.runIfDue(libraryName: 'Local'), isFalse);
      expect(folder.files, isEmpty);
    });

    test('writes the archive of the local library under a temporary '
        'name, then renames it', () async {
      await songs.createSong(source: '{title: Hello}\n[C]Hello');
      final c = await active();
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      const name = 'setDING-Backup Tab 2026-05-02 0830.zip';
      expect(folder.files.keys, [name]);
      expect(folder.log, ['write $name.part', 'rename $name']);
      final contents = await BackupService.read(folder.files[name]!);
      expect(contents.sourceName, 'Local');
      expect((contents.manifest['source'] as Map)['kind'], 'local');
      expect(contents.songs, hasLength(1));
      expect(c.state.lastAt, now);
      expect(c.state.lastFile, name);
      // It counts as the last backup of the local library (ADR-0043).
      expect(prefs.getString(lastBackupKey), now.toIso8601String());
    });

    test('at most once a day and only after changes', () async {
      final song = await songs.createSong(source: '{title: Hello}');
      final c = await active();
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      now = now.add(const Duration(hours: 2));
      await songs.createSong(source: '{title: Second}');
      expect(await c.runIfDue(libraryName: 'Local'), isFalse);
      now = DateTime(2026, 5, 3, 7);
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      // The next day, without a change: nothing.
      now = DateTime(2026, 5, 4, 7);
      expect(await c.runIfDue(libraryName: 'Local'), isFalse);
      // A personal adjustment is a change too.
      await songs.updateOverlay(song, (o) => o.copyWith(transpose: 3));
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      expect(folder.files, hasLength(3));
    });

    test('Back up now writes also without a change', () async {
      final c = await active();
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      now = now.add(const Duration(minutes: 1));
      expect(await c.runNow(libraryName: 'Local'), isTrue);
      expect(folder.files, hasLength(2));
    });

    test(
      'keeps the newest backups of this device, never other files',
      () async {
        folder.files.addAll({
          'setDING-Backup Tab 2026-04-01 0800.zip': Uint8List(0),
          'setDING-Backup Tab 2026-04-02 0800.zip': Uint8List(0),
          'setDING-Backup Tab 2026-04-03 0800.zip.part': Uint8List(0),
          'setDING-Backup Phone 2026-04-01 0800.zip': Uint8List(0),
          'setDING-Backup Alles 2026-04-01.zip': Uint8List(0),
          'notes.txt': Uint8List(0),
        });
        final c = await active();
        await c.setKeep(2);
        expect(await c.runIfDue(libraryName: 'Local'), isTrue);
        expect(folder.files.keys.toSet(), {
          'setDING-Backup Tab 2026-05-02 0830.zip',
          'setDING-Backup Tab 2026-04-02 0800.zip',
          'setDING-Backup Phone 2026-04-01 0800.zip',
          'setDING-Backup Alles 2026-04-01.zip',
          'notes.txt',
        });
      },
    );

    test('the number kept is between 1 and 10', () async {
      final c = await controller();
      await c.setKeep(0);
      expect(c.state.keep, 1);
      await c.setKeep(42);
      expect(c.state.keep, 10);
    });

    test('the device name can be changed; empty is the system name', () async {
      final c = await active();
      expect(c.state.device, 'Tab');
      await c.setDeviceName('  Stage left ');
      expect(c.state.device, 'Stage left');
      expect(await c.runNow(libraryName: 'Local'), isTrue);
      expect(
        folder.files.keys.single,
        'setDING-Backup Stage left 2026-05-02 0830.zip',
      );
      await c.setDeviceName('');
      expect(c.state.deviceName, isNull);
      expect(c.state.device, 'Tab');
    });

    test('a lost permission is recorded, with a hint once a day', () async {
      final c = await active();
      folder.error = BackupFolderError.permission;
      expect(await c.runIfDue(libraryName: 'Local'), isFalse);
      expect(c.state.error, AutoBackupError.permission);
      expect(c.state.errorAt, now);
      expect(prefs.getString(lastBackupKey), isNull);
      expect(c.takeErrorHint(), isTrue);
      expect(c.takeErrorHint(), isFalse);
      now = DateTime(2026, 5, 3, 7);
      expect(c.takeErrorHint(), isTrue);
      // Stored: it is still there at the next start.
      expect((await controller()).state.error, AutoBackupError.permission);

      // Choosing the folder again clears it; the next backup succeeds.
      folder.error = null;
      expect(await c.chooseFolder(), isTrue);
      expect(c.state.error, isNull);
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      expect(c.takeErrorHint(), isFalse);
    });

    test('an unreachable folder is retried at the next check', () async {
      final c = await active();
      folder.error = BackupFolderError.unavailable;
      expect(await c.runIfDue(libraryName: 'Local'), isFalse);
      expect(c.state.error, AutoBackupError.unavailable);
      folder.error = null;
      expect(await c.runIfDue(libraryName: 'Local'), isTrue);
      expect(c.state.error, isNull);
    });

    test('switching off clears the error', () async {
      final c = await active();
      folder.error = BackupFolderError.failed;
      await c.runIfDue(libraryName: 'Local');
      expect(c.state.error, AutoBackupError.failed);
      await c.setEnabled(false);
      expect(c.state.error, isNull);
      expect(c.takeErrorHint(), isFalse);
    });
  });

  test('the fingerprint changes with the library, not with time', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final dir = Directory.systemTemp.createTempSync('setding_fingerprint');
    addTearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });
    final storage = FileAttachmentStorage(dir);
    final songs = SongRepository(db, storage);
    final service = BackupService(db, storage);
    final song = await songs.createSong(source: '{title: A}');
    final first = await service.fingerprint(localBandId);
    expect(await service.fingerprint(localBandId), first);
    await songs.updateOverlay(
      song,
      (o) => o.copyWith(notes: const Value('Slow')),
    );
    final second = await service.fingerprint(localBandId);
    expect(second, isNot(first));
    await songs.addAttachment(
      song,
      name: 'Score',
      bytes: Uint8List.fromList('%PDF'.codeUnits),
    );
    expect(await service.fingerprint(localBandId), isNot(second));
  });

  group('folder on the desktop', () {
    late Directory dir;
    late DirectoryBackupFolder folder;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('setding_folder');
      folder = DirectoryBackupFolder(
        pickDirectory: () async => dir.path,
        hostName: 'host',
      );
    });
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('writes, replaces, lists and deletes', () async {
      final choice = await folder.pick();
      expect(choice!.location, dir.path);
      await folder.write(dir.path, 'a.zip', Uint8List.fromList([1]));
      await folder.write(dir.path, 'a.zip', Uint8List.fromList([2]));
      Directory('${dir.path}/sub').createSync();
      expect(await folder.list(dir.path), ['a.zip']);
      expect(File('${dir.path}/a.zip').readAsBytesSync(), [2]);
      await folder.delete(dir.path, 'a.zip');
      await folder.delete(dir.path, 'missing.zip');
      expect(await folder.list(dir.path), isEmpty);
      expect(await folder.deviceName(), 'host');
    });

    test('a folder that is gone is unavailable', () async {
      dir.deleteSync(recursive: true);
      await expectLater(
        folder.write(dir.path, 'a.zip', Uint8List(0)),
        throwsA(
          isA<BackupFolderException>().having(
            (e) => e.error,
            'error',
            BackupFolderError.unavailable,
          ),
        ),
      );
    });
  });
}
