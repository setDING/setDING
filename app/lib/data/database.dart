import 'package:drift/drift.dart';

part 'database.g.dart';

/// ID of the implicit band used while the app runs without a backend (MVP).
const localBandId = '00000000-0000-4000-8000-000000000001';

@DataClassName('BandEntry')
class Bands extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get membersCanEditSongs =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SongEntry')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get bandId => text().references(Bands, #id)();

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

  /// `{tag}` values, each enclosed in newlines (`\nRock\nLive\n`) so a tag
  /// can be matched exactly with LIKE (schema 2).
  TextColumn get tags => text().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AttachmentEntry')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get songId => text().references(Songs, #id)();
  TextColumn get name => text()();

  /// File name inside the attachment directory.
  TextColumn get fileName => text()();
  IntColumn get pages => integer().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

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

/// Personal adjustments per song (layer 3, ADR-0006).
@DataClassName('SongOverlay')
class PersonalOverlays extends Table {
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

  @override
  Set<Column> get primaryKey => {songId};
}

@DriftDatabase(
  tables: [Bands, Songs, Attachments, Setlists, SetItems, PersonalOverlays],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

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
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) await afterUpgrade?.call(this);
      await customStatement('PRAGMA foreign_keys = ON');
      await into(bands).insert(
        BandsCompanion.insert(id: localBandId, name: 'My band'),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );
}
