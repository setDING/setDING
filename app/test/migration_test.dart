import 'dart:io';
import 'dart:typed_data';

import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
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

/// Turns a current database back into schema 18: overlays without a
/// keyboard program (ADR-0039).
void downgradeToSchema18(Database raw) {
  downgradeToSchema19(raw);
  raw.execute('ALTER TABLE personal_overlays DROP COLUMN midi');
}

/// Turns a current database back into schema 19: one keyboard program per
/// song, no programs per profile (ADR-0042).
void downgradeToSchema19(Database raw) {
  downgradeToSchema20(raw);
  raw.execute('ALTER TABLE personal_overlays DROP COLUMN midi_programs');
}

/// Turns a current database back into schema 20: no trash (ADR-0043).
void downgradeToSchema20(Database raw) {
  for (final table in ['songs', 'attachments', 'setlists']) {
    raw.execute('ALTER TABLE $table DROP COLUMN deleted_at');
    raw.execute('ALTER TABLE $table DROP COLUMN purged');
  }
}

/// Turns a current database back into schema 16: overlays without
/// "chords in the first verse only".
void downgradeToSchema16(Database raw) {
  downgradeToSchema18(raw);
  raw.execute('ALTER TABLE personal_overlays DROP COLUMN verse_chords');
}

/// Turns a current database back into schema 17: chords in the first verse
/// only as a boolean (#518) instead of the verse chords choice (#521).
void downgradeToSchema17(Database raw, {required bool firstVerseOnly}) {
  downgradeToSchema16(raw);
  raw.execute(
    'ALTER TABLE personal_overlays ADD COLUMN first_verse_chords_only '
    'INTEGER NOT NULL DEFAULT 0 CHECK (first_verse_chords_only IN (0, 1))',
  );
  raw.execute(
    'UPDATE personal_overlays SET first_verse_chords_only = '
    '${firstVerseOnly ? 1 : 0}',
  );
}

/// Turns a current database back into schema 15: no freehand annotations.
void downgradeToSchema15(Database raw) {
  downgradeToSchema16(raw);
  raw.execute('DROP INDEX annotations_owner_song');
  raw.execute('DROP TABLE annotations');
  raw.execute('ALTER TABLE personal_overlays DROP COLUMN hide_annotations');
}

/// Turns a current database back into schema 14: no personal settings.
void downgradeToSchema14(Database raw) {
  downgradeToSchema15(raw);
  raw.execute('DROP TABLE user_settings');
}

