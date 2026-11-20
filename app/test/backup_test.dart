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
import 'package:setding/data/outbox.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';

/// Backup archive of ADR-0043.
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 score'.codeUnits);
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  late SongRepository songs;
  late SetRepository sets;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_backup');
    storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  BackupService service([AppDatabase? on]) =>
      BackupService(on ?? db, storage, appVersion: '1.2.3');

  /// A library with a song (attachment, adjustments, annotation, band
  /// arrangement), a PDF-only song and a set with a song and a pause.
  Future<({String song, String pdfOnly, String attachment})> fill() async {
    final song = await songs.createSong(
      source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world',
    );
    final attachment = await songs.addAttachment(
      song,
      name: 'Score',
      bytes: pdf,
      pages: 1,
    );
    await songs.updateOverlay(
      song,
      (o) => o.copyWith(
        transpose: 2,
        notes: const Value('Slow intro'),
        liveView: Value(attachment),
      ),
    );
    await db
        .into(db.annotations)
        .insert(
          AnnotationsCompanion.insert(
            id: 'stroke-1',
            ownerId: localOwnerId,
            songId: song,
            target: Value(attachment),
            stroke: const Value('{"kind":"pen"}'),
            updatedAt: 1,
          ),
        );
    await ArrangementRepository(db).save(localBandId, song, transpose: -2);
    final pdfOnly = await songs.createSong(title: 'Horns', artist: 'Brass');
    await songs.addAttachment(pdfOnly, name: 'Horns', bytes: pdf);
    final setId = await sets.createSet(
      name: 'Gig',
      gigDate: DateTime(2027, 6, 21),
      venue: 'Bern',
    );
    await sets.addSongs(setId, [song]);
    await sets.addMarker(setId, SetItemType.pause, 'Break');
    return (song: song, pdfOnly: pdfOnly, attachment: attachment);
  }

  Future<Map<String, Uint8List>> unzip(Uint8List zip) async => {
    for (final f in ZipDecoder().decodeBytes(zip).files)
      if (f.isFile) f.name: Uint8List.fromList(f.content),
  };

  test('the archive has a manifest, ChordPro files and attachments', () async {
    final ids = await fill();
    final zip = await service().export(
      localBandId,
      libraryName: 'On this device',
    );
    final files = await unzip(zip);
    final manifest = jsonDecode(
      utf8.decode(files['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(manifest['format'], 'setding-backup');
    expect(manifest['formatVersion'], 1);
    expect(manifest['app'], '1.2.3');
    expect(manifest['source'], {
      'kind': 'local',
      'id': localBandId,
      'name': 'On this device',
    });
    final cho = files.keys.where((k) => k.startsWith('songs/')).toList();
    expect(cho, hasLength(1), reason: 'the PDF-only song has no text');
    expect(cho.single, startsWith('songs/Hello ('));
    expect(utf8.decode(files[cho.single]!), contains('[C]Hello'));
    expect(files.keys.where((k) => k.startsWith('attachments/')), hasLength(2));
    expect(((manifest['overlays'] as List).single as Map)['songId'], ids.song);
    expect((manifest['annotations'] as List), hasLength(1));
    expect(((manifest['arrangements'] as List).single as Map)['transpose'], -2);
    expect(await BackupService.isBackup(zip), isTrue);
  });

  test('a round trip gives the same library with new IDs', () async {
    final ids = await fill();
    final zip = await service().export(localBandId, libraryName: 'Mine');

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final contents = await BackupService.read(zip);
    final result = await service(other).import(
      contents,
      libraryId: localBandId,
      bands: {localBandId: localBandId},
    );
    expect(result.imported, 2);
    expect(result.sets, 1);
    expect(result.files, 2);
    expect(result.additional, isEmpty);

    final copies = SongRepository(other, storage);
    final all = await other.select(other.songs).get();
    expect([for (final s in all) s.title]..sort(), ['Hello', 'Horns']);
    final hello = all.firstWhere((s) => s.title == 'Hello');
    expect(hello.id, isNot(ids.song));
    expect(hello.artist, 'Band');
    expect(hello.chordproSource, contains('[C]Hello'));
    final horns = all.firstWhere((s) => s.title == 'Horns');
    expect(horns.artist, 'Brass');
    final score = (await copies.getAttachments(hello.id)).single;
    expect(score.id, isNot(ids.attachment));
    expect(score.pages, 1);
    expect(await storage.file(score.fileName).readAsBytes(), pdf);
    final overlay = await copies.getOverlay(hello.id);
    expect(overlay.transpose, 2);
    expect(overlay.notes, 'Slow intro');
    expect(overlay.liveView, score.id, reason: 'mapped to the copy');
    final strokes = await other.select(other.annotations).get();
    expect(strokes.single.songId, hello.id);
    expect(strokes.single.target, score.id);
    final arrangement = await ArrangementRepository(other)
        .get(localBandId, hello.id);
    expect(arrangement!.transpose, -2);
    final set = await other.select(other.setlists).getSingle();
    expect(
      (set.name, set.venue, set.gigDate),
      ('Gig', 'Bern', DateTime(2027, 6, 21)),
    );
    final items = await SetRepository(other, storage).getItems(set.id);
    expect(
      [for (final i in items) i.song?.title ?? i.item.note],
      ['Hello', 'Break'],
    );
  });

  test('identical songs are not imported again', () async {
    await fill();
    final zip = await service().export(localBandId, libraryName: 'Mine');
    final contents = await BackupService.read(zip);
    final preview = await service().preview(contents, localBandId);
    expect((preview.songs, preview.identical, preview.differing), (2, 2, 0));

    final result = await service().import(
      contents,
      libraryId: localBandId,
      bands: {localBandId: localBandId},
    );
    expect(result.imported, 0);
    expect(result.identical, 2);
    expect(await db.select(db.songs).get(), hasLength(2));
    // The set is added and points to the existing song.
    final added = (await sets.watchSets().first).map((s) => s.set.name);
    expect(added, ['Gig', 'Gig']);
  });

  group('songs with a different text', () {
    late BackupContents contents;
    late String original;

    setUp(() async {
      original = (await fill()).song;
      contents = await BackupService.read(
        await service().export(localBandId, libraryName: 'Mine'),
      );
      await songs.updateSource(
        original,
        '{title: Hello}\n{artist: Band}\n[D]Changed',
      );
    });

    test('are found by ID or by title and artist', () async {
      final preview = await service().preview(contents, localBandId);
      expect((preview.identical, preview.differing), (1, 1));
    });

    test('keep the existing song', () async {
      final result = await service().import(
        contents,
        libraryId: localBandId,
        bands: const {},
        duplicates: BackupDuplicates.keepExisting,
      );
      expect((result.imported, result.keptExisting), (0, 1));
      expect(
        (await songs.getSong(original))!.chordproSource,
        contains('Changed'),
      );
    });

    test('are imported as additional songs and listed', () async {
      final result = await service().import(
        contents,
        libraryId: localBandId,
        bands: const {},
        duplicates: BackupDuplicates.addAll,
      );
      expect(result.imported, 1);
      expect(result.additional.single.title, 'Hello');
      final copy = await songs.getSong(result.additional.single.id);
      expect(copy!.chordproSource, contains('[C]Hello'));
      expect(
        (await songs.getSong(original))!.chordproSource,
        contains('Changed'),
        reason: 'nothing existing is changed',
      );
      expect(await sets.watchSets().first, hasLength(1), reason: 'skipped');
    });
  });

  test('an import into an organization is synced', () async {
    await fill();
    final zip = await service().export(localBandId, libraryName: 'Mine');
    await db
        .into(db.bands)
        .insert(BandsCompanion.insert(id: 'b1', name: 'Rock'));
    final result = await BackupService(db, storage, userId: 'ann').import(
      await BackupService.read(zip),
      libraryId: 'o1',
      bands: {localBandId: 'b1'},
    );
    expect(result.imported, 2);
    final outbox = await db.select(db.syncOutbox).get();
    expect(
      outbox.where((e) => e.collection == SyncCollection.songs),
      hasLength(2),
    );
    expect(
      outbox.where((e) => e.collection == SyncCollection.setlists),
      hasLength(1),
    );
    expect(
      outbox.where((e) => e.collection == SyncCollection.overlays),
      hasLength(1),
    );
    final overlay = await db.select(db.personalOverlays).get();
    expect(overlay.where((o) => o.ownerId == 'ann'), hasLength(1));
  });

  test('plain ZIPs and newer backups are recognized', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('a.cho', 3, utf8.encode('{t}')));
    final plain = Uint8List.fromList(ZipEncoder().encode(archive));
    expect(await BackupService.isBackup(plain), isFalse);
    await expectLater(
      BackupService.read(plain),
      throwsA(isA<BackupFormatException>()),
    );

    final manifest = utf8.encode(
      jsonEncode({'format': 'setding-backup', 'formatVersion': 99}),
    );
    final newer = Uint8List.fromList(
      ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)),
      ),
    );
    expect(await BackupService.isBackup(newer), isTrue);
    await expectLater(
      BackupService.read(newer),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.newerVersion,
          'newerVersion',
          99,
        ),
      ),
    );
  });

  test('a missing attachment file stops the export', () async {
    final ids = await fill();
    final a = (await songs.getAttachments(ids.song)).single;
    await storage.delete(a.fileName);
    await expectLater(
      service().export(localBandId, libraryName: 'Mine'),
      throwsA(isA<BackupFileMissingException>()),
    );
  });

  group('before an organization export', () {
    late SongRepository org;

    setUp(() {
      org = SongRepository(db, storage, libraryId: 'o1');
    });

    test('pending changes block it', () async {
      await org.createSong(source: '{title: New}');
      expect(await service().blocker('o1'), BackupBlocker.pendingChanges);
      expect(await service().blocker(localBandId), isNull);
    });

    test('conflicts block it', () async {
      final id = await org.createSong(source: '{title: A}');
      await db.delete(db.syncOutbox).go();
      await db
          .into(db.songConflicts)
          .insert(
            SongConflictsCompanion.insert(
              songId: id,
              title: 'A',
              chordproSource: '{title: A}',
              revision: 2,
              detectedAt: DateTime.now(),
            ),
          );
      expect(await service().blocker('o1'), BackupBlocker.conflicts);
    });

    test('missing files block it, except on the web client', () async {
      final id = await org.createSong(source: '{title: A}');
      await org.addAttachment(id, name: 'Score', bytes: pdf);
      await db.delete(db.syncOutbox).go();
      expect(await service().blocker('o1'), isNull);
      await storage.delete((await org.getAttachments(id)).single.fileName);
      expect(await service().blocker('o1'), BackupBlocker.missingFiles);
      expect(await service().blocker('o1', checkFiles: false), isNull);
    });
  });
}
