import 'dart:convert';

import 'package:chordpro/chordpro.dart' show Subdivision;
import 'package:drift/drift.dart';

import '../midi/midi_message.dart';
import 'band_role.dart';
import 'played_values.dart';

export '../midi/midi_message.dart' show MidiProgram, MidiPrograms;
export 'band_role.dart';
export 'played_values.dart';

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

  /// Stored by name, so schema 11 kept the values of [BandRole] it had
  /// before (`admin`, `member`) and added `librarian` (ADR-0023).
  TextColumn get role => textEnum<OrgRole>()();
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

  /// Server revision (ADR-0015); 0 for the local library (schema 4).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// The band is no longer available to this device (schema 4).
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Months after which a song counts as not played for a while
  /// (ADR-0046); 0 = the default (schema 25).
  IntColumn get staleAfterMonths => integer().withDefault(const Constant(0))();

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

  /// Raw `{x_sequence}` value, for the song list (schema 13).
  TextColumn get sequence => text().nullable()();

  /// `{sorttitle}` / `{sortartist}` for sorting (schema 2).
  TextColumn get sortTitle => text().nullable()();
  TextColumn get sortArtist => text().nullable()();

  /// Lyrics and comments without chords, for the full-text search
  /// (search.drift, schema 10).
  TextColumn get searchText => text().nullable()();

  /// Number of places where the ChordPro source probably does not do what
  /// the author meant (`validateChordPro`, schema 14, #314): derived on
  /// the device like [searchText], for the warning icons in lists.
  IntColumn get chordproProblems => integer().withDefault(const Constant(0))();

  /// Number of places the editor offers to convert, e.g. CCLI directives
  /// or short-form section labels (`countChordProConversions`, schema 30,
  /// #798): derived on the device like [chordproProblems].
  IntColumn get chordproConversions =>
      integer().withDefault(const Constant(0))();

  /// `{tag}` values, each enclosed in newlines (`\nRock\nLive\n`) so a tag
  /// can be matched exactly with LIKE (schema 2).
  TextColumn get tags => text().nullable()();

  /// User who created the song and who changed it last, as the server
  /// reports them (ADR-0023, schema 11): band leaders may edit their own
  /// songs as long as nobody else has changed them. Null for the local
  /// library and for songs created before.
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

  /// Shared ID of all language versions of a work (ADR-0053, schema 31):
  /// translations and free adaptations of the song in the same library.
  /// Null if the song has no other versions.
  TextColumn get workId => text().nullable()();

  /// Language set by hand (ADR-0053, schema 31): a code of
  /// `songLanguages` (outbox.dart); null uses the language detected on the device.
  TextColumn get language => text().nullable()();

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

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

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

  /// The set this one was imported from, for re-importing a set archive
  /// (ADR-0043 §1b, schema 28): the original ID of the exported set (or its
  /// own origin). Null for sets made in the app.
  TextColumn get origin => text().nullable()();

  /// User who changed the set last, as the server reports it (ADR-0045,
  /// schema 22): for the recent changes of the overview. Null for the
  /// local band and for sets synced before.
  TextColumn get updatedBy => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Type of a set item: a song or a marker (break, announcement, encore, …
/// with an icon and an optional text, ADR-0047). Schema 28 and older had
/// `pause` and `text` instead of `marker`.
enum SetItemType { song, marker }

/// How the verses of a song show their chords (a personal adjustment,
/// ADR-0006): all of them, in the first verse only (#518), or verses with
/// the same chords stacked line by line (#521).
enum VerseChords { all, first, stacked }

/// Stores a [MidiProgram] as its JSON (ADR-0039); a value that cannot be
/// read is no program.
class MidiProgramConverter extends TypeConverter<MidiProgram?, String?> {
  const MidiProgramConverter();

  @override
  MidiProgram? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      return MidiProgram.fromJson(jsonDecode(fromDb));
    } on FormatException {
      return null;
    }
  }

  @override
  String? toSql(MidiProgram? value) =>
      value == null ? null : jsonEncode(value.toJson());
}

