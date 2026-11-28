// Fuzz tests of the archive imports (#1244): damaged archives, ZIP bombs,
// path traversal, odd and duplicate names. An import refuses or skips with
// a report, never writes outside its folder and stays within its limits.
// The seed is fixed, so a run is reproducible; FUZZ_ITERATIONS raises the
// number of inputs (docs/development/fuzz-tests.md).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/zip_reader.dart';

final _iterations =
    int.tryParse(Platform.environment['FUZZ_ITERATIONS'] ?? '') ?? 40;

Uint8List _zip(Map<String, List<int>> files, {int level = 6}) {
  final archive = Archive();
  for (final MapEntry(key: name, value: bytes) in files.entries) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive, level: level));
}

/// [zip] with the uncompressed size of every entry set to [size] in the
/// local and the central headers: what a ZIP bomb or a damaged archive
/// declares.
Uint8List _withDeclaredSize(Uint8List zip, int size) {
  final out = Uint8List.fromList(zip);
  final data = ByteData.sublistView(out);
  for (var i = 0; i + 4 <= out.length; i++) {
    final sig = data.getUint32(i, Endian.little);
    if (sig == 0x04034b50 && i + 26 <= out.length) {
      data.setUint32(i + 22, size, Endian.little);
    } else if (sig == 0x02014b50 && i + 28 <= out.length) {
      data.setUint32(i + 24, size, Endian.little);
    }
  }
  return out;
}

List<int> _text(String s) => utf8.encode(s);

/// [json] with a few values swapped for values of another type, or a few
/// characters cut or added.
String _mutateJson(Random random, String json) {
  const values = [
    'null',
    '1',
    '-1',
    '"x"',
    '"../x"',
    '[]',
    '{}',
    'true',
    '[1]',
    '{"a":1}',
    '1e400',
    '""',
  ];
  var s = json;
  for (var k = 1 + random.nextInt(4); k > 0; k--) {
    final matches = RegExp(
      r'(?<=:)\s*("(?:[^"\\]|\\.)*"|-?\d+|true|false|null|\[\]|\{\})',
    ).allMatches(s).toList();
    if (matches.isNotEmpty && random.nextInt(4) != 0) {
      final m = matches[random.nextInt(matches.length)];
      s = s.replaceRange(m.start, m.end, values[random.nextInt(values.length)]);
    } else if (s.isNotEmpty) {
      final at = random.nextInt(s.length);
      s = random.nextBool()
          ? s.replaceRange(at, min(s.length, at + random.nextInt(5)), '')
          : s.replaceRange(at, at, '{["\\,:');
    }
  }
  return s;
}

