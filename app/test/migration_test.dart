import 'dart:io';
import 'dart:typed_data';

import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Indexes added in schema 7.
const schema7Indexes = [
  'org_memberships_user',
  'memberships_band',
  'memberships_user',
  'songs_library',
  'attachments_song',
  'setlists_band',
  'set_items_set',
  'set_items_song',
];

/// Turns a current database back into schema 13: songs without the
/// number of ChordPro problems.
void downgradeToSchema13(Database raw) {
  raw.execute('ALTER TABLE songs DROP COLUMN chordpro_problems');
}

/// Turns a current database back into schema 12: songs without sequence.
void downgradeToSchema12(Database raw) {
  downgradeToSchema13(raw);
  raw.execute('ALTER TABLE songs DROP COLUMN sequence');
}

/// Turns a current database back into schema 11: no band arrangements.
void downgradeToSchema11(Database raw) {
  downgradeToSchema12(raw);
  raw.execute('DROP TABLE band_arrangements');
}

/// Turns a current database back into schema 10: songs without creator
/// and last editor, bands with the setting members_can_edit_songs.
void downgradeToSchema10(Database raw) {
  downgradeToSchema11(raw);
  raw.execute('ALTER TABLE songs DROP COLUMN created_by');
  raw.execute('ALTER TABLE songs DROP COLUMN updated_by');
  raw.execute(
    'ALTER TABLE bands ADD COLUMN members_can_edit_songs INTEGER NOT NULL '
    'DEFAULT 0 CHECK ("members_can_edit_songs" IN (0, 1))',
  );
}

/// Turns a current database back into schema 9: no full-text search.
void downgradeToSchema9(Database raw) {
  downgradeToSchema10(raw);
  for (final trigger in ['insert', 'delete', 'update']) {
    raw.execute('DROP TRIGGER songs_fts_$trigger');
  }
  raw.execute('DROP TABLE songs_fts');
  raw.execute('ALTER TABLE songs DROP COLUMN search_text');
}

/// Turns a current database back into schema 7: personal overlays without
/// an owner, keyed by song.
void downgradeToSchema7(Database raw) {
  downgradeToSchema9(raw);
  raw.execute('''
    CREATE TABLE overlays_7 (
      song_id TEXT NOT NULL REFERENCES songs (id),
      transpose INTEGER NOT NULL DEFAULT 0,
      capo INTEGER NOT NULL DEFAULT 0,
      capo_fret INTEGER NULL,
      font_scale REAL NOT NULL DEFAULT 1.0,
      notes TEXT NULL,
      nashville INTEGER NULL,
      live_view TEXT NULL,
      PRIMARY KEY (song_id)
    )''');
  raw.execute(
    'INSERT INTO overlays_7 SELECT song_id, transpose, capo, capo_fret, '
    'font_scale, notes, nashville, live_view FROM personal_overlays',
  );
  raw.execute('DROP TABLE personal_overlays');
  raw.execute('ALTER TABLE overlays_7 RENAME TO personal_overlays');
}

/// Turns a current database back into schema 6 (no indexes).
void downgradeToSchema6(Database raw) {
  downgradeToSchema7(raw);
  for (final index in schema7Indexes) {
    raw.execute('DROP INDEX $index');
  }
}

/// Names of the indexes in [raw] (without SQLite's own).
Set<String> indexNames(Database raw) => {
  for (final row in raw.select(
    "SELECT name FROM sqlite_master WHERE type = 'index' "
    "AND name NOT LIKE 'sqlite_%'",
  ))
    row['name'] as String,
};