/// Stores [PlayedValues] as their JSON (ADR-0046); a value that cannot be
/// read counts as not frozen.
class PlayedValuesConverter extends TypeConverter<PlayedValues?, String?> {
  const PlayedValuesConverter();

  @override
  PlayedValues? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      final json = jsonDecode(fromDb);
      return json is Map<String, dynamic> ? PlayedValues.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  String? toSql(PlayedValues? value) =>
      value == null ? null : jsonEncode(value.toJson());
}

/// Stores [MidiPrograms] as their JSON (ADR-0042); null = never written
/// (a v0.16.0 program in `midi` still counts), a value that cannot be read
/// is no program.
class MidiProgramsConverter extends TypeConverter<MidiPrograms?, String?> {
  const MidiProgramsConverter();

  @override
  MidiPrograms? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      return MidiPrograms.fromJson(jsonDecode(fromDb)) ?? const MidiPrograms();
    } on FormatException {
      return const MidiPrograms();
    }
  }

  @override
  String? toSql(MidiPrograms? value) =>
      value == null ? null : jsonEncode(value.toJson());
}

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

  /// Text of a marker; null or empty when it shows its icon's name.
  TextColumn get note => text().nullable()();
  TextColumn get type => textEnum<SetItemType>()();

  /// Key of a marker's icon in the catalogue (`MarkerIcons`, ADR-0047);
  /// null for songs.
  TextColumn get icon => text().nullable()();

  /// How the song was played, frozen once the gig date is reached
  /// (ADR-0046); null before, and for sets of older clients.
  TextColumn get played =>
      text().nullable().map(const PlayedValuesConverter())();

  /// Fields of the server's item JSON this version does not know, as a JSON
  /// object, so that saving the set keeps them for newer clients (ADR-0046).
  TextColumn get extra => text().nullable()();

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

  /// Freehand annotations of this song hidden (ADR-0032, schema 16).
  BoolColumn get hideAnnotations =>
      boolean().withDefault(const Constant(false))();

  /// How verses show their chords: all, in the first verse only (#518) or
  /// stacked line by line (#521) (schema 18; a boolean in schema 17).
  TextColumn get verseChords =>
      textEnum<VerseChords>().withDefault(Constant(VerseChords.all.name))();

  /// Keyboard program sent in live mode (ADR-0039, schema 19); null =
  /// none, the keyboard keeps its program.
  TextColumn get midi => text().nullable().map(const MidiProgramConverter())();

  /// Keyboard programs per device profile (ADR-0042, schema 20). Null =
  /// never written: [midi] (v0.16.0) counts for the device's profile; once
  /// written, even empty, [midi] is ignored.
  TextColumn get midiPrograms =>
      text().nullable().map(const MidiProgramsConverter())();

  /// Grouping of an odd meter for the click and the beat display (#698,
  /// schema 27): `3+2+2`, or the numerator alone for no groups; null = as
  /// in the song (`{x_time_grouping}`).
  TextColumn get clickGrouping => text().nullable()();

  /// Subdivisions of the click for this song (#698, schema 27); null = the
  /// personal setting.
  TextColumn get clickSubdivision => textEnum<Subdivision>().nullable()();

  /// Server revision; 0 = not on the server (schema 9, ADR-0020).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {ownerId, songId};
}