void main() {
  final examples = [
    for (final f
        in Directory('../docs/examples')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.zip'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      f.readAsBytesSync(),
  ];

  group('readZipFiles', () {
    test('reads the files of an archive', () {
      final files = readZipFiles(
        _zip({'a.cho': _text('{title: A}'), 'b/c.pdf': _text('%PDF-1.4')}),
      );
      expect([for (final (name, _) in files) name], ['a.cho', 'b/c.pdf']);
    });

    test('refuses more files than maxZipEntries', () {
      final zip = _zip({
        for (var i = 0; i <= maxZipEntries; i++) '$i': const <int>[],
      }, level: 0);
      expect(() => readZipFiles(zip), throwsA(isA<ArchiveTooLargeException>()));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('refuses a file that declares more than maxZipEntryBytes', () {
      final zip = _withDeclaredSize(
        _zip({'a.cho': _text('{title: A}')}),
        maxZipEntryBytes + 1,
      );
      expect(() => readZipFiles(zip), throwsA(isA<ArchiveTooLargeException>()));
    });

    test('refuses a zip64-sized file without a limit', () {
      final zip = _withDeclaredSize(_zip({'a': _text('x')}), 0xFFFFFFFF);
      expect(() => readZipFiles(zip), throwsA(isA<ArchiveTooLargeException>()));
    });

    test('refuses a ZIP bomb: far more content than archive', () {
      // 2 × 40 MB of zeros compress to about 80 KB: each file is under
      // maxZipEntryBytes, together they are far over the ratio.
      final zip = _zip({
        'a.cho': Uint8List(40 * 1024 * 1024),
        'b.cho': Uint8List(40 * 1024 * 1024),
      });
      expect(zip.length, lessThan(200 * 1024));
      expect(() => readZipFiles(zip), throwsA(isA<ArchiveTooLargeException>()));
    });

    test('a file larger than it declares is refused, not read whole', () {
      final zip = _withDeclaredSize(
        _zip({'a.cho': Uint8List(1024 * 1024)}),
        10,
      );
      expect(() => readZipFiles(zip), throwsA(isA<FormatException>()));
    });

    test('a file with a wrong checksum is refused', () {
      final zip = _zip({'a.cho': _text('{title: A}')}, level: 0);
      // The stored content follows the local header and the name.
      zip[30 + 'a.cho'.length] ^= 0xFF;
      expect(() => readZipFiles(zip), throwsA(anything));
    });

    test('no ZIP is refused', () {
      for (final bytes in [<int>[], _text('PK\x03\x04no'), _text('text')]) {
        expect(
          () => readZipFiles(Uint8List.fromList(bytes)),
          throwsA(anything),
          reason: '$bytes',
        );
      }
    });

    test('duplicate names are one file', () {
      final archive = Archive()
        ..addFile(ArchiveFile('a.cho', 1, [0x41]))
        ..addFile(ArchiveFile('a.cho', 1, [0x42]));
      final files = readZipFiles(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      expect(files.length, lessThanOrEqualTo(2));
      expect({for (final (name, _) in files) name}, {'a.cho'});
    });
  });

  group('imports', () {
    late AppDatabase db;
    late Directory root;
    late Directory dir;
    late SongRepository songs;
    late BackupService backup;
    late ImportExportService imports;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      root = Directory.systemTemp.createTempSync('setding_fuzz');
      dir = Directory(p.join(root.path, 'deep', 'attachments'))
        ..createSync(recursive: true);
      final storage = FileAttachmentStorage(dir);
      songs = SongRepository(db, storage);
      backup = BackupService(db, storage);
      imports = ImportExportService(songs, SetRepository(db, storage));
    });
    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    /// Every file below [root] that is not in the attachment folder.
    List<String> outside() => [
      for (final f in root.listSync(recursive: true).whereType<File>())
        if (!p.isWithin(dir.path, f.path)) f.path,
    ];

    // #1244: replacing the library kept the attachment ID of the archive,
    // and the file is named after it: `../../escaped` was written two
    // folders above the attachment folder.
    test('an attachment ID from the archive never leaves the folder', () async {
      final song = await songs.createSong(source: '{title: Hello}\n[C]Hi');
      await songs.addAttachment(
        song,
        name: 'Score',
        bytes: Uint8List.fromList(_text('%PDF-1.4 score')),
      );
      final contents = BackupService.read(
        await backup.export(localBandId, libraryName: 'Here'),
      );
      final read = await contents;
      final manifest = {
        ...read.manifest,
        'songs': [
          for (final s in read.songs)
            {
              ...s,
              'attachments': [
                for (final a in BackupService.attachmentsOf(s))
                  {...a, 'id': '../../escaped'},
              ],
            },
        ],
      };
      final result = await backup.replaceLocal(
        BackupContents(manifest, read.files),
      );
      expect(result.files, 1);
      expect(outside(), isEmpty);
      final stored = await db.select(db.attachments).getSingle();
      expect(stored.id, isNot(contains('/')));
      expect(File(p.join(dir.path, stored.fileName)).existsSync(), isTrue);
    });

    test('isArchiveId accepts record IDs only', () {
      expect(isArchiveId('3f9c1e5a-2b7d-4c8e-9f10-1a2b3c4d5e6f'), isTrue);
      expect(isArchiveId('abc123def456ghi'), isTrue);
      for (final id in [
        '',
        '../x',
        '/etc/x',
        r'..\x',
        'a b',
        'a.b',
        'é',
        'x' * 65,
      ]) {
        expect(isArchiveId(id), isFalse, reason: id);
      }
    });

    test('odd and hostile names import as songs, nothing is written', () async {
      final zip = _zip({
        '../../evil.cho': _text('{title: Up}'),
        '/abs/olute.cho': _text('{title: Absolute}'),
        r'C:\win\dows.cho': _text('{title: Windows}'),
        r'a\..\..\back.cho': _text('{title: Back}'),
        '${'long' * 200}.cho': _text('{title: Long}'),
        'ctrl\u0001\u007f.cho': _text('{title: Control}'),
        'emoji 😀 日本.cho': _text('{title: Emoji}'),
        'folder/': const [],
        '.hidden.cho': _text('{title: Hidden}'),
        '__MACOSX/._x.cho': _text('meta'),
        'inner.zip': _zip({'nested.cho': _text('{title: Nested}')}),
        'deep/${'d/' * 200}deep.cho': _text('{title: Deep}'),
      });
      final result = await imports.importFiles([ImportFile('x.zip', zip)]);
      expect(result.imported, 8);
      // A ZIP in the ZIP is not unpacked.
      expect(result.skipped, ['inner.zip']);
      expect(outside(), isEmpty);
      expect(dir.listSync(), isEmpty);
      final titles = {for (final s in await db.select(db.songs).get()) s.title};
      expect(titles, containsAll(['Up', 'Absolute', 'Windows', 'Back']));
      expect(titles, isNot(contains('Hidden')));
      expect(titles, isNot(contains('Nested')));
    });

    test('a backslash name is cut to its file name (#1244)', () async {
      final zip = _zip({r'songs\sub\Hello.cho': _text('[C]Hi')});
      final result = await imports.importFiles([ImportFile('x.zip', zip)]);
      expect(result.imported, 1);
      final song = await db.select(db.songs).getSingle();
      expect(song.title, 'Hello');
    });

    // #1244: a damaged ZIP aborted the whole import with a raw error; now
    // it is skipped and the other files are imported.
    test('a damaged or oversized ZIP is skipped, the rest imported', () async {
      final bomb = _zip({'bomb.cho': Uint8List(80 * 1024 * 1024)});
      final result = await imports.importFiles([
        ImportFile('a.cho', Uint8List.fromList(_text('{title: A}'))),
        ImportFile('broken.zip', Uint8List.fromList(_text('PK\x03\x04no'))),
        ImportFile('bomb.zip', bomb),
        ImportFile('b.cho', Uint8List.fromList(_text('{title: B}'))),
      ]);
      expect(result.imported, 2);
      expect(result.skipped, ['broken.zip', 'bomb.zip']);
    });

    // #1244: a damaged archive or a manifest of the wrong shape threw
    // archive or type errors from readFull, which the restore did not
    // catch.
    test('readFull refuses damaged archives and odd manifests', () async {
      Uint8List manifest(Object json) =>
          _zip({backupManifestName: _text(jsonEncode(json))});
      final full = {'format': backupFormat, 'formatVersion': 2};
      for (final zip in [
        Uint8List(0),
        Uint8List.fromList(_text('PK\x05\x06')),
        examples.first.sublist(0, examples.first.length ~/ 2),
        manifest({...full, 'libraries': 'x'}),
        manifest({
          ...full,
          'libraries': [1],
        }),
        manifest({
          ...full,
          'libraries': [
            {'path': 3},
          ],
        }),
      ]) {
        await expectLater(
          BackupService.readFull(zip),
          throwsA(isA<BackupFormatException>()),
        );
      }
      await expectLater(
        BackupService.readFull(_zip({'bomb': Uint8List(80 * 1024 * 1024)})),
        throwsA(isA<ArchiveTooLargeException>()),
      );
    });

    /// A library with a song with a PDF and an image, an adjustment and a
    /// set; its archives of every kind, next to the example archives.
    Future<List<Uint8List>> ownArchives() async {
      final sets = SetRepository(db, songs.storage);
      final song = await songs.createSong(
        source: '{title: Hello}\n{image: logo.png}\n[C]Hi',
      );
      final pdf = await songs.addAttachment(
        song,
        name: 'Score',
        bytes: Uint8List.fromList(_text('%PDF-1.4 score')),
      );
      await songs.addAttachment(
        song,
        name: 'logo.png',
        bytes: Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0,
          0,
          0,
          0,
        ]),
        extension: 'png',
      );
      await songs.updateOverlay(
        song,
        (o) => o.copyWith(transpose: 2, liveView: Value(pdf)),
      );
      final set = await sets.createSet(name: 'Gig');
      await sets.addSongs(set, [song]);
      return [
        await backup.export(localBandId, libraryName: 'Here'),
        await backup.exportAll(
          libraries: [(id: localBandId, name: 'Here')],
          personalSettings: const {'fontScale': 1.2},
        ),
        await SongArchiveService(backup).export([song]),
        await SetArchiveService(backup).export(set),
      ];
    }

    // #1244: a field of another type (a title that is an object) passed
    // the read and threw a type error in the preview, or in the build of
    // the import dialog.
    test('a manifest with a field of another type is refused', () async {
      Uint8List songs(List<Object?> list) => _zip({
        backupManifestName: _text(
          jsonEncode({
            'format': songArchiveFormat,
            'formatVersion': songArchiveFormatVersion,
            'songs': list,
          }),
        ),
      });
      expect(
        await SongArchiveService.read(
          songs([
            {'id': 's1', 'title': 'Fine', 'attachments': <Object>[]},
          ]),
        ),
        isNotNull,
      );
      for (final list in [
        [
          {'id': 's1', 'title': <String, Object>{}},
        ],
        [
          {'title': 'No ID'},
        ],
        [1],
        [
          {
            'id': 's1',
            'attachments': [
              {'id': 'a1', 'pages': 'two'},
            ],
          },
        ],
        [
          {
            'id': 's1',
            'attachments': ['a1'],
          },
        ],
      ]) {
        expect(
          await SongArchiveService.read(songs(list)),
          isNull,
          reason: '$list',
        );
      }
    });

    test('mutated archives are read or refused, never more', () async {
      final random = Random(1244);
      final pool = [...examples, ...await ownArchives()];
      final songArchives = SongArchiveService(backup);
      final setArchives = SetArchiveService(backup);
      Future<void> imported(Uint8List bytes) async {
        // A backup: its preview and both ways to import it.
        FullBackup? full;
        try {
          full = await BackupService.readFull(bytes);
        } on BackupFormatException {
          // Refused.
        } on ArchiveTooLargeException {
          // Refused.
        }
        for (final library in full?.libraries ?? const <BackupContents>[]) {
          await backup.preview(library, localBandId);
          await backup.import(
            library,
            libraryId: localBandId,
            bands: {
              for (final b in library.bands) b['id'] as String: localBandId,
            },
          );
          await backup.replaceLocal(library);
        }
        for (final personal in full?.personal ?? const <PersonalBackup>[]) {
          await backup.restorePersonal(personal);
        }
        try {
          if (await SongArchiveService.read(bytes) case final archive?) {
            await songArchives.preview(archive, libraryId: localBandId);
            await songArchives.import(archive, libraryId: localBandId);
          }
          if (await SetArchiveService.read(bytes) case final archive?) {
            String copy(String name, int n) => '$name $n';
            await setArchives.preview(
              archive,
              bandId: localBandId,
              canCreateSongs: true,
              copyName: copy,
            );
            await setArchives.import(
              archive,
              bandId: localBandId,
              canCreateSongs: true,
              missingNote: (title) => title,
              copyName: copy,
            );
          }
        } on BackupFormatException catch (e) {
          expect(e.newerVersion, isNotNull);
        }
        // A damaged archive is skipped with a report.
        await imports.importFiles([ImportFile('x.zip', bytes)]);
      }

      for (var i = 0; i < _iterations; i++) {
        final source = pool[random.nextInt(pool.length)];
        var bytes = Uint8List.fromList(source);
        switch (random.nextInt(5)) {
          case 0:
            for (var k = 1 + random.nextInt(20); k > 0; k--) {
              bytes[random.nextInt(bytes.length)] = random.nextInt(256);
            }
          case 1:
            // Damage the central directory at the end.
            for (var k = 1 + random.nextInt(8); k > 0; k--) {
              final at =
                  bytes.length - 1 - random.nextInt(min(400, bytes.length));
              bytes[at] = random.nextInt(256);
            }
          case 2:
            final cut = random.nextInt(bytes.length);
            bytes.setRange(cut, bytes.length, Uint8List(bytes.length - cut));
          default:
            // A valid archive with a damaged manifest.
            final files = {
              for (final (name, content) in readZipFiles(bytes)) name: content,
            };
            for (final name in [
              for (final n in files.keys)
                if (n.endsWith(backupManifestName)) n,
            ]) {
              files[name] = utf8.encode(
                _mutateJson(
                  random,
                  utf8.decode(files[name]!, allowMalformed: true),
                ),
              );
            }
            bytes = _zip(files);
        }
        final watch = Stopwatch()..start();
        try {
          await imported(bytes);
        } catch (e, stack) {
          fail('threw $e on input $i\n$stack');
        }
        expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
      }
      expect(outside(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