/// Turns a current database back into schema 13: songs without the
/// number of ChordPro problems.
void downgradeToSchema13(Database raw) {
  downgradeToSchema14(raw);
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

  test('upgrades a schema 14 database: personal settings', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current.select(current.songs).get();
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema14(raw);
    raw.execute('PRAGMA user_version = 14');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    await upgraded
        .into(upgraded.userSettings)
        .insert(UserSettingsCompanion.insert(ownerId: 'local'));
    expect(await upgraded.select(upgraded.userSettings).get(), hasLength(1));
    await upgraded.close();
  });

  test('upgrades a schema 15 database: freehand annotations', () async {
    final current = AppDatabase(NativeDatabase(file));
    final repo = SongRepository(current, FileAttachmentStorage(dir));
    final song = await repo.createSong(source: '{title: Song}');
    await repo.saveOverlay(
      (await repo.getOverlay(song)).copyWith(transpose: 2),
    );
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema15(raw);
    raw.execute('PRAGMA user_version = 15');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final overlay = await upgraded
        .select(upgraded.personalOverlays)
        .getSingle();
    expect((overlay.transpose, overlay.hideAnnotations), (2, false));
    await upgraded
        .into(upgraded.annotations)
        .insert(
          AnnotationsCompanion.insert(
            id: 'a1',
            ownerId: 'local',
            songId: song,
            updatedAt: 1,
          ),
        );
    expect(await upgraded.select(upgraded.annotations).get(), hasLength(1));
    final raw2 = sqlite3.open(file.path);
    expect(indexNames(raw2), contains('annotations_owner_song'));
    raw2.close();
    await upgraded.close();
  });

  test(
    'upgrades a schema 16 database: chords in the first verse only',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(current, FileAttachmentStorage(dir));
      final song = await repo.createSong(source: '{title: Song}');
      await repo.saveOverlay(
        (await repo.getOverlay(song)).copyWith(transpose: 3),
      );
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema16(raw);
      raw.execute('PRAGMA user_version = 16');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final overlay = await upgraded
          .select(upgraded.personalOverlays)
          .getSingle();
      expect((overlay.transpose, overlay.verseChords), (3, VerseChords.all));
      await upgraded.close();
    },
  );

  for (final firstVerseOnly in [true, false]) {
    test('upgrades a schema 17 database: chords in the first verse only '
        '$firstVerseOnly', () async {
      final current = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(current, FileAttachmentStorage(dir));
      final song = await repo.createSong(source: '{title: Song}');
      await repo.saveOverlay(
        (await repo.getOverlay(song)).copyWith(transpose: 3),
      );
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema17(raw, firstVerseOnly: firstVerseOnly);
      raw.execute('PRAGMA user_version = 17');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final overlay = await upgraded
          .select(upgraded.personalOverlays)
          .getSingle();
      expect(overlay.transpose, 3);
      expect(
        overlay.verseChords,
        firstVerseOnly ? VerseChords.first : VerseChords.all,
      );
      await upgraded.close();
      final check = sqlite3.open(file.path);
      final columns = check
          .select('PRAGMA table_info(personal_overlays)')
          .map((r) => r['name'])
          .toList();
      check.close();
      expect(columns, isNot(contains('first_verse_chords_only')));
    });
  }

  test(
    'upgrades a schema 18 database: overlays get a keyboard program',
    () async {
      final current = AppDatabase(NativeDatabase(file));
      final repo = SongRepository(current, FileAttachmentStorage(dir));
      final song = await repo.createSong(source: '{title: Song}');
      await repo.saveOverlay(
        (await repo.getOverlay(song))
            .copyWith(transpose: 3, verseChords: VerseChords.stacked),
      );
      await current.close();

      final raw = sqlite3.open(file.path);
      downgradeToSchema18(raw);
      raw.execute('PRAGMA user_version = 18');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final repo2 = SongRepository(upgraded, FileAttachmentStorage(dir));
      final overlay = await repo2.getOverlay(song);
      expect(
        (overlay.transpose, overlay.verseChords),
        (3, VerseChords.stacked),
      );
      expect(overlay.midi, isNull);
      const program = MidiProgram(msb: 0, lsb: 2, program: 12);
      await repo2.setMidiProgram(
        song,
        'nordStage3',
        program,
        deviceProfile: 'nordStage3',
      );
      expect(await repo2.midiProgram(song, 'nordStage3'), program);
      await upgraded.close();
    },
  );

  test('upgrades a schema 19 database: the program of v0.16.0 counts for '
      "the device's profile until the programs change (ADR-0042)", () async {
    final current = AppDatabase(NativeDatabase(file));
    final repo = SongRepository(current, FileAttachmentStorage(dir));
    final song = await repo.createSong(source: '{title: Song}');
    const legacy = MidiProgram(msb: 0, lsb: 2, program: 12);
    await repo.saveOverlay(
      (await repo.getOverlay(song)).copyWith(midi: const Value(legacy)),
    );
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema19(raw);
    raw.execute('PRAGMA user_version = 19');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final repo2 = SongRepository(upgraded, FileAttachmentStorage(dir));
    expect((await repo2.getOverlay(song)).midiPrograms, isNull);
    expect(await repo2.midiProgram(song, 'nordStage3'), legacy);
    expect(await repo2.midiProgram(song, 'generic'), legacy);

    // The first change moves it to the device's profile.
    const motif = MidiProgram(msb: 63, lsb: 8, program: 0);
    await repo2.setMidiProgram(
      song,
      'motifXf',
      motif,
      deviceProfile: 'nordStage3',
    );
    final overlay = await repo2.getOverlay(song);
    expect(
      overlay.midiPrograms,
      const MidiPrograms({'nordStage3': legacy, 'motifXf': motif}),
    );
    expect(overlay.midi, legacy, reason: 'kept for v0.16.0 clients');
    expect(await repo2.midiProgram(song, 'generic'), isNull);
    await upgraded.close();
  });

  test('upgrades a schema 20 database: deleted records go to the trash '
      '(ADR-0043)', () async {
    final current = AppDatabase(NativeDatabase(file));
    final repo = SongRepository(current, FileAttachmentStorage(dir));
    final sets = SetRepository(current, FileAttachmentStorage(dir));
    final gone = await repo.createSong(source: '{title: Gone}');
    final kept = await repo.createSong(source: '{title: Kept}');
    final setId = await sets.createSet(name: 'Gig');
    await repo.deleteSong(gone);
    await sets.deleteSet(setId);
    await current.close();

    final raw = sqlite3.open(file.path);
    downgradeToSchema20(raw);
    raw.execute('PRAGMA user_version = 20');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    final songs = await upgraded.select(upgraded.songs).get();
    final byId = {for (final s in songs) s.id: s};
    expect(byId[gone]!.deletedAt, isNotNull, reason: 'from updated_at');
    expect(byId[gone]!.purged, isFalse);
    expect(byId[kept]!.deletedAt, isNull);
    final set = await upgraded.select(upgraded.setlists).getSingle();
    expect(set.deletedAt, isNotNull);
    await upgraded.close();
  });
}