/// A band's arrangement of a song (ADR-0025, schema 12): the band's key as
/// a transposition relative to the song, its sequence and tempo; between
/// the song and the set item. The primary key (band first) also serves the
/// lookups per band.
@DataClassName('BandArrangement')
class BandArrangements extends Table {
  TextColumn get bandId => text()();
  TextColumn get songId => text().references(Songs, #id)();

  /// Semitones relative to the song's key.
  IntColumn get transpose => integer().withDefault(const Constant(0))();

  /// Song sequence (`{x_sequence}` syntax); null = as in the song.
  TextColumn get sequence => text().nullable()();

  /// Tempo in BPM; null = as in the song (`{tempo}`).
  IntColumn get tempo => integer().nullable()();

  /// User who changed the arrangement last, as the server reports it
  /// (ADR-0045, schema 22). Null for the local band and for arrangements
  /// synced before.
  TextColumn get updatedBy => text().nullable()();

  /// Server revision; 0 = not on the server.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Removed ("as in the song"); kept until the removal reached the server.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {bandId, songId};
}

/// Personal settings of one person (layer 4a, ADR-0027, schema 15): the
/// settings that follow a person to all their devices, as a JSON object
/// keyed by setting name. Device settings stay in `SharedPreferences`.
@DataClassName('UserSettingsRow')
class UserSettings extends Table {
  /// Server user ID, or [localOwnerId] while signed out.
  TextColumn get ownerId => text()();

  /// The settings as a JSON object; keys this app version does not know
  /// (from a newer version on another device) are kept.
  TextColumn get data => text().withDefault(const Constant('{}'))();

  /// JSON list of the keys changed here and not yet on the server.
  TextColumn get dirtyKeys => text().withDefault(const Constant('[]'))();

