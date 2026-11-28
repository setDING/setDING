import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';

import 'test_attachments.dart';

/// Replacing the local library by a backup (ADR-0054 section 2).
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 score'.codeUnits);
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  late SongRepository songs;
  late SetRepository sets;
  late BackupService service;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_replace');
    storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
    service = BackupService(db, storage);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// A local library with a song (attachment, adjustment, annotation,
  /// arrangement, language version), a second version and a past set.
  Future<({String song, String other, String attachment, String set})>
  fill() async {
    final song = await songs.createSong(source: '{title: Hello}\n[C]Hello');
    final other = await songs.createSong(source: '{title: Hallo}\n[C]Hallo');
    await songs.setWorkId(song, 'work-1');
    await songs.setWorkId(other, 'work-1');
    final attachment = await songs.addAttachment(
      song,
      name: 'Score',
      bytes: pdf,
    );
    await songs.updateOverlay(
      song,
      (o) => o.copyWith(transpose: 2, liveView: Value(attachment)),
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
    final set = await sets.createSet(
      name: 'Gig',
      gigDate: DateTime(2026, 6, 21),
    );
    await sets.addSongs(set, [song]);
    await db
        .update(db.setItems)
        .write(const SetItemsCompanion(played: Value(PlayedValues(key: 'D'))));
    return (song: song, other: other, attachment: attachment, set: set);
  }

  Future<BackupContents> backup({String? device}) async => BackupService.read(
    await service.export(
      localBandId,
      libraryName: 'On this device',
      device: device,
    ),
  );

  test('only archives of a local library can replace it', () async {
    await fill();
    final local = await backup(device: 'Tab');
    expect(BackupService.isLocalArchive(local), isTrue);
    expect(local.device, 'Tab');
    expect(local.createdAt, isNotNull);
    final org = BackupContents({
      ...local.manifest,
      'source': {'kind': 'organization', 'id': 'o1', 'name': 'School'},
    }, local.files);
    expect(BackupService.isLocalArchive(org), isFalse);
  });

  test('a PDF over 1 MB is skipped and named (ADR-0070)', () async {
    final ids = await fill();
    await addOldPdf(db, storage, ids.song, name: 'Big');
    final contents = await backup();
    final result = await service.replaceLocal(contents);
    expect(result.files, 1);
    expect(
      [for (final f in result.skippedFiles) (f.song, f.name)],
      [('Hello', 'Big')],
    );
  });

  test('the library is replaced with the original IDs', () async {
    final ids = await fill();
    final contents = await backup();
    // Changes after the backup: a new song, a deleted song in the trash,
    // a changed text and a new set.
    final added = await songs.createSong(source: '{title: New}');
    final trashed = await songs.createSong(source: '{title: Gone}');
    await songs.deleteSong(trashed);
    await songs.updateSource(ids.other, '{title: Hallo}\n[G]Neu');
    await sets.createSet(name: 'Later');
    final before = await service.localCounts();
    expect(before, (songs: 3, sets: 2));

    final result = await service.replaceLocal(contents);
    expect(result.imported, 2);
    expect(result.sets, 1);
    expect(result.files, 1);

    final all = await db.select(db.songs).get();
    expect({for (final s in all) s.id}, {ids.song, ids.other});
    expect(all.every((s) => !s.deleted), isTrue, reason: 'the trash is empty');
    expect(
      all.firstWhere((s) => s.id == ids.other).chordproSource,
      contains('[C]Hallo'),
    );
    expect({for (final s in all) s.workId}, {'work-1'});
    expect(await songs.getSong(added), isNull);

    final attachment = await (db.select(
      db.attachments,
    )..where((a) => a.id.equals(ids.attachment))).getSingle();
    expect(attachment.songId, ids.song);
    expect(await storage.exists(attachment.fileName), isTrue);

    final overlay = await songs.getOverlay(ids.song);
    expect(overlay.transpose, 2);
    expect(overlay.liveView, ids.attachment);
    final stroke = await db.select(db.annotations).getSingle();
    expect(stroke.id, 'stroke-1');
    expect(stroke.target, ids.attachment);
    expect(
      (await ArrangementRepository(db).get(localBandId, ids.song))?.transpose,
      -2,
    );

    final restoredSets = await db.select(db.setlists).get();
    expect([for (final s in restoredSets) s.id], [ids.set]);
    // The play history of the local band comes with its sets (ADR-0046).
    final item = await db.select(db.setItems).getSingle();
    expect(item.songId, ids.song);
    expect(item.played?.key, 'D');
    expect(await service.localCounts(), (songs: 2, sets: 1));
    // Nothing to sync: the local library is never on the server.
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });

  test('files of removed attachments are deleted', () async {
    final song = await songs.createSong(source: '{title: A}');
    final contents = await backup();
    final attachment = await songs.addAttachment(song, name: 'X', bytes: pdf);
    final file = (await (db.select(
      db.attachments,
    )..where((a) => a.id.equals(attachment))).getSingle()).fileName;
    expect(await storage.exists(file), isTrue);
    await service.replaceLocal(contents);
    expect(await storage.exists(file), isFalse);
    expect(await db.select(db.attachments).get(), isEmpty);
  });

  test(
    'organizations are not touched; an ID used there gets a new one',
    () async {
      await db
          .into(db.organizations)
          .insert(OrganizationsCompanion.insert(id: 'o1', name: 'School'));
      final orgSongs = SongRepository(db, storage, libraryId: 'o1');
      final orgSong = await orgSongs.createSong(source: '{title: Org}');
      final local = await songs.createSong(source: '{title: Local}');
      final contents = await backup();
      // The archive's song has the ID of the organization's song.
      final manifest = {
        ...contents.manifest,
        'songs': [
          for (final s in contents.songs)
            if (s['id'] == local) {...s, 'id': orgSong} else s,
        ],
      };
      await service.replaceLocal(BackupContents(manifest, contents.files));
      final org = await (db.select(
        db.songs,
      )..where((s) => s.id.equals(orgSong))).getSingle();
      expect(org.libraryId, 'o1');
      expect(org.title, 'Org');
      final restored = await (db.select(
        db.songs,
      )..where((s) => s.libraryId.equals(localBandId))).getSingle();
      expect(restored.title, 'Local');
      expect(restored.id, isNot(orgSong));
    },
  );

  test('an empty backup empties the local library', () async {
    final contents = await backup();
    await fill();
    final result = await service.replaceLocal(contents);
    expect(result.imported, 0);
    expect(await service.localCounts(), (songs: 0, sets: 0));
    expect(await db.select(db.personalOverlays).get(), isEmpty);
    expect(await db.select(db.annotations).get(), isEmpty);
    expect(await db.select(db.bandArrangements).get(), isEmpty);
  });

  // Regression (#876): replacing created every song again, so each got the
  // restore time and all of them showed as *Newest songs*.
  test('restored songs keep when they were created', () async {
    final song = await songs.createSong(source: '{title: Old}');
    final created = DateTime(2025, 3, 4, 5, 6);
    await (db.update(db.songs)..where((s) => s.id.equals(song))).write(
      SongsCompanion(createdAt: Value(created)),
    );
    final contents = await backup();
    await service.replaceLocal(contents);
    final restored = await songs.getSong(song);
    expect(restored!.createdAt, created);
    expect(await songs.watchNewestSongs().first, hasLength(1));
  });

  test('without a creation date in the archive it stays unknown', () async {
    final song = await songs.createSong(source: '{title: Old}');
    final contents = await backup();
    // An archive written before the date was in it.
    final manifest = {
      ...contents.manifest,
      'songs': [
        for (final s in contents.songs) {...s}..remove('createdAt'),
      ],
    };
    await service.replaceLocal(BackupContents(manifest, contents.files));
    expect((await songs.getSong(song))!.createdAt, isNull);
    // Not among the newest songs: its age is unknown.
    expect(await songs.watchNewestSongs().first, isEmpty);
  });
}
