import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/data/song_repository.dart';

/// The example songs of the website (#923) as song archives, the app's own
/// export format (ADR-0043): `make examples` writes
/// `docs/examples/<name>.setDING.zip` from `<name>.cho` with
/// `--dart-define=WRITE_EXAMPLES=true`; otherwise the test checks that every
/// archive holds its current source and imports as one song.
const examples = [
  'chord-views-de',
  'chord-views-en',
  'beat-de',
  'beat-en',
  'sections-de',
  'sections-en',
  'personal-de',
  'personal-en',
];

const _write = bool.fromEnvironment('WRITE_EXAMPLES');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late AppDatabase db;
  late FileAttachmentStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('setding_examples');
    db = AppDatabase(NativeDatabase.memory());
    storage = FileAttachmentStorage(dir);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  SongArchiveService service() =>
      SongArchiveService(BackupService(db, storage));

  for (final name in examples) {
    test('$name.setDING.zip holds $name.cho', () async {
      final source = File('../docs/examples/$name.cho').readAsStringSync();
      final archive = File('../docs/examples/$name.setDING.zip');
      if (_write) {
        // Exported from a database of its own; [db] stays empty for the
        // import below.
        final from = AppDatabase(NativeDatabase.memory());
        addTearDown(from.close);
        final id = await SongRepository(
          from,
          storage,
        ).createSong(source: source);
        archive.writeAsBytesSync(
          await SongArchiveService(BackupService(from, storage))
              .export([id], now: DateTime.utc(2026)),
        );
      }
      expect(
        archive.existsSync(),
        isTrue,
        reason: 'missing, run make examples',
      );

      final read = (await SongArchiveService.read(archive.readAsBytesSync()))!;
      final song = read.contents.songs.single;
      expect(
        read.contents.sourceOf(song),
        source,
        reason: '$name.cho changed, run make examples',
      );

      final result = await service().import(read, libraryId: localBandId);
      expect(result.songs.imported, hasLength(1));
      final imported = await db.select(db.songs).getSingle();
      expect(imported.chordproSource, source);
    });
  }
}
