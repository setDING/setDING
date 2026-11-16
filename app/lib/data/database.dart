import 'package:drift/drift.dart';

import 'band_role.dart';

export 'band_role.dart';

part 'database.g.dart';

/// ID of the local library ("On this device"): the band of the MVP, kept
/// on this device only and never synced. Works without an account.
const localBandId = '00000000-0000-4000-8000-000000000001';

/// Owner of personal adjustments without an account: songs of the local
/// library, and existing adjustments until a user takes them over
/// (ADR-0020).
const localOwnerId = 'local';

/// An organization from the server (ADR-0017); owns the song library that
/// its bands share (schema 4).
@DataClassName('OrganizationEntry')
class Organizations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// The organization is no longer available to this device.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Membership of a user in an organization, cached from the server
/// (schema 4).
@TableIndex(name: 'org_memberships_user', columns: {#userId})
@DataClassName('OrgMembershipEntry')
class OrgMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text().references(Organizations, #id)();
  TextColumn get userId => text()();
  TextColumn get userName => text().withDefault(const Constant(''))();
  TextColumn get userEmail => text().nullable()();
  TextColumn get role => textEnum<BandRole>()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A band from the server, or the local library ([localBandId]).
@DataClassName('BandEntry')
class Bands extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Organization of the band; null for the local library (schema 4).
  TextColumn get organizationId =>
      text().nullable().references(Organizations, #id)();
  BoolColumn get membersCanEditSongs =>
      boolean().withDefault(const Constant(false))();

  /// Server revision (ADR-0015); 0 for the local library (schema 4).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// The band is no longer available to this device (schema 4).
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Membership of a user in a band, cached from the server so that roles
/// and member names are available offline (schema 4).
@TableIndex(name: 'memberships_band', columns: {#bandId})
@TableIndex(name: 'memberships_user', columns: {#userId})
@DataClassName('MembershipEntry')
class Memberships extends Table {
  TextColumn get id => text()();
  TextColumn get bandId => text().references(Bands, #id)();
  TextColumn get userId => text()();

  /// Name of the user at the time of the last refresh.
  TextColumn get userName => text().withDefault(const Constant(''))();
  TextColumn get userEmail => text().nullable()();
  TextColumn get role => textEnum<BandRole>()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'songs_library', columns: {#libraryId, #deleted})
@DataClassName('SongEntry')
class Songs extends Table {
  TextColumn get id => text()();

  /// Song library the song belongs to: an organization ID (ADR-0017), or
  /// [localBandId] for the local library. Until schema 3: `band_id`.
  TextColumn get libraryId => text()();

  /// ChordPro text – the single source of truth (ADR-0003).
  TextColumn get chordproSource => text().withDefault(const Constant(''))();

  /// Redundant metadata for search and sorting.
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get songKey => text().nullable()();
  IntColumn get tempo => integer().nullable()();

  /// `{sorttitle}` / `{sortartist}` for sorting (schema 2).
  TextColumn get sortTitle => text().nullable()();
  TextColumn get sortArtist => text().nullable()();

  /// Lyrics and comments without chords, for the full-text search
  /// (search.drift, schema 10).
  TextColumn get searchText => text().nullable()();

  /// `{tag}` values, each enclosed in newlines (`\nRock\nLive\n`) so a tag
  /// can be matched exactly with LIKE (schema 2).
  TextColumn get tags => text().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'attachments_song', columns: {#songId})
@DataClassName('AttachmentEntry')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get songId => text().references(Songs, #id)();
  TextColumn get name => text()();

  /// File name inside the attachment directory.
  TextColumn get fileName => text()();

  /// Name of the file on the server, null until uploaded or for local-only
  /// attachments; a missing local file is downloaded with it (schema 6).
  TextColumn get remoteFile => text().nullable()();
  IntColumn get pages => integer().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'setlists_band', columns: {#bandId, #deleted})
@DataClassName('SetlistEntry')
class Setlists extends Table {
  TextColumn get id => text()();
  TextColumn get bandId => text().references(Bands, #id)();
  TextColumn get name => text()();
  DateTimeColumn get gigDate => dateTime().nullable()();
  TextColumn get venue => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Type of a set item.
enum SetItemType { song, pause, text }

@TableIndex(name: 'set_items_set', columns: {#setId, #position})
@TableIndex(name: 'set_items_song', columns: {#songId})
@DataClassName('SetItemEntry')
class SetItems extends Table {
  TextColumn get id => text()();
  TextColumn get setId => text().references(Setlists, #id)();
  TextColumn get songId => text().nullable().references(Songs, #id)();
  IntColumn get position => integer()();

  /// Set-specific transposition in semitones (layer 2, ADR-0006).
  IntColumn get transpose => integer().withDefault(const Constant(0))();

  /// Set-specific song sequence (`{x_sequence}` syntax, layer 2,
  /// ADR-0006); null = as in the song.
  TextColumn get sequence => text().nullable()();

  /// Label of a pause or text item.
  TextColumn get note => text().nullable()();
  TextColumn get type => textEnum<SetItemType>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Personal adjustments per person and song (layer 3, ADR-0006, ADR-0020).
@DataClassName('SongOverlay')
class PersonalOverlays extends Table {
  /// Server user ID, or [localOwnerId] (schema 8).
  TextColumn get ownerId => text().withDefault(const Constant(localOwnerId))();
  TextColumn get songId => text().references(Songs, #id)();
  IntColumn get transpose => integer().withDefault(const Constant(0))();

  /// Legacy capo (schema 1, 0 = none); replaced by [capoFret].
  IntColumn get capo => integer().withDefault(const Constant(0))();

  /// Personal capo; null = as written in the song (`{capo}`), 0 = no capo
  /// (schema 2).
  IntColumn get capoFret => integer().nullable()();
  RealColumn get fontScale => real().withDefault(const Constant(1.0))();
  TextColumn get notes => text().nullable()();

  /// Per-song Nashville override; null = use device setting.
  BoolColumn get nashville => boolean().nullable()();

  /// What live mode shows: null = ChordPro, otherwise an attachment ID.
  TextColumn get liveView => text().nullable()();

  /// Server revision; 0 = not on the server (schema 9, ADR-0020).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {ownerId, songId};
}

/// Local changes waiting to be pushed to the server (ADR-0004, schema 5).
/// One row per record; [version] grows with every change, so a change made
/// while a push is running is not lost.
@DataClassName('OutboxEntry')
class SyncOutbox extends Table {
  /// Server collection: `songs`, `setlists` or `attachments`.
  TextColumn get collection => text()();
  TextColumn get recordId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {collection, recordId};
}

/// Highest server revision pulled per scope (organization or band) and
/// collection (delta sync, schema 5).
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  TextColumn get scope => text()();
  TextColumn get collection => text()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {scope, collection};
}

/// A song changed on the server and on this device (ADR-0004): the server
/// version waits here until the user decides (schema 5).
@DataClassName('SongConflict')
class SongConflicts extends Table {
  TextColumn get songId => text()();
  TextColumn get title => text()();
  TextColumn get chordproSource => text()();
  IntColumn get revision => integer()();

  /// The song was deleted on the server.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get detectedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}

@DriftDatabase(
  include: {'search.drift'},
  tables: [
    Organizations,
    OrgMemberships,
    Bands,
    Memberships,
    Songs,
    Attachments,
    Setlists,
    SetItems,
    PersonalOverlays,
    SyncOutbox,
    SyncCursors,
    SongConflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 10;

  /// Creates the full-text index of the songs and its triggers (again) and
  /// fills it. Needed after a migration that rebuilds the `songs` table
  /// (which drops its triggers).
  Future<void> createSongSearch(Migrator m) async {
    await customStatement('DROP TABLE IF EXISTS songs_fts');
    for (final trigger in [songsFtsInsert, songsFtsDelete, songsFtsUpdate]) {
      await customStatement('DROP TRIGGER IF EXISTS ${trigger.entityName}');
    }
    await m.create(songsFts);
    await m.create(songsFtsInsert);
    await m.create(songsFtsDelete);
    await m.create(songsFtsUpdate);
    await customStatement(
      "INSERT INTO songs_fts (songs_fts) VALUES ('rebuild')",
    );
  }

  /// Indexes of the local database (schema 7).
  List<Index> get localIndexes => [
    for (final e in allSchemaEntities)
      if (e is Index) e,
  ];

  /// Called after an upgrade to fill new columns from the ChordPro source.
  Future<void> Function(AppDatabase db)? afterUpgrade;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(songs, songs.sortTitle);
        await m.addColumn(songs, songs.sortArtist);
        await m.addColumn(songs, songs.tags);
        await m.addColumn(personalOverlays, personalOverlays.capoFret);
        await customStatement(
          'UPDATE personal_overlays SET capo_fret = capo WHERE capo > 0',
        );
      }
      if (from < 3) {
        await m.addColumn(setItems, setItems.sequence);
      }
      if (from < 4) {
        await m.createTable(organizations);
        await m.createTable(orgMemberships);
        await m.addColumn(bands, bands.organizationId);
        await m.addColumn(bands, bands.revision);
        await m.addColumn(bands, bands.deleted);
        await m.createTable(memberships);
        // Songs belong to a library instead of a band (ADR-0017); the
        // table is rebuilt to drop the foreign key on bands.
        await m.alterTable(
          TableMigration(
            songs,
            columnTransformer: {
              songs.libraryId: const CustomExpression<String>('band_id'),
            },
            // Columns of later schemas exist in the rebuilt table already.
            newColumns: [songs.searchText],
          ),
        );
      }
      if (from < 5) {
        await m.createTable(syncOutbox);
        await m.createTable(syncCursors);
        await m.createTable(songConflicts);
      }
      if (from < 6) {
        await m.addColumn(attachments, attachments.remoteFile);
      }
      if (from < 7) {
        // Indexes for the lists of songs, sets, items, attachments and
        // members (schema 7). Rebuilding a table above may already have
        // created some of them.
        for (final index in localIndexes) {
          await customStatement('DROP INDEX IF EXISTS ${index.entityName}');
          await m.createIndex(index);
        }
      }
      if (from < 8) {
        // Overlays belong to a person (ADR-0020): existing ones to the
        // local owner until a user takes them over. The table is rebuilt
        // for the new primary key.
        await m.alterTable(
          TableMigration(
            personalOverlays,
            newColumns: [personalOverlays.ownerId, personalOverlays.revision],
          ),
        );
      } else if (from < 9) {
        await m.addColumn(personalOverlays, personalOverlays.revision);
      }
      if (from < 10) {
        // Full-text search: the column is filled by afterUpgrade
        // (refreshAllMetadata), the index rebuilt from the songs.
        // Before schema 4 the rebuilt table has the column already.
        if (from >= 4) await m.addColumn(songs, songs.searchText);
        await createSongSearch(m);
      }
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) await afterUpgrade?.call(this);
      await customStatement('PRAGMA foreign_keys = ON');
      await _insertLocalBand();
    },
  );

  Future<void> _insertLocalBand() => into(bands).insert(
    BandsCompanion.insert(id: localBandId, name: 'My band'),
    mode: InsertMode.insertOrIgnore,
  );

  /// Deletes all data, as after a fresh install: songs, sets, bands, the
  /// outbox and the sync cursors. The web client does this when signing out
  /// (ADR-0018). The full-text index follows the songs through its triggers.
  Future<void> clearAll() async {
    // Foreign keys cannot be switched inside a transaction.
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in allTables) {
          if (table is VirtualTableInfo) continue;
          await delete(table).go();
        }
        await _insertLocalBand();
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