  /// Server revision; 0 = not on the server.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Copied from the signed-out settings at the first sign-in on this
  /// device: replaced by the person's settings from the server, or
  /// uploaded if the server has none yet (ADR-0027).
  BoolColumn get adopting => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {ownerId};
}

/// Personal freehand annotations (ADR-0032, schema 16): one row per stroke
/// or stamp. The strokes of an owner for a song and target are one record
/// on the server, merged per stroke ID.
@TableIndex(name: 'annotations_owner_song', columns: {#ownerId, #songId})
@DataClassName('AnnotationRow')
class Annotations extends Table {
  /// UUID of the stroke.
  TextColumn get id => text()();

  /// Server user ID, or [localOwnerId] (as for personal overlays).
  TextColumn get ownerId => text()();
  TextColumn get songId => text().references(Songs, #id)();

  /// What is annotated: empty for the ChordPro text, otherwise the ID of a
  /// PDF attachment.
  TextColumn get target => text().withDefault(const Constant(''))();

  /// The stroke as JSON (`AnnotationStroke.toJson`); null for an erased
  /// stroke whose erase is not on the server yet (tombstone).
  TextColumn get stroke => text().nullable()();

  /// Last change in milliseconds since the epoch; also the drawing order.
  IntColumn get updatedAt => integer()();

  /// Grows with every local change not yet pushed; 0 = as on the server.
  IntColumn get pending => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
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

/// How often a band of an organization played a song of its library, as the
/// server summed it up at the last sync (ADR-0046, schema 26). Never the
/// sets themselves; replaced per organization with every sync.
@DataClassName('OrgPlay')
class OrgPlays extends Table {
  TextColumn get organizationId => text()();
  TextColumn get songId => text()();
  TextColumn get bandId => text()();
  TextColumn get bandName => text()();

  /// Past sets of the band with the song.
  IntColumn get playCount => integer()();
  DateTimeColumn get lastPlayed => dateTime()();

  /// The key of the most recent play with frozen values, if any.
  TextColumn get playedKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {songId, bandId};
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

/// What an entry of the [ChangeLog] is about (ADR-0045).
enum ChangeKind {
  /// A song new in the library.
  songAdded,

  /// A song's ChordPro text, or one of its PDF attachments.
  songChanged,

  /// Songs added to or removed from a set, or a changed song sequence of
  /// a set item or of the band's arrangement of a song in the set.
  setChanged,

  /// A set new in the band (#674); stored by name, so added last.
  setAdded,
}

/// Changes by other people that the sync applied on this device, for the
/// recent changes of the overview (ADR-0045, schema 24). Device-only,
/// never synced; entries older than 30 days are removed.
@TableIndex(name: 'change_log_scope', columns: {#scopeId, #at})
@DataClassName('ChangeLogRow')
class ChangeLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// When the sync applied the change on this device (compared with the
  /// overview's "last shown", also a time on this device).
  DateTimeColumn get at => dateTime()();
  TextColumn get kind => textEnum<ChangeKind>()();

  /// The organization of a song, the band of a set.
  TextColumn get scopeId => text()();

  /// The song or set.
  TextColumn get recordId => text()();

  /// Title of the song or name of the set at the time of the change.
  TextColumn get title => text()();

  /// Who made the change (`created_by` of a new song, otherwise
  /// `updated_by`).
  TextColumn get userId => text().nullable()();

  /// What changed, as the JSON of `ChangeDetails`.
  TextColumn get details => text().withDefault(const Constant('{}'))();
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
    BandArrangements,
    UserSettings,
    Annotations,
    SyncOutbox,
    SyncCursors,
    SongConflicts,
    ChangeLog,
    OrgPlays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 31;

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
            newColumns: [
              songs.searchText,
              songs.createdBy,
              songs.updatedBy,
              songs.sequence,
              songs.chordproProblems,
              songs.chordproConversions,
              songs.deletedAt,
              songs.purged,
              songs.workId,
              songs.language,
            ],
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
          // Tables of later schemas do not exist yet.
          if (index == annotationsOwnerSong || index == changeLogScope) {
            continue;
          }
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
            newColumns: [
              personalOverlays.ownerId,
              personalOverlays.revision,
              personalOverlays.hideAnnotations,
              personalOverlays.verseChords,
              personalOverlays.midi,
              personalOverlays.midiPrograms,
              personalOverlays.clickGrouping,
              personalOverlays.clickSubdivision,
            ],
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
      if (from < 11) {
        // Creator and last editor of songs (ADR-0023); before schema 4 the
        // rebuilt table has the columns already. The band setting
        // members_can_edit_songs is gone: the table is rebuilt without it.
        if (from >= 4) {
          await m.addColumn(songs, songs.createdBy);
          await m.addColumn(songs, songs.updatedBy);
        }
        // The threshold of schema 25 is not in the old table yet.
        await m.alterTable(
          TableMigration(bands, newColumns: [bands.staleAfterMonths]),
        );
      }
      if (from < 12) {
        // Band arrangements (ADR-0025).
        await m.createTable(bandArrangements);
      }
      if (from < 13) {
        // Song sequence for the song list: filled by afterUpgrade
        // (refreshAllMetadata); before schema 4 the rebuilt table has the
        // column already.
        if (from >= 4) await m.addColumn(songs, songs.sequence);
      }
      if (from < 14) {
        // ChordPro problems for the warning icons (#314): filled by
        // afterUpgrade (refreshAllMetadata); before schema 4 the rebuilt
        // table has the column already.
        if (from >= 4) await m.addColumn(songs, songs.chordproProblems);
      }
      if (from < 15) {
        // Personal settings per person (ADR-0027); the signed-out values
        // move here from the device settings when the app starts.
        await m.createTable(userSettings);
      }
      if (from < 16) {
        // Freehand annotations (ADR-0032); before schema 8 the rebuilt
        // overlay table has the column already.
        if (from >= 8) {
          await m.addColumn(personalOverlays, personalOverlays.hideAnnotations);
        }
        await m.createTable(annotations);
        await m.createIndex(annotationsOwnerSong);
      }
      if (from < 18 && from >= 8) {
        // How verses show their chords (#518, #521); before schema 8 the
        // rebuilt overlay table has the column already. Schema 17 had a
        // boolean for chords in the first verse only.
        await m.addColumn(personalOverlays, personalOverlays.verseChords);
        if (from == 17) {
          await customStatement(
            "UPDATE personal_overlays SET verse_chords = 'first' "
            'WHERE first_verse_chords_only = 1',
          );
          await customStatement(
            'ALTER TABLE personal_overlays DROP COLUMN first_verse_chords_only',
          );
        }
      }
      if (from < 19 && from >= 8) {
        // Keyboard program (ADR-0039); before schema 8 the rebuilt overlay
        // table has the column already.
        await m.addColumn(personalOverlays, personalOverlays.midi);
      }
      if (from < 20 && from >= 8) {
        // Keyboard programs per profile (ADR-0042).
        await m.addColumn(personalOverlays, personalOverlays.midiPrograms);
      }
      if (from < 21) {
        // Trash (ADR-0043); before schema 4 the rebuilt song table has the
        // columns already. Records deleted before count as deleted when
        // they were last changed.
        if (from >= 4) {
          await m.addColumn(songs, songs.deletedAt);
          await m.addColumn(songs, songs.purged);
        }
        await m.addColumn(attachments, attachments.deletedAt);
        await m.addColumn(attachments, attachments.purged);
        await m.addColumn(setlists, setlists.deletedAt);
        await m.addColumn(setlists, setlists.purged);
        for (final table in ['songs', 'attachments', 'setlists']) {
          await customStatement(
            'UPDATE $table SET deleted_at = updated_at WHERE deleted = 1',
          );
        }
      }
      if (from < 22) {
        // Last editor of sets and band arrangements (ADR-0045); before
        // schema 12 the new arrangement table has the column already.
        // Filled by the next change from the server.
        await m.addColumn(setlists, setlists.updatedBy);
        if (from >= 12) {
          await m.addColumn(bandArrangements, bandArrangements.updatedBy);
        }
      }
      if (from < 23) {
        // Song play history (ADR-0046): the values a song was played with,
        // and unknown item fields kept for newer clients.
        await m.addColumn(setItems, setItems.played);
        await m.addColumn(setItems, setItems.extra);
      }
      if (from < 24) {
        // Change log for the recent changes of the overview (ADR-0045);
        // starts empty.
        await m.createTable(changeLog);
        await m.createIndex(changeLogScope);
      }
      if (from < 25 && from >= 11) {
        // Band repertoire (ADR-0046); before schema 11 the rebuilt band
        // table has the column already.
        await m.addColumn(bands, bands.staleAfterMonths);
      }
      if (from < 26) {
        // Plays across the bands of an organization (ADR-0046); filled by
        // the next sync.
        await m.createTable(orgPlays);
      }
      if (from < 27 && from >= 8) {
        // Grouping and subdivisions of the click per song (#698); before
        // schema 8 the rebuilt overlay table has the columns already.
        await m.addColumn(personalOverlays, personalOverlays.clickGrouping);
        await m.addColumn(personalOverlays, personalOverlays.clickSubdivision);
      }
      if (from < 28) {
        // Origin of an imported set (ADR-0043 §1b, #707).
        await m.addColumn(setlists, setlists.origin);
      }
      if (from < 29) {
        // Set markers (ADR-0047): breaks and texts become markers with an
        // icon from their old type.
        await m.addColumn(setItems, setItems.icon);
        await customStatement(
          "UPDATE set_items SET icon = CASE type WHEN 'pause' THEN 'break' "
          "ELSE 'announcement' END, type = 'marker' WHERE type != 'song'",
        );
      }
      if (from < 30 && from >= 4) {
        // Possible conversions for the song list (#798): filled by
        // afterUpgrade (refreshAllMetadata); before schema 4 the rebuilt
        // table has the column already.
        await m.addColumn(songs, songs.chordproConversions);
      }
      if (from < 31 && from >= 4) {
        // Language versions (ADR-0053, #804); before schema 4 the rebuilt
        // table has the columns already.
        await m.addColumn(songs, songs.workId);
        await m.addColumn(songs, songs.language);
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