/// Turns a current database back into schema 3 (before organizations):
/// songs reference a band again, no organization or membership tables.
void downgradeToSchema3(Database raw) {
  downgradeToSchema6(raw);
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
    dir = Directory.systemTemp.createTempSync('setding_migration');
    file = File('${dir.path}/db.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('upgrades a schema 1 database to the current schema', () async {
    // Create the current schema, then turn it back into schema 1.
    final current = AppDatabase(NativeDatabase(file));
    final songs = SongRepository(current, FileAttachmentStorage(dir));
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
    final repo = SongRepository(upgraded, FileAttachmentStorage(dir));
    upgraded.afterUpgrade = (db) => repo.refreshAllMetadata();

    final song = (await repo.getSong(id))!;
    expect(song.sortTitle, 'Old, The');
    expect(songTags(song), ['Rock']);
    expect((await repo.getOverlay(id)).capoFret, 3);
    await upgraded.close();
  });

  test('upgrades a schema 2 database: set items get a sequence', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
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
      final storage = FileAttachmentStorage(dir);
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

  test('a new database has the indexes of schema 7', () async {
    final db = AppDatabase(NativeDatabase(file));
    await SongRepository(db, FileAttachmentStorage(dir)).getSong('x');
    await db.close();
    final raw = sqlite3.open(file.path);
    expect(indexNames(raw), containsAll(schema7Indexes));
    raw.close();
  });

  for (final from in [6, 3]) {
    test('upgrades a schema $from database: lists get indexes', () async {
      final current = AppDatabase(NativeDatabase(file));
      final storage = FileAttachmentStorage(dir);
      final songId = await SongRepository(
        current,
        storage,
      ).createSong(source: '{title: Indexed}');
      await current.close();

      var raw = sqlite3.open(file.path);
      if (from == 6) {
        downgradeToSchema6(raw);
      } else {
        downgradeToSchema3(raw);
      }
      raw.execute('PRAGMA user_version = $from');
      expect(indexNames(raw).intersection(schema7Indexes.toSet()), isEmpty);
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(upgraded, storage);
      expect((await repo.watchSongs().first).map((s) => s.id), [songId]);
      await upgraded.close();

      raw = sqlite3.open(file.path);
      expect(indexNames(raw), containsAll(schema7Indexes));
      raw.close();
    });
  }

  test('upgrades a schema 7 database: overlays get the local owner', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
    final local = SongRepository(current, storage);
    final id = await local.createSong(source: '{title: Mine}');
    await local.saveOverlay(
      (await local.getOverlay(id)).copyWith(transpose: 3),
    );
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema7(raw);
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final overlay = await SongRepository(upgraded, storage).getOverlay(id);
    expect(overlay.ownerId, localOwnerId);
    expect(overlay.transpose, 3);
    await upgraded.close();
  });

  test('upgrades a schema 8 database: overlays get a revision', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
    final org = SongRepository(
      current,
      storage,
      libraryId: 'o1',
      userId: 'ann',
    );
    final id = await org.createSong(source: '{title: Org}');
    await org.saveOverlay((await org.getOverlay(id)).copyWith(transpose: 1));
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema9(raw);
    raw.execute('ALTER TABLE personal_overlays DROP COLUMN revision');
    raw.execute('PRAGMA user_version = 8');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final overlay = await SongRepository(
      upgraded,
      storage,
      libraryId: 'o1',
      userId: 'ann',
    ).getOverlay(id);
    expect(
      (overlay.ownerId, overlay.transpose, overlay.revision),
      ('ann', 1, 0),
    );
    await upgraded.close();
  });

  test('upgrades a schema 9 database: songs become searchable', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
    final songs = SongRepository(current, storage);
    await songs.createSong(source: '{title: Old}\n[C]Hel[G]lo sunshine');
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema9(raw);
    raw.execute('PRAGMA user_version = 9');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final repo = SongRepository(upgraded, storage);
    upgraded.afterUpgrade = (db) => repo.refreshAllMetadata();
    expect((await repo.watchSongs(query: 'hello').first).map((s) => s.title), [
      'Old',
    ]);
    await upgraded.close();
  });

  test('upgrades a schema 10 database: roles of ADR-0023', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
    await SongRepository(current, storage).createSong(source: '{title: Old}');
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema10(raw);
    raw.execute("INSERT INTO organizations (id, name) VALUES ('o1', 'School')");
    raw.execute(
      "INSERT INTO bands (id, name, organization_id, members_can_edit_songs) "
      "VALUES ('b1', 'Rock', 'o1', 1)",
    );
    raw.execute(
      "INSERT INTO org_memberships (id, organization_id, user_id, role) "
      "VALUES ('m1', 'o1', 'u1', 'member')",
    );
    raw.execute('PRAGMA user_version = 10');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final song = (await upgraded.select(upgraded.songs).get()).single;
    expect(song.title, 'Old');
    expect(song.createdBy, isNull);
    expect(song.updatedBy, isNull);
    final band = await (upgraded.select(
      upgraded.bands,
    )..where((b) => b.id.equals('b1'))).getSingle();
    expect(band.organizationId, 'o1');
    expect(
      (await upgraded.select(upgraded.orgMemberships).get()).single.role,
      OrgRole.member,
    );
    final columns = await upgraded
        .customSelect('PRAGMA table_info(bands)')
        .map((r) => r.read<String>('name'))
        .get();
    expect(columns, isNot(contains('members_can_edit_songs')));
    await upgraded.close();
  });

  test('upgrades a schema 11 database: band arrangements', () async {
    final current = AppDatabase(NativeDatabase(file));
    final storage = FileAttachmentStorage(dir);
    final song = await SongRepository(
      current,
      storage,
    ).createSong(source: '{title: Old}');
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema11(raw);
    raw.execute('PRAGMA user_version = 11');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final repo = ArrangementRepository(upgraded);
    await repo.save('b1', song, transpose: 2);
    expect((await repo.get('b1', song))!.transpose, 2);
    await upgraded.close();
  });

  test(
    'upgrades a schema 12 database: the song list has the sequence',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      final storage = FileAttachmentStorage(dir);
      await SongRepository(
        current,
        storage,
      ).createSong(source: '{title: Old}\n{x_sequence: I, V, C}');
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema12(raw);
      raw.execute('PRAGMA user_version = 12');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(upgraded, storage);
      upgraded.afterUpgrade = (db) => repo.refreshAllMetadata();
      expect((await repo.watchSongList().first).single.sequence, 'I, V, C');
      await upgraded.close();
    },
  );

  test(
    'upgrades a schema 13 database: songs know their ChordPro problems',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      final storage = FileAttachmentStorage(dir);
      await SongRepository(
        current,
        storage,
      ).createSong(source: '{title: Old}\n{c: Chorus} (a cappella)');
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema13(raw);
      raw.execute('PRAGMA user_version = 13');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(upgraded, storage);
      upgraded.afterUpgrade = (db) => repo.refreshAllMetadata();
      expect((await repo.watchSongList().first).single.problems, 1);
      await upgraded.close();
    },
  );
}
