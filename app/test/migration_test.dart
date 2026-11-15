import 'dart:io';
import 'dart:typed_data';

import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Turns a current database back into schema 3 (before organizations):
/// songs reference a band again, no organization or membership tables.
void downgradeToSchema3(Database raw) {
  // Schema 6 and 5: attachment server file, sync tables.
  raw.execute('ALTER TABLE attachments DROP COLUMN remote_file');
  raw.execute('DROP TABLE sync_outbox');
  raw.execute('DROP TABLE sync_cursors');
  raw.execute('DROP TABLE song_conflicts');
  raw.execute('DROP TABLE memberships');
  raw.execute('DROP TABLE org_memberships');
  raw.execute('ALTER TABLE bands DROP COLUMN organization_id');
  raw.execute('ALTER TABLE bands DROP COLUMN revision');
  raw.execute('ALTER TABLE bands DROP COLUMN deleted');
  raw.execute('DROP TABLE organizations');
  raw.execute('ALTER TABLE songs RENAME COLUMN library_id TO band_id');
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('realchord_migration');
    file = File('${dir.path}/db.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('upgrades a schema 1 database to the current schema', () async {
    // Create the current schema, then turn it back into schema 1.
    final current = AppDatabase(NativeDatabase(file));
    final songs = SongRepository(current, AttachmentStorage(dir));
    final id = await songs.createSong(
      source: '{title: Old}\n{sorttitle: Old, The}\n{tag: Rock}\n[C]x',
    );
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema3(raw);
    raw.execute('ALTER TABLE songs DROP COLUMN sort_title');
    raw.execute('ALTER TABLE songs DROP COLUMN sort_artist');
    raw.execute('ALTER TABLE songs DROP COLUMN tags');
    raw.execute('ALTER TABLE personal_overlays DROP COLUMN capo_fret');
    raw.execute('ALTER TABLE set_items DROP COLUMN sequence');
    raw.execute(
      "INSERT INTO personal_overlays (song_id, transpose, capo, font_scale) "
      "VALUES ('$id', 0, 3, 1.0)",
    );
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    // Open with the app: migrate and fill the new columns.
    final upgraded = AppDatabase(NativeDatabase(file));
    final repo = SongRepository(upgraded, AttachmentStorage(dir));
    upgraded.afterUpgrade = (db) => repo.refreshAllMetadata();

    final song = (await repo.getSong(id))!;
    expect(song.sortTitle, 'Old, The');
    expect(songTags(song), ['Rock']);
    expect((await repo.getOverlay(id)).capoFret, 3);
    await upgraded.close();
  });

  test('upgrades a schema 2 database: set items get a sequence', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = AttachmentStorage(dir);
    final songId = await SongRepository(
      current,
      storage,
    ).createSong(source: '{title: S}');
    final sets = SetRepository(current, storage);
    final setId = await sets.createSet(name: 'Gig');
    await sets.addSongs(setId, [songId]);
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema3(raw);
    raw.execute('ALTER TABLE set_items DROP COLUMN sequence');
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final upgradedSets = SetRepository(upgraded, storage);
    final item = (await upgradedSets.getItems(setId)).single.item;
    expect(item.sequence, isNull);
    await upgradedSets.setItemSequence(item.id, ' V, C ');
    expect((await upgradedSets.getItems(setId)).single.item.sequence, 'V, C');
    await upgradedSets.setItemSequence(item.id, '');
    expect((await upgradedSets.getItems(setId)).single.item.sequence, isNull);
    await upgraded.close();
  });

  test(
    'upgrades a schema 3 database: songs move to the local library',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      final storage = AttachmentStorage(dir);
      final songs = SongRepository(current, storage);
      final songId = await songs.createSong(source: '{title: Kept}');
      await songs.addAttachment(
        songId,
        name: 'Score',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final sets = SetRepository(current, storage);
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [songId]);
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema3(raw);
      raw.execute('PRAGMA user_version = 3');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(upgraded, storage);
      final song = (await repo.getSong(songId))!;
      expect(song.libraryId, localBandId);
      expect(song.title, 'Kept');
      expect((await repo.watchSongs().first).map((s) => s.id), [songId]);
      expect(await repo.getAttachments(songId), hasLength(1));
      final items = await SetRepository(upgraded, storage).getItems(setId);
      expect(items.single.song?.id, songId);

      // Songs of an organization library need no band (ADR-0017).
      final orgSongs = SongRepository(upgraded, storage, libraryId: 'org-1');
      final orgSong = await orgSongs.createSong(source: '{title: Shared}');
      expect((await orgSongs.getSong(orgSong))!.libraryId, 'org-1');
      await upgraded.close();
    },
  );
}
