import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_archive.dart';
import 'package:setding/data/song_repository.dart';

/// Song archive of ADR-0043 §1c (#792).
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 score'.codeUnits);
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  late SongRepository songs;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_song_archive');
    storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  SongArchiveService service([AppDatabase? on]) =>
      SongArchiveService(BackupService(on ?? db, storage, appVersion: '1.2.3'));

  bool any(SongEntry _) => true;

  /// "Hello" with two attachments, an adjustment and a band arrangement,
  /// and "Bye" without a title directive.
  Future<({String hello, String bye})> fill() async {
    final hello = await songs.createSong(
      source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world',
    );
    await songs.addAttachment(hello, name: 'Score', bytes: pdf, pages: 1);
    await songs.addAttachment(
      hello,
      name: 'Photo',
      bytes: png,
      extension: 'png',
    );
    await songs.updateOverlay(
      hello,
      (o) => o.copyWith(notes: const Value('Slow intro')),
    );
    await ArrangementRepository(db).save(localBandId, hello, transpose: -2);
    final bye = await songs.createSong(source: '[G]Bye', title: 'Bye');
    return (hello: hello, bye: bye);
  }

  Map<String, Uint8List> unzip(Uint8List zip) => {
    for (final f in ZipDecoder().decodeBytes(zip).files)
      if (f.isFile) f.name: Uint8List.fromList(f.content),
  };

  test(
    'the archive holds the songs, their attachments and a manifest',
    () async {
      final ids = await fill();
      final files = unzip(
        await service().export([ids.hello, ids.bye], now: DateTime(2027)),
      );
      final manifest = jsonDecode(
        utf8.decode(files[backupManifestName]!),
      ) as Map<String, dynamic>;
      expect(manifest['format'], songArchiveFormat);
      expect(manifest['formatVersion'], 1);
      expect(manifest['app'], '1.2.3');
      expect(manifest['options'], {
        'attachments': true,
        'arrangements': false,
        'personal': false,
      });
      final list = (manifest['songs'] as List).cast<Map<String, dynamic>>();
      expect([for (final s in list) s['title']], ['Hello', 'Bye']);
      expect(list.first['id'], ids.hello);
      final attachments = (list.first['attachments'] as List)
          .cast<Map<String, dynamic>>();
      expect([for (final a in attachments) a['name']], ['Photo', 'Score']);
      expect(files[attachments.last['file']], pdf);
      expect(files[attachments.first['file']], png);
      // ChordPro files readable without setDING, with the title added.
      expect(utf8.decode(files[list.last['file']]!), contains('{title: Bye}'));
      expect(manifest['arrangements'], isEmpty);
      expect(manifest['overlays'], isEmpty);
    },
  );

  test('the options add arrangements of the band and the own adjustments, '
      'or leave out the attachments', () async {
    final ids = await fill();
    var files = unzip(
      await service().export(
        [ids.hello],
        options: const SongArchiveOptions(
          attachments: false,
          arrangements: true,
          personal: true,
        ),
        bandId: localBandId,
      ),
    );
    var manifest = jsonDecode(
      utf8.decode(files[backupManifestName]!),
    ) as Map<String, dynamic>;
    expect(files.keys.where((f) => f.startsWith('attachments/')), isEmpty);
    expect(
      (manifest['arrangements'] as List).single,
      containsPair('transpose', -2),
    );
    expect(
      (manifest['overlays'] as List).single,
      containsPair('notes', 'Slow intro'),
    );
    expect(manifest['options'], {
      'attachments': false,
      'arrangements': true,
      'personal': true,
    });

    // Without a band there are no arrangements, and the options say so.
    files = unzip(
      await service().export([
        ids.hello,
      ], options: const SongArchiveOptions(arrangements: true)),
    );
    manifest = jsonDecode(
      utf8.decode(files[backupManifestName]!),
    ) as Map<String, dynamic>;
    expect(manifest['arrangements'], isEmpty);
    expect((manifest['options'] as Map)['arrangements'], isFalse);
  });

  test('a missing attachment file aborts the export', () async {
    final ids = await fill();
    expect(
      () => service().export([ids.hello], readFile: (_) async => null),
      throwsA(isA<BackupFileMissingException>()),
    );
  });

  test('only song archives are read as such', () async {
    final ids = await fill();
    final zip = await service().export([ids.hello]);
    expect(await SongArchiveService.read(zip), isNotNull);
    expect(await SetArchiveService.read(zip), isNull);
    expect(await BackupService.isBackup(zip), isFalse);
    expect(await SongArchiveService.read(Uint8List(3)), isNull);

    final set = await SetRepository(db, storage).createSet(name: 'Gig');
    final setZip = await SetArchiveService(BackupService(db, storage))
        .export(set);
    expect(await SongArchiveService.read(setZip), isNull);

    final newer = ZipEncoder().encode(
      Archive()..addFile(
        ArchiveFile.bytes(
          backupManifestName,
          utf8.encode(
            jsonEncode({'format': songArchiveFormat, 'formatVersion': 99}),
          ),
        ),
      ),
    );
    expect(
      () => SongArchiveService.read(Uint8List.fromList(newer)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a round trip into another library adds the songs with new ids and '
      'their attachments, arrangements and adjustments', () async {
    final ids = await fill();
    final zip = await service().export(
      [ids.hello, ids.bye],
      options: const SongArchiveOptions(arrangements: true, personal: true),
      bandId: localBandId,
    );
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final archive = (await SongArchiveService.read(zip))!;
    expect(archive.titles, ['Hello', 'Bye']);
    expect(archive.holds, SongArchiveOptions.all);
    final target = service(other);
    final preview = await target.preview(
      archive,
      libraryId: localBandId,
      canEditSong: any,
      bandId: localBandId,
    );
    expect(
      (preview.songs, preview.added, preview.identical, preview.differing),
      (2, 2, 0, 0),
    );
    expect(preview.attachmentsAdded, 0);

    final result = await target.import(
      archive,
      libraryId: localBandId,
      canEditSong: any,
      bandId: localBandId,
    );
    expect(result.songs.imported, hasLength(2));
    expect(result.songs.files, 2);
    expect(result.arrangements, 1);
    final repo = SongRepository(other, storage);
    final hello = result.songs.songIds[ids.hello]!;
    expect(hello, isNot(ids.hello));
    expect([for (final a in await repo.getAttachments(hello)) a.name]..sort(), [
      'Photo',
      'Score',
    ]);
    expect((await repo.getOverlay(hello)).notes, 'Slow intro');
    expect(
      (await ArrangementRepository(other).get(localBandId, hello))!.transpose,
      -2,
    );
  });

  test(
    'importing again completes the attachments of the existing song',
    () async {
      final ids = await fill();
      final zip = await service().export([ids.hello]);
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final repo = SongRepository(other, storage);
      // The same song elsewhere, with only one of the attachments (another
      // case in the name).
      final existing = await repo.createSong(
        source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world',
      );
      await repo.addAttachment(existing, name: 'score', bytes: pdf);
      final archive = (await SongArchiveService.read(zip))!;
      final target = service(other);

      // Without the right to edit the song nothing is added.
      expect(
        (await target.preview(
          archive,
          libraryId: localBandId,
        )).attachmentsAdded,
        0,
      );
      final preview = await target.preview(
        archive,
        libraryId: localBandId,
        canEditSong: any,
      );
      expect((preview.identical, preview.added), (1, 0));
      expect(preview.attachmentsAdded, 1);

      final result = await target.import(
        archive,
        libraryId: localBandId,
        canEditSong: any,
      );
      expect(result.songs.imported, isEmpty);
      expect(result.songs.identical, 1);
      expect(result.songs.completed, 1);
      expect(
        [for (final a in await repo.getAttachments(existing)) a.name]..sort(),
        ['Photo', 'score'],
      );

      // A second import finds nothing missing.
      expect(
        (await target.preview(
          archive,
          libraryId: localBandId,
          canEditSong: any,
        )).attachmentsAdded,
        0,
      );
    },
  );

  test(
    'without the attachments option existing songs stay unchanged',
    () async {
      final ids = await fill();
      final zip = await service().export([ids.hello]);
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final repo = SongRepository(other, storage);
      final existing = await repo.createSong(
        source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world',
      );
      final result = await service(other).import(
        (await SongArchiveService.read(zip))!,
        libraryId: localBandId,
        options: const SongArchiveOptions(attachments: false),
        canEditSong: any,
      );
      expect(result.songs.completed, 0);
      expect(await repo.getAttachments(existing), isEmpty);
    },
  );

  test('a song with a different text is kept or added as chosen', () async {
    final ids = await fill();
    final zip = await service().export([ids.hello]);
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final repo = SongRepository(other, storage);
    await repo.createSong(source: '{title: Hello}\n{artist: Band}\n[D]Other');
    final archive = (await SongArchiveService.read(zip))!;
    final target = service(other);
    expect(
      (await target.preview(archive, libraryId: localBandId)).differing,
      1,
    );
    var result = await target.import(archive, libraryId: localBandId);
    expect((result.songs.keptExisting, result.songs.imported.length), (1, 0));
    result = await target.import(
      archive,
      libraryId: localBandId,
      duplicates: BackupDuplicates.addAll,
    );
    expect(result.songs.additional.single.title, 'Hello');
  });

  test('existing arrangements are kept unless overwriting is chosen', () async {
    final ids = await fill();
    final zip = await service().export(
      [ids.hello],
      options: const SongArchiveOptions(arrangements: true),
      bandId: localBandId,
    );
    final archive = (await SongArchiveService.read(zip))!;
    // Into the same library: the song is reused, its arrangement exists.
    await ArrangementRepository(db).save(localBandId, ids.hello, transpose: 5);
    final preview = await service().preview(
      archive,
      libraryId: localBandId,
      bandId: localBandId,
    );
    expect(preview.arrangementConflicts, 1);
    var result = await service().import(
      archive,
      libraryId: localBandId,
      bandId: localBandId,
    );
    expect(result.arrangements, 0);
    expect(
      (await ArrangementRepository(db).get(localBandId, ids.hello))!.transpose,
      5,
    );
    result = await service().import(
      archive,
      libraryId: localBandId,
      bandId: localBandId,
      overwriteArrangements: true,
    );
    expect(result.arrangements, 1);
    expect(
      (await ArrangementRepository(db).get(localBandId, ids.hello))!.transpose,
      -2,
    );
  });

  test('the file name is the title of a single song, else dated', () async {
    final ids = await fill();
    final hello = (await songs.getSong(ids.hello))!;
    final bye = (await songs.getSong(ids.bye))!;
    expect(SongArchiveService.fileName([hello]), 'Hello.zip');
    expect(
      SongArchiveService.fileName([hello, bye], now: DateTime(2027, 3, 4)),
      'setDING-Songs 2027-03-04.zip',
    );
  });
  test('the documented example archive imports (docs/formats)', () async {
    // The example manifest of docs/formats/song-archive.md, as an external
    // tool would write it: own IDs, a PDF-only song.
    final manifest = jsonDecode(
      File('../docs/formats/song-archive-manifest.example.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    const cho =
        '{title: Amazing Grace}\n{artist: John Newton}\n{key: G}\n'
        '{ccli: 7012345}\n\n[G]Amazing [G7]grace, how [C]sweet the [G]sound\n';
    Uint8List zipOf(Map<String, dynamic> manifest) {
      final archive = Archive();
      void add(String name, List<int> bytes) =>
          archive.addFile(ArchiveFile.bytes(name, bytes));
      add(backupManifestName, utf8.encode(jsonEncode(manifest)));
      add('songs/Amazing Grace (7012345).cho', utf8.encode(cho));
      add('attachments/Amazing Grace (7012345) - Lead Sheet.pdf', pdf);
      add('attachments/Only a Score (7098765) - Score.pdf', pdf);
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    final archive = (await SongArchiveService.read(zipOf(manifest)))!;
    expect(archive.libraryName, 'CCLI SongSelect');
    expect(archive.titles, ['Amazing Grace', 'Only a Score']);
    final result = await service().import(
      archive,
      libraryId: localBandId,
      canEditSong: any,
    );
    expect(result.songs.imported, hasLength(2));
    expect(result.songs.files, 2);

    final grace = (await songs.getSong(result.songs.songIds['ccli-7012345']!))!;
    expect((grace.title, grace.artist), ('Amazing Grace', 'John Newton'));
    expect(grace.chordproSource, cho);
    final lead = (await songs.getAttachments(grace.id)).single;
    expect((lead.name, lead.pages), ('Lead Sheet', 2));

    final score = (await songs.getSong(result.songs.songIds['ccli-7098765']!))!;
    expect((score.title, score.artist), ('Only a Score', 'Some Writer'));
    expect(score.chordproSource, isEmpty);
    expect(
      [for (final a in await songs.getAttachments(score.id)) a.name],
      ['Score'],
    );

    // Running the exporter again with a new PDF completes the songs.
    final again = jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
    (((again['songs'] as List).first as Map)['attachments'] as List).add({
      'id': 'ccli-7012345-chords',
      'name': 'Chord Chart',
      'file': 'attachments/Only a Score (7098765) - Score.pdf',
    });
    final second = await service().import(
      (await SongArchiveService.read(zipOf(again)))!,
      libraryId: localBandId,
      canEditSong: any,
    );
    expect(second.songs.imported, isEmpty);
    expect(second.songs.completed, 1);
    expect(
      [for (final a in await songs.getAttachments(grace.id)) a.name]..sort(),
      ['Chord Chart', 'Lead Sheet'],
    );

    // Without options.attachments no attachments are imported.
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final bare = Map<String, dynamic>.of(manifest)..remove('options');
    final withoutOptions = await service(other).import(
      (await SongArchiveService.read(zipOf(bare)))!,
      libraryId: localBandId,
    );
    expect(withoutOptions.songs.imported, hasLength(2));
    expect(withoutOptions.songs.files, 0);
  });
}
