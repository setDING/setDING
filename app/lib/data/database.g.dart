// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class SongsFts extends Table
    with TableInfo<SongsFts, SongsFt>, VirtualTableInfo<SongsFts, SongsFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SongsFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [title, artist, searchText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongsFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SongsFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongsFt(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
    );
  }

  @override
  SongsFts createAlias(String alias) {
    return SongsFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title, artist, search_text, content = \'songs\', content_rowid = \'rowid\', tokenize = \'unicode61 remove_diacritics 2\')';
}

class SongsFt extends DataClass implements Insertable<SongsFt> {
  final String title;
  final String artist;
  final String searchText;
  const SongsFt({
    required this.title,
    required this.artist,
    required this.searchText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['search_text'] = Variable<String>(searchText);
    return map;
  }

  SongsFtsCompanion toCompanion(bool nullToAbsent) {
    return SongsFtsCompanion(
      title: Value(title),
      artist: Value(artist),
      searchText: Value(searchText),
    );
  }

  factory SongsFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongsFt(
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      searchText: serializer.fromJson<String>(json['search_text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'search_text': serializer.toJson<String>(searchText),
    };
  }

  SongsFt copyWith({String? title, String? artist, String? searchText}) =>
      SongsFt(
        title: title ?? this.title,
        artist: artist ?? this.artist,
        searchText: searchText ?? this.searchText,
      );
  SongsFt copyWithCompanion(SongsFtsCompanion data) {
    return SongsFt(
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongsFt(')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('searchText: $searchText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, artist, searchText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongsFt &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.searchText == this.searchText);
}

class SongsFtsCompanion extends UpdateCompanion<SongsFt> {
  final Value<String> title;
  final Value<String> artist;
  final Value<String> searchText;
  final Value<int> rowid;
  const SongsFtsCompanion({
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsFtsCompanion.insert({
    required String title,
    required String artist,
    required String searchText,
    this.rowid = const Value.absent(),
  }) : title = Value(title),
       artist = Value(artist),
       searchText = Value(searchText);
  static Insertable<SongsFt> custom({
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? searchText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (searchText != null) 'search_text': searchText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsFtsCompanion copyWith({
    Value<String>? title,
    Value<String>? artist,
    Value<String>? searchText,
    Value<int>? rowid,
  }) {
    return SongsFtsCompanion(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      searchText: searchText ?? this.searchText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsFtsCompanion(')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('searchText: $searchText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, SongEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chordproSourceMeta = const VerificationMeta(
    'chordproSource',
  );
  @override
  late final GeneratedColumn<String> chordproSource = GeneratedColumn<String>(
    'chordpro_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _songKeyMeta = const VerificationMeta(
    'songKey',
  );
  @override
  late final GeneratedColumn<String> songKey = GeneratedColumn<String>(
    'song_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempoMeta = const VerificationMeta('tempo');
  @override
  late final GeneratedColumn<int> tempo = GeneratedColumn<int>(
    'tempo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<String> sequence = GeneratedColumn<String>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortTitleMeta = const VerificationMeta(
    'sortTitle',
  );
  @override
  late final GeneratedColumn<String> sortTitle = GeneratedColumn<String>(
    'sort_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortArtistMeta = const VerificationMeta(
    'sortArtist',
  );
  @override
  late final GeneratedColumn<String> sortArtist = GeneratedColumn<String>(
    'sort_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chordproProblemsMeta = const VerificationMeta(
    'chordproProblems',
  );
  @override
  late final GeneratedColumn<int> chordproProblems = GeneratedColumn<int>(
    'chordpro_problems',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purgedMeta = const VerificationMeta('purged');
  @override
  late final GeneratedColumn<bool> purged = GeneratedColumn<bool>(
    'purged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    chordproSource,
    title,
    artist,
    songKey,
    tempo,
    sequence,
    sortTitle,
    sortArtist,
    searchText,
    chordproProblems,
    tags,
    createdBy,
    updatedBy,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('chordpro_source')) {
      context.handle(
        _chordproSourceMeta,
        chordproSource.isAcceptableOrUnknown(
          data['chordpro_source']!,
          _chordproSourceMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('song_key')) {
      context.handle(
        _songKeyMeta,
        songKey.isAcceptableOrUnknown(data['song_key']!, _songKeyMeta),
      );
    }
    if (data.containsKey('tempo')) {
      context.handle(
        _tempoMeta,
        tempo.isAcceptableOrUnknown(data['tempo']!, _tempoMeta),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('sort_title')) {
      context.handle(
        _sortTitleMeta,
        sortTitle.isAcceptableOrUnknown(data['sort_title']!, _sortTitleMeta),
      );
    }
    if (data.containsKey('sort_artist')) {
      context.handle(
        _sortArtistMeta,
        sortArtist.isAcceptableOrUnknown(data['sort_artist']!, _sortArtistMeta),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    if (data.containsKey('chordpro_problems')) {
      context.handle(
        _chordproProblemsMeta,
        chordproProblems.isAcceptableOrUnknown(
          data['chordpro_problems']!,
          _chordproProblemsMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('purged')) {
      context.handle(
        _purgedMeta,
        purged.isAcceptableOrUnknown(data['purged']!, _purgedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      chordproSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chordpro_source'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      songKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_key'],
      ),
      tempo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tempo'],
      ),
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence'],
      ),
      sortTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_title'],
      ),
      sortArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_artist'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      ),
      chordproProblems: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chordpro_problems'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      purged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged'],
      )!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class SongEntry extends DataClass implements Insertable<SongEntry> {
  final String id;

  /// Song library the song belongs to: an organization ID (ADR-0017), or
  /// [localBandId] for the local library. Until schema 3: `band_id`.
  final String libraryId;

  /// ChordPro text – the single source of truth (ADR-0003).
  final String chordproSource;

  /// Redundant metadata for search and sorting.
  final String title;
  final String? artist;
  final String? songKey;
  final int? tempo;

  /// Raw `{x_sequence}` value, for the song list (schema 13).
  final String? sequence;

  /// `{sorttitle}` / `{sortartist}` for sorting (schema 2).
  final String? sortTitle;
  final String? sortArtist;

  /// Lyrics and comments without chords, for the full-text search
  /// (search.drift, schema 10).
  final String? searchText;

  /// Number of places where the ChordPro source probably does not do what
  /// the author meant (`validateChordPro`, schema 14, #314): derived on
  /// the device like [searchText], for the warning icons in lists.
  final int chordproProblems;

  /// `{tag}` values, each enclosed in newlines (`\nRock\nLive\n`) so a tag
  /// can be matched exactly with LIKE (schema 2).
  final String? tags;

  /// User who created the song and who changed it last, as the server
  /// reports them (ADR-0023, schema 11): band leaders may edit their own
  /// songs as long as nobody else has changed them. Null for the local
  /// library and for songs created before.
  final String? createdBy;
  final String? updatedBy;
  final int revision;
  final DateTime updatedAt;
  final bool deleted;

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  final DateTime? deletedAt;

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  final bool purged;
  const SongEntry({
    required this.id,
    required this.libraryId,
    required this.chordproSource,
    required this.title,
    this.artist,
    this.songKey,
    this.tempo,
    this.sequence,
    this.sortTitle,
    this.sortArtist,
    this.searchText,
    required this.chordproProblems,
    this.tags,
    this.createdBy,
    this.updatedBy,
    required this.revision,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    required this.purged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['chordpro_source'] = Variable<String>(chordproSource);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || songKey != null) {
      map['song_key'] = Variable<String>(songKey);
    }
    if (!nullToAbsent || tempo != null) {
      map['tempo'] = Variable<int>(tempo);
    }
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<String>(sequence);
    }
    if (!nullToAbsent || sortTitle != null) {
      map['sort_title'] = Variable<String>(sortTitle);
    }
    if (!nullToAbsent || sortArtist != null) {
      map['sort_artist'] = Variable<String>(sortArtist);
    }
    if (!nullToAbsent || searchText != null) {
      map['search_text'] = Variable<String>(searchText);
    }
    map['chordpro_problems'] = Variable<int>(chordproProblems);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['revision'] = Variable<int>(revision);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['purged'] = Variable<bool>(purged);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      chordproSource: Value(chordproSource),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      songKey: songKey == null && nullToAbsent
          ? const Value.absent()
          : Value(songKey),
      tempo: tempo == null && nullToAbsent
          ? const Value.absent()
          : Value(tempo),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
      sortTitle: sortTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sortTitle),
      sortArtist: sortArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(sortArtist),
      searchText: searchText == null && nullToAbsent
          ? const Value.absent()
          : Value(searchText),
      chordproProblems: Value(chordproProblems),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      revision: Value(revision),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      purged: Value(purged),
    );
  }

  factory SongEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongEntry(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      chordproSource: serializer.fromJson<String>(json['chordproSource']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      songKey: serializer.fromJson<String?>(json['songKey']),
      tempo: serializer.fromJson<int?>(json['tempo']),
      sequence: serializer.fromJson<String?>(json['sequence']),
      sortTitle: serializer.fromJson<String?>(json['sortTitle']),
      sortArtist: serializer.fromJson<String?>(json['sortArtist']),
      searchText: serializer.fromJson<String?>(json['searchText']),
      chordproProblems: serializer.fromJson<int>(json['chordproProblems']),
      tags: serializer.fromJson<String?>(json['tags']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      revision: serializer.fromJson<int>(json['revision']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      purged: serializer.fromJson<bool>(json['purged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'chordproSource': serializer.toJson<String>(chordproSource),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'songKey': serializer.toJson<String?>(songKey),
      'tempo': serializer.toJson<int?>(tempo),
      'sequence': serializer.toJson<String?>(sequence),
      'sortTitle': serializer.toJson<String?>(sortTitle),
      'sortArtist': serializer.toJson<String?>(sortArtist),
      'searchText': serializer.toJson<String?>(searchText),
      'chordproProblems': serializer.toJson<int>(chordproProblems),
      'tags': serializer.toJson<String?>(tags),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'revision': serializer.toJson<int>(revision),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'purged': serializer.toJson<bool>(purged),
    };
  }

  SongEntry copyWith({
    String? id,
    String? libraryId,
    String? chordproSource,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> songKey = const Value.absent(),
    Value<int?> tempo = const Value.absent(),
    Value<String?> sequence = const Value.absent(),
    Value<String?> sortTitle = const Value.absent(),
    Value<String?> sortArtist = const Value.absent(),
    Value<String?> searchText = const Value.absent(),
    int? chordproProblems,
    Value<String?> tags = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    int? revision,
    DateTime? updatedAt,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? purged,
  }) => SongEntry(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    chordproSource: chordproSource ?? this.chordproSource,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    songKey: songKey.present ? songKey.value : this.songKey,
    tempo: tempo.present ? tempo.value : this.tempo,
    sequence: sequence.present ? sequence.value : this.sequence,
    sortTitle: sortTitle.present ? sortTitle.value : this.sortTitle,
    sortArtist: sortArtist.present ? sortArtist.value : this.sortArtist,
    searchText: searchText.present ? searchText.value : this.searchText,
    chordproProblems: chordproProblems ?? this.chordproProblems,
    tags: tags.present ? tags.value : this.tags,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    purged: purged ?? this.purged,
  );
  SongEntry copyWithCompanion(SongsCompanion data) {
    return SongEntry(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      chordproSource: data.chordproSource.present
          ? data.chordproSource.value
          : this.chordproSource,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      songKey: data.songKey.present ? data.songKey.value : this.songKey,
      tempo: data.tempo.present ? data.tempo.value : this.tempo,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      sortTitle: data.sortTitle.present ? data.sortTitle.value : this.sortTitle,
      sortArtist: data.sortArtist.present
          ? data.sortArtist.value
          : this.sortArtist,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      chordproProblems: data.chordproProblems.present
          ? data.chordproProblems.value
          : this.chordproProblems,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      revision: data.revision.present ? data.revision.value : this.revision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      purged: data.purged.present ? data.purged.value : this.purged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongEntry(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('chordproSource: $chordproSource, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('songKey: $songKey, ')
          ..write('tempo: $tempo, ')
          ..write('sequence: $sequence, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('sortArtist: $sortArtist, ')
          ..write('searchText: $searchText, ')
          ..write('chordproProblems: $chordproProblems, ')
          ..write('tags: $tags, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    chordproSource,
    title,
    artist,
    songKey,
    tempo,
    sequence,
    sortTitle,
    sortArtist,
    searchText,
    chordproProblems,
    tags,
    createdBy,
    updatedBy,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongEntry &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.chordproSource == this.chordproSource &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.songKey == this.songKey &&
          other.tempo == this.tempo &&
          other.sequence == this.sequence &&
          other.sortTitle == this.sortTitle &&
          other.sortArtist == this.sortArtist &&
          other.searchText == this.searchText &&
          other.chordproProblems == this.chordproProblems &&
          other.tags == this.tags &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.revision == this.revision &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.purged == this.purged);
}

class SongsCompanion extends UpdateCompanion<SongEntry> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> chordproSource;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> songKey;
  final Value<int?> tempo;
  final Value<String?> sequence;
  final Value<String?> sortTitle;
  final Value<String?> sortArtist;
  final Value<String?> searchText;
  final Value<int> chordproProblems;
  final Value<String?> tags;
  final Value<String?> createdBy;
  final Value<String?> updatedBy;
  final Value<int> revision;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<bool> purged;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.chordproSource = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.songKey = const Value.absent(),
    this.tempo = const Value.absent(),
    this.sequence = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.sortArtist = const Value.absent(),
    this.searchText = const Value.absent(),
    this.chordproProblems = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String libraryId,
    this.chordproSource = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
    this.songKey = const Value.absent(),
    this.tempo = const Value.absent(),
    this.sequence = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.sortArtist = const Value.absent(),
    this.searchText = const Value.absent(),
    this.chordproProblems = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<SongEntry> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? chordproSource,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? songKey,
    Expression<int>? tempo,
    Expression<String>? sequence,
    Expression<String>? sortTitle,
    Expression<String>? sortArtist,
    Expression<String>? searchText,
    Expression<int>? chordproProblems,
    Expression<String>? tags,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? revision,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<bool>? purged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (chordproSource != null) 'chordpro_source': chordproSource,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (songKey != null) 'song_key': songKey,
      if (tempo != null) 'tempo': tempo,
      if (sequence != null) 'sequence': sequence,
      if (sortTitle != null) 'sort_title': sortTitle,
      if (sortArtist != null) 'sort_artist': sortArtist,
      if (searchText != null) 'search_text': searchText,
      if (chordproProblems != null) 'chordpro_problems': chordproProblems,
      if (tags != null) 'tags': tags,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (revision != null) 'revision': revision,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (purged != null) 'purged': purged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? chordproSource,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? songKey,
    Value<int?>? tempo,
    Value<String?>? sequence,
    Value<String?>? sortTitle,
    Value<String?>? sortArtist,
    Value<String?>? searchText,
    Value<int>? chordproProblems,
    Value<String?>? tags,
    Value<String?>? createdBy,
    Value<String?>? updatedBy,
    Value<int>? revision,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<bool>? purged,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      chordproSource: chordproSource ?? this.chordproSource,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      songKey: songKey ?? this.songKey,
      tempo: tempo ?? this.tempo,
      sequence: sequence ?? this.sequence,
      sortTitle: sortTitle ?? this.sortTitle,
      sortArtist: sortArtist ?? this.sortArtist,
      searchText: searchText ?? this.searchText,
      chordproProblems: chordproProblems ?? this.chordproProblems,
      tags: tags ?? this.tags,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      purged: purged ?? this.purged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (chordproSource.present) {
      map['chordpro_source'] = Variable<String>(chordproSource.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (songKey.present) {
      map['song_key'] = Variable<String>(songKey.value);
    }
    if (tempo.present) {
      map['tempo'] = Variable<int>(tempo.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<String>(sequence.value);
    }
    if (sortTitle.present) {
      map['sort_title'] = Variable<String>(sortTitle.value);
    }
    if (sortArtist.present) {
      map['sort_artist'] = Variable<String>(sortArtist.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (chordproProblems.present) {
      map['chordpro_problems'] = Variable<int>(chordproProblems.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (purged.present) {
      map['purged'] = Variable<bool>(purged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('chordproSource: $chordproSource, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('songKey: $songKey, ')
          ..write('tempo: $tempo, ')
          ..write('sequence: $sequence, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('sortArtist: $sortArtist, ')
          ..write('searchText: $searchText, ')
          ..write('chordproProblems: $chordproProblems, ')
          ..write('tags: $tags, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrganizationsTable extends Organizations
    with TableInfo<$OrganizationsTable, OrganizationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, revision, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'organizations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrganizationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrganizationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrganizationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $OrganizationsTable createAlias(String alias) {
    return $OrganizationsTable(attachedDatabase, alias);
  }
}

class OrganizationEntry extends DataClass
    implements Insertable<OrganizationEntry> {
  final String id;
  final String name;
  final int revision;

  /// The organization is no longer available to this device.
  final bool deleted;
  const OrganizationEntry({
    required this.id,
    required this.name,
    required this.revision,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['revision'] = Variable<int>(revision);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  OrganizationsCompanion toCompanion(bool nullToAbsent) {
    return OrganizationsCompanion(
      id: Value(id),
      name: Value(name),
      revision: Value(revision),
      deleted: Value(deleted),
    );
  }

  factory OrganizationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrganizationEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      revision: serializer.fromJson<int>(json['revision']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'revision': serializer.toJson<int>(revision),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  OrganizationEntry copyWith({
    String? id,
    String? name,
    int? revision,
    bool? deleted,
  }) => OrganizationEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    deleted: deleted ?? this.deleted,
  );
  OrganizationEntry copyWithCompanion(OrganizationsCompanion data) {
    return OrganizationEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      revision: data.revision.present ? data.revision.value : this.revision,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, revision, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrganizationEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.revision == this.revision &&
          other.deleted == this.deleted);
}

class OrganizationsCompanion extends UpdateCompanion<OrganizationEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> revision;
  final Value<bool> deleted;
  final Value<int> rowid;
  const OrganizationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrganizationsCompanion.insert({
    required String id,
    required String name,
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<OrganizationEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? revision,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (revision != null) 'revision': revision,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrganizationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? revision,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return OrganizationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      revision: revision ?? this.revision,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrgMembershipsTable extends OrgMemberships
    with TableInfo<$OrgMembershipsTable, OrgMembershipEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrgMembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userEmailMeta = const VerificationMeta(
    'userEmail',
  );
  @override
  late final GeneratedColumn<String> userEmail = GeneratedColumn<String>(
    'user_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OrgRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OrgRole>($OrgMembershipsTable.$converterrole);
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    userId,
    userName,
    userEmail,
    role,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'org_memberships';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrgMembershipEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_organizationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    }
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrgMembershipEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrgMembershipEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
      ),
      role: $OrgMembershipsTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $OrgMembershipsTable createAlias(String alias) {
    return $OrgMembershipsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OrgRole, String, String> $converterrole =
      const EnumNameConverter<OrgRole>(OrgRole.values);
}

class OrgMembershipEntry extends DataClass
    implements Insertable<OrgMembershipEntry> {
  final String id;
  final String organizationId;
  final String userId;
  final String userName;
  final String? userEmail;

  /// Stored by name, so schema 11 kept the values of [BandRole] it had
  /// before (`admin`, `member`) and added `librarian` (ADR-0023).
  final OrgRole role;
  final int revision;
  const OrgMembershipEntry({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.role,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['user_id'] = Variable<String>(userId);
    map['user_name'] = Variable<String>(userName);
    if (!nullToAbsent || userEmail != null) {
      map['user_email'] = Variable<String>(userEmail);
    }
    {
      map['role'] = Variable<String>(
        $OrgMembershipsTable.$converterrole.toSql(role),
      );
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  OrgMembershipsCompanion toCompanion(bool nullToAbsent) {
    return OrgMembershipsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      userId: Value(userId),
      userName: Value(userName),
      userEmail: userEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(userEmail),
      role: Value(role),
      revision: Value(revision),
    );
  }

  factory OrgMembershipEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrgMembershipEntry(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      userId: serializer.fromJson<String>(json['userId']),
      userName: serializer.fromJson<String>(json['userName']),
      userEmail: serializer.fromJson<String?>(json['userEmail']),
      role: $OrgMembershipsTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'userId': serializer.toJson<String>(userId),
      'userName': serializer.toJson<String>(userName),
      'userEmail': serializer.toJson<String?>(userEmail),
      'role': serializer.toJson<String>(
        $OrgMembershipsTable.$converterrole.toJson(role),
      ),
      'revision': serializer.toJson<int>(revision),
    };
  }

  OrgMembershipEntry copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? userName,
    Value<String?> userEmail = const Value.absent(),
    OrgRole? role,
    int? revision,
  }) => OrgMembershipEntry(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    userEmail: userEmail.present ? userEmail.value : this.userEmail,
    role: role ?? this.role,
    revision: revision ?? this.revision,
  );
  OrgMembershipEntry copyWithCompanion(OrgMembershipsCompanion data) {
    return OrgMembershipEntry(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      userName: data.userName.present ? data.userName.value : this.userName,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      role: data.role.present ? data.role.value : this.role,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrgMembershipEntry(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('role: $role, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    userId,
    userName,
    userEmail,
    role,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrgMembershipEntry &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.userId == this.userId &&
          other.userName == this.userName &&
          other.userEmail == this.userEmail &&
          other.role == this.role &&
          other.revision == this.revision);
}

class OrgMembershipsCompanion extends UpdateCompanion<OrgMembershipEntry> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> userId;
  final Value<String> userName;
  final Value<String?> userEmail;
  final Value<OrgRole> role;
  final Value<int> revision;
  final Value<int> rowid;
  const OrgMembershipsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.role = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrgMembershipsCompanion.insert({
    required String id,
    required String organizationId,
    required String userId,
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    required OrgRole role,
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       userId = Value(userId),
       role = Value(role);
  static Insertable<OrgMembershipEntry> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? userId,
    Expression<String>? userName,
    Expression<String>? userEmail,
    Expression<String>? role,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (role != null) 'role': role,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrgMembershipsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? userId,
    Value<String>? userName,
    Value<String?>? userEmail,
    Value<OrgRole>? role,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return OrgMembershipsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      role: role ?? this.role,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $OrgMembershipsTable.$converterrole.toSql(role.value),
      );
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrgMembershipsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('role: $role, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BandsTable extends Bands with TableInfo<$BandsTable, BandEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _staleAfterMonthsMeta = const VerificationMeta(
    'staleAfterMonths',
  );
  @override
  late final GeneratedColumn<int> staleAfterMonths = GeneratedColumn<int>(
    'stale_after_months',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    organizationId,
    revision,
    deleted,
    staleAfterMonths,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bands';
  @override
  VerificationContext validateIntegrity(
    Insertable<BandEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('stale_after_months')) {
      context.handle(
        _staleAfterMonthsMeta,
        staleAfterMonths.isAcceptableOrUnknown(
          data['stale_after_months']!,
          _staleAfterMonthsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BandEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BandEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      staleAfterMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stale_after_months'],
      )!,
    );
  }

  @override
  $BandsTable createAlias(String alias) {
    return $BandsTable(attachedDatabase, alias);
  }
}

class BandEntry extends DataClass implements Insertable<BandEntry> {
  final String id;
  final String name;

  /// Organization of the band; null for the local library (schema 4).
  final String? organizationId;

  /// Server revision (ADR-0015); 0 for the local library (schema 4).
  final int revision;

  /// The band is no longer available to this device (schema 4).
  final bool deleted;

  /// Months after which a song counts as not played for a while
  /// (ADR-0046); 0 = the default (schema 25).
  final int staleAfterMonths;
  const BandEntry({
    required this.id,
    required this.name,
    this.organizationId,
    required this.revision,
    required this.deleted,
    required this.staleAfterMonths,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    map['revision'] = Variable<int>(revision);
    map['deleted'] = Variable<bool>(deleted);
    map['stale_after_months'] = Variable<int>(staleAfterMonths);
    return map;
  }

  BandsCompanion toCompanion(bool nullToAbsent) {
    return BandsCompanion(
      id: Value(id),
      name: Value(name),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      revision: Value(revision),
      deleted: Value(deleted),
      staleAfterMonths: Value(staleAfterMonths),
    );
  }

  factory BandEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BandEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      revision: serializer.fromJson<int>(json['revision']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      staleAfterMonths: serializer.fromJson<int>(json['staleAfterMonths']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'organizationId': serializer.toJson<String?>(organizationId),
      'revision': serializer.toJson<int>(revision),
      'deleted': serializer.toJson<bool>(deleted),
      'staleAfterMonths': serializer.toJson<int>(staleAfterMonths),
    };
  }

  BandEntry copyWith({
    String? id,
    String? name,
    Value<String?> organizationId = const Value.absent(),
    int? revision,
    bool? deleted,
    int? staleAfterMonths,
  }) => BandEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    revision: revision ?? this.revision,
    deleted: deleted ?? this.deleted,
    staleAfterMonths: staleAfterMonths ?? this.staleAfterMonths,
  );
  BandEntry copyWithCompanion(BandsCompanion data) {
    return BandEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      revision: data.revision.present ? data.revision.value : this.revision,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      staleAfterMonths: data.staleAfterMonths.present
          ? data.staleAfterMonths.value
          : this.staleAfterMonths,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BandEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('organizationId: $organizationId, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('staleAfterMonths: $staleAfterMonths')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    organizationId,
    revision,
    deleted,
    staleAfterMonths,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BandEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.organizationId == this.organizationId &&
          other.revision == this.revision &&
          other.deleted == this.deleted &&
          other.staleAfterMonths == this.staleAfterMonths);
}

class BandsCompanion extends UpdateCompanion<BandEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> organizationId;
  final Value<int> revision;
  final Value<bool> deleted;
  final Value<int> staleAfterMonths;
  final Value<int> rowid;
  const BandsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.staleAfterMonths = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BandsCompanion.insert({
    required String id,
    required String name,
    this.organizationId = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.staleAfterMonths = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<BandEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? organizationId,
    Expression<int>? revision,
    Expression<bool>? deleted,
    Expression<int>? staleAfterMonths,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (organizationId != null) 'organization_id': organizationId,
      if (revision != null) 'revision': revision,
      if (deleted != null) 'deleted': deleted,
      if (staleAfterMonths != null) 'stale_after_months': staleAfterMonths,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BandsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? organizationId,
    Value<int>? revision,
    Value<bool>? deleted,
    Value<int>? staleAfterMonths,
    Value<int>? rowid,
  }) {
    return BandsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      revision: revision ?? this.revision,
      deleted: deleted ?? this.deleted,
      staleAfterMonths: staleAfterMonths ?? this.staleAfterMonths,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (staleAfterMonths.present) {
      map['stale_after_months'] = Variable<int>(staleAfterMonths.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BandsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('organizationId: $organizationId, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('staleAfterMonths: $staleAfterMonths, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembershipsTable extends Memberships
    with TableInfo<$MembershipsTable, MembershipEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandIdMeta = const VerificationMeta('bandId');
  @override
  late final GeneratedColumn<String> bandId = GeneratedColumn<String>(
    'band_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bands (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userEmailMeta = const VerificationMeta(
    'userEmail',
  );
  @override
  late final GeneratedColumn<String> userEmail = GeneratedColumn<String>(
    'user_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BandRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BandRole>($MembershipsTable.$converterrole);
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bandId,
    userId,
    userName,
    userEmail,
    role,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memberships';
  @override
  VerificationContext validateIntegrity(
    Insertable<MembershipEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('band_id')) {
      context.handle(
        _bandIdMeta,
        bandId.isAcceptableOrUnknown(data['band_id']!, _bandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bandIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    }
    if (data.containsKey('user_email')) {
      context.handle(
        _userEmailMeta,
        userEmail.isAcceptableOrUnknown(data['user_email']!, _userEmailMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MembershipEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MembershipEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      userEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_email'],
      ),
      role: $MembershipsTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $MembershipsTable createAlias(String alias) {
    return $MembershipsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BandRole, String, String> $converterrole =
      const EnumNameConverter<BandRole>(BandRole.values);
}

class MembershipEntry extends DataClass implements Insertable<MembershipEntry> {
  final String id;
  final String bandId;
  final String userId;

  /// Name of the user at the time of the last refresh.
  final String userName;
  final String? userEmail;
  final BandRole role;
  final int revision;
  const MembershipEntry({
    required this.id,
    required this.bandId,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.role,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['band_id'] = Variable<String>(bandId);
    map['user_id'] = Variable<String>(userId);
    map['user_name'] = Variable<String>(userName);
    if (!nullToAbsent || userEmail != null) {
      map['user_email'] = Variable<String>(userEmail);
    }
    {
      map['role'] = Variable<String>(
        $MembershipsTable.$converterrole.toSql(role),
      );
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  MembershipsCompanion toCompanion(bool nullToAbsent) {
    return MembershipsCompanion(
      id: Value(id),
      bandId: Value(bandId),
      userId: Value(userId),
      userName: Value(userName),
      userEmail: userEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(userEmail),
      role: Value(role),
      revision: Value(revision),
    );
  }

  factory MembershipEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MembershipEntry(
      id: serializer.fromJson<String>(json['id']),
      bandId: serializer.fromJson<String>(json['bandId']),
      userId: serializer.fromJson<String>(json['userId']),
      userName: serializer.fromJson<String>(json['userName']),
      userEmail: serializer.fromJson<String?>(json['userEmail']),
      role: $MembershipsTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bandId': serializer.toJson<String>(bandId),
      'userId': serializer.toJson<String>(userId),
      'userName': serializer.toJson<String>(userName),
      'userEmail': serializer.toJson<String?>(userEmail),
      'role': serializer.toJson<String>(
        $MembershipsTable.$converterrole.toJson(role),
      ),
      'revision': serializer.toJson<int>(revision),
    };
  }

  MembershipEntry copyWith({
    String? id,
    String? bandId,
    String? userId,
    String? userName,
    Value<String?> userEmail = const Value.absent(),
    BandRole? role,
    int? revision,
  }) => MembershipEntry(
    id: id ?? this.id,
    bandId: bandId ?? this.bandId,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    userEmail: userEmail.present ? userEmail.value : this.userEmail,
    role: role ?? this.role,
    revision: revision ?? this.revision,
  );
  MembershipEntry copyWithCompanion(MembershipsCompanion data) {
    return MembershipEntry(
      id: data.id.present ? data.id.value : this.id,
      bandId: data.bandId.present ? data.bandId.value : this.bandId,
      userId: data.userId.present ? data.userId.value : this.userId,
      userName: data.userName.present ? data.userName.value : this.userName,
      userEmail: data.userEmail.present ? data.userEmail.value : this.userEmail,
      role: data.role.present ? data.role.value : this.role,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MembershipEntry(')
          ..write('id: $id, ')
          ..write('bandId: $bandId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('role: $role, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bandId, userId, userName, userEmail, role, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MembershipEntry &&
          other.id == this.id &&
          other.bandId == this.bandId &&
          other.userId == this.userId &&
          other.userName == this.userName &&
          other.userEmail == this.userEmail &&
          other.role == this.role &&
          other.revision == this.revision);
}

class MembershipsCompanion extends UpdateCompanion<MembershipEntry> {
  final Value<String> id;
  final Value<String> bandId;
  final Value<String> userId;
  final Value<String> userName;
  final Value<String?> userEmail;
  final Value<BandRole> role;
  final Value<int> revision;
  final Value<int> rowid;
  const MembershipsCompanion({
    this.id = const Value.absent(),
    this.bandId = const Value.absent(),
    this.userId = const Value.absent(),
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    this.role = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembershipsCompanion.insert({
    required String id,
    required String bandId,
    required String userId,
    this.userName = const Value.absent(),
    this.userEmail = const Value.absent(),
    required BandRole role,
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bandId = Value(bandId),
       userId = Value(userId),
       role = Value(role);
  static Insertable<MembershipEntry> custom({
    Expression<String>? id,
    Expression<String>? bandId,
    Expression<String>? userId,
    Expression<String>? userName,
    Expression<String>? userEmail,
    Expression<String>? role,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bandId != null) 'band_id': bandId,
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (role != null) 'role': role,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembershipsCompanion copyWith({
    Value<String>? id,
    Value<String>? bandId,
    Value<String>? userId,
    Value<String>? userName,
    Value<String?>? userEmail,
    Value<BandRole>? role,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return MembershipsCompanion(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      role: role ?? this.role,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bandId.present) {
      map['band_id'] = Variable<String>(bandId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (userEmail.present) {
      map['user_email'] = Variable<String>(userEmail.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $MembershipsTable.$converterrole.toSql(role.value),
      );
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembershipsCompanion(')
          ..write('id: $id, ')
          ..write('bandId: $bandId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('userEmail: $userEmail, ')
          ..write('role: $role, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteFileMeta = const VerificationMeta(
    'remoteFile',
  );
  @override
  late final GeneratedColumn<String> remoteFile = GeneratedColumn<String>(
    'remote_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purgedMeta = const VerificationMeta('purged');
  @override
  late final GeneratedColumn<bool> purged = GeneratedColumn<bool>(
    'purged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    name,
    fileName,
    remoteFile,
    pages,
    sizeBytes,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('remote_file')) {
      context.handle(
        _remoteFileMeta,
        remoteFile.isAcceptableOrUnknown(data['remote_file']!, _remoteFileMeta),
      );
    }
    if (data.containsKey('pages')) {
      context.handle(
        _pagesMeta,
        pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('purged')) {
      context.handle(
        _purgedMeta,
        purged.isAcceptableOrUnknown(data['purged']!, _purgedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      remoteFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_file'],
      ),
      pages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      purged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentEntry extends DataClass implements Insertable<AttachmentEntry> {
  final String id;
  final String songId;
  final String name;

  /// File name inside the attachment directory.
  final String fileName;

  /// Name of the file on the server, null until uploaded or for local-only
  /// attachments; a missing local file is downloaded with it (schema 6).
  final String? remoteFile;
  final int? pages;
  final int sizeBytes;
  final int revision;
  final DateTime updatedAt;
  final bool deleted;

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  final DateTime? deletedAt;

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  final bool purged;
  const AttachmentEntry({
    required this.id,
    required this.songId,
    required this.name,
    required this.fileName,
    this.remoteFile,
    this.pages,
    required this.sizeBytes,
    required this.revision,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    required this.purged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['name'] = Variable<String>(name);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || remoteFile != null) {
      map['remote_file'] = Variable<String>(remoteFile);
    }
    if (!nullToAbsent || pages != null) {
      map['pages'] = Variable<int>(pages);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['revision'] = Variable<int>(revision);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['purged'] = Variable<bool>(purged);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      songId: Value(songId),
      name: Value(name),
      fileName: Value(fileName),
      remoteFile: remoteFile == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteFile),
      pages: pages == null && nullToAbsent
          ? const Value.absent()
          : Value(pages),
      sizeBytes: Value(sizeBytes),
      revision: Value(revision),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      purged: Value(purged),
    );
  }

  factory AttachmentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentEntry(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      name: serializer.fromJson<String>(json['name']),
      fileName: serializer.fromJson<String>(json['fileName']),
      remoteFile: serializer.fromJson<String?>(json['remoteFile']),
      pages: serializer.fromJson<int?>(json['pages']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      revision: serializer.fromJson<int>(json['revision']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      purged: serializer.fromJson<bool>(json['purged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'name': serializer.toJson<String>(name),
      'fileName': serializer.toJson<String>(fileName),
      'remoteFile': serializer.toJson<String?>(remoteFile),
      'pages': serializer.toJson<int?>(pages),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'revision': serializer.toJson<int>(revision),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'purged': serializer.toJson<bool>(purged),
    };
  }

  AttachmentEntry copyWith({
    String? id,
    String? songId,
    String? name,
    String? fileName,
    Value<String?> remoteFile = const Value.absent(),
    Value<int?> pages = const Value.absent(),
    int? sizeBytes,
    int? revision,
    DateTime? updatedAt,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? purged,
  }) => AttachmentEntry(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    name: name ?? this.name,
    fileName: fileName ?? this.fileName,
    remoteFile: remoteFile.present ? remoteFile.value : this.remoteFile,
    pages: pages.present ? pages.value : this.pages,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    purged: purged ?? this.purged,
  );
  AttachmentEntry copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentEntry(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      name: data.name.present ? data.name.value : this.name,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      remoteFile: data.remoteFile.present
          ? data.remoteFile.value
          : this.remoteFile,
      pages: data.pages.present ? data.pages.value : this.pages,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      revision: data.revision.present ? data.revision.value : this.revision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      purged: data.purged.present ? data.purged.value : this.purged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentEntry(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('name: $name, ')
          ..write('fileName: $fileName, ')
          ..write('remoteFile: $remoteFile, ')
          ..write('pages: $pages, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songId,
    name,
    fileName,
    remoteFile,
    pages,
    sizeBytes,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentEntry &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.name == this.name &&
          other.fileName == this.fileName &&
          other.remoteFile == this.remoteFile &&
          other.pages == this.pages &&
          other.sizeBytes == this.sizeBytes &&
          other.revision == this.revision &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.purged == this.purged);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentEntry> {
  final Value<String> id;
  final Value<String> songId;
  final Value<String> name;
  final Value<String> fileName;
  final Value<String?> remoteFile;
  final Value<int?> pages;
  final Value<int> sizeBytes;
  final Value<int> revision;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<bool> purged;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.name = const Value.absent(),
    this.fileName = const Value.absent(),
    this.remoteFile = const Value.absent(),
    this.pages = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.revision = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String songId,
    required String name,
    required String fileName,
    this.remoteFile = const Value.absent(),
    this.pages = const Value.absent(),
    required int sizeBytes,
    this.revision = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       name = Value(name),
       fileName = Value(fileName),
       sizeBytes = Value(sizeBytes),
       updatedAt = Value(updatedAt);
  static Insertable<AttachmentEntry> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<String>? name,
    Expression<String>? fileName,
    Expression<String>? remoteFile,
    Expression<int>? pages,
    Expression<int>? sizeBytes,
    Expression<int>? revision,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<bool>? purged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (name != null) 'name': name,
      if (fileName != null) 'file_name': fileName,
      if (remoteFile != null) 'remote_file': remoteFile,
      if (pages != null) 'pages': pages,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (revision != null) 'revision': revision,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (purged != null) 'purged': purged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<String>? name,
    Value<String>? fileName,
    Value<String?>? remoteFile,
    Value<int?>? pages,
    Value<int>? sizeBytes,
    Value<int>? revision,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<bool>? purged,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      remoteFile: remoteFile ?? this.remoteFile,
      pages: pages ?? this.pages,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      purged: purged ?? this.purged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (remoteFile.present) {
      map['remote_file'] = Variable<String>(remoteFile.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (purged.present) {
      map['purged'] = Variable<bool>(purged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('name: $name, ')
          ..write('fileName: $fileName, ')
          ..write('remoteFile: $remoteFile, ')
          ..write('pages: $pages, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistsTable extends Setlists
    with TableInfo<$SetlistsTable, SetlistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandIdMeta = const VerificationMeta('bandId');
  @override
  late final GeneratedColumn<String> bandId = GeneratedColumn<String>(
    'band_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bands (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gigDateMeta = const VerificationMeta(
    'gigDate',
  );
  @override
  late final GeneratedColumn<DateTime> gigDate = GeneratedColumn<DateTime>(
    'gig_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _venueMeta = const VerificationMeta('venue');
  @override
  late final GeneratedColumn<String> venue = GeneratedColumn<String>(
    'venue',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purgedMeta = const VerificationMeta('purged');
  @override
  late final GeneratedColumn<bool> purged = GeneratedColumn<bool>(
    'purged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("purged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bandId,
    name,
    gigDate,
    venue,
    origin,
    updatedBy,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetlistEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('band_id')) {
      context.handle(
        _bandIdMeta,
        bandId.isAcceptableOrUnknown(data['band_id']!, _bandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bandIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('gig_date')) {
      context.handle(
        _gigDateMeta,
        gigDate.isAcceptableOrUnknown(data['gig_date']!, _gigDateMeta),
      );
    }
    if (data.containsKey('venue')) {
      context.handle(
        _venueMeta,
        venue.isAcceptableOrUnknown(data['venue']!, _venueMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('purged')) {
      context.handle(
        _purgedMeta,
        purged.isAcceptableOrUnknown(data['purged']!, _purgedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetlistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetlistEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      gigDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gig_date'],
      ),
      venue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}venue'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      purged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}purged'],
      )!,
    );
  }

  @override
  $SetlistsTable createAlias(String alias) {
    return $SetlistsTable(attachedDatabase, alias);
  }
}

class SetlistEntry extends DataClass implements Insertable<SetlistEntry> {
  final String id;
  final String bandId;
  final String name;
  final DateTime? gigDate;
  final String? venue;

  /// The set this one was imported from, for re-importing a set archive
  /// (ADR-0043 §1b, schema 28): the original ID of the exported set (or its
  /// own origin). Null for sets made in the app.
  final String? origin;

  /// User who changed the set last, as the server reports it (ADR-0045,
  /// schema 22): for the recent changes of the overview. Null for the
  /// local band and for sets synced before.
  final String? updatedBy;
  final int revision;
  final DateTime updatedAt;
  final bool deleted;

  /// When the record was deleted, for the trash (ADR-0043, schema 21).
  final DateTime? deletedAt;

  /// The server purged the deleted record's content after 30 days
  /// (ADR-0043, schema 21): it is no longer in the trash.
  final bool purged;
  const SetlistEntry({
    required this.id,
    required this.bandId,
    required this.name,
    this.gigDate,
    this.venue,
    this.origin,
    this.updatedBy,
    required this.revision,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    required this.purged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['band_id'] = Variable<String>(bandId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || gigDate != null) {
      map['gig_date'] = Variable<DateTime>(gigDate);
    }
    if (!nullToAbsent || venue != null) {
      map['venue'] = Variable<String>(venue);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['revision'] = Variable<int>(revision);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['purged'] = Variable<bool>(purged);
    return map;
  }

  SetlistsCompanion toCompanion(bool nullToAbsent) {
    return SetlistsCompanion(
      id: Value(id),
      bandId: Value(bandId),
      name: Value(name),
      gigDate: gigDate == null && nullToAbsent
          ? const Value.absent()
          : Value(gigDate),
      venue: venue == null && nullToAbsent
          ? const Value.absent()
          : Value(venue),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      revision: Value(revision),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      purged: Value(purged),
    );
  }

  factory SetlistEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetlistEntry(
      id: serializer.fromJson<String>(json['id']),
      bandId: serializer.fromJson<String>(json['bandId']),
      name: serializer.fromJson<String>(json['name']),
      gigDate: serializer.fromJson<DateTime?>(json['gigDate']),
      venue: serializer.fromJson<String?>(json['venue']),
      origin: serializer.fromJson<String?>(json['origin']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      revision: serializer.fromJson<int>(json['revision']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      purged: serializer.fromJson<bool>(json['purged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bandId': serializer.toJson<String>(bandId),
      'name': serializer.toJson<String>(name),
      'gigDate': serializer.toJson<DateTime?>(gigDate),
      'venue': serializer.toJson<String?>(venue),
      'origin': serializer.toJson<String?>(origin),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'revision': serializer.toJson<int>(revision),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'purged': serializer.toJson<bool>(purged),
    };
  }

  SetlistEntry copyWith({
    String? id,
    String? bandId,
    String? name,
    Value<DateTime?> gigDate = const Value.absent(),
    Value<String?> venue = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    int? revision,
    DateTime? updatedAt,
    bool? deleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? purged,
  }) => SetlistEntry(
    id: id ?? this.id,
    bandId: bandId ?? this.bandId,
    name: name ?? this.name,
    gigDate: gigDate.present ? gigDate.value : this.gigDate,
    venue: venue.present ? venue.value : this.venue,
    origin: origin.present ? origin.value : this.origin,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    purged: purged ?? this.purged,
  );
  SetlistEntry copyWithCompanion(SetlistsCompanion data) {
    return SetlistEntry(
      id: data.id.present ? data.id.value : this.id,
      bandId: data.bandId.present ? data.bandId.value : this.bandId,
      name: data.name.present ? data.name.value : this.name,
      gigDate: data.gigDate.present ? data.gigDate.value : this.gigDate,
      venue: data.venue.present ? data.venue.value : this.venue,
      origin: data.origin.present ? data.origin.value : this.origin,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      revision: data.revision.present ? data.revision.value : this.revision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      purged: data.purged.present ? data.purged.value : this.purged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetlistEntry(')
          ..write('id: $id, ')
          ..write('bandId: $bandId, ')
          ..write('name: $name, ')
          ..write('gigDate: $gigDate, ')
          ..write('venue: $venue, ')
          ..write('origin: $origin, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bandId,
    name,
    gigDate,
    venue,
    origin,
    updatedBy,
    revision,
    updatedAt,
    deleted,
    deletedAt,
    purged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetlistEntry &&
          other.id == this.id &&
          other.bandId == this.bandId &&
          other.name == this.name &&
          other.gigDate == this.gigDate &&
          other.venue == this.venue &&
          other.origin == this.origin &&
          other.updatedBy == this.updatedBy &&
          other.revision == this.revision &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.purged == this.purged);
}

class SetlistsCompanion extends UpdateCompanion<SetlistEntry> {
  final Value<String> id;
  final Value<String> bandId;
  final Value<String> name;
  final Value<DateTime?> gigDate;
  final Value<String?> venue;
  final Value<String?> origin;
  final Value<String?> updatedBy;
  final Value<int> revision;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<bool> purged;
  final Value<int> rowid;
  const SetlistsCompanion({
    this.id = const Value.absent(),
    this.bandId = const Value.absent(),
    this.name = const Value.absent(),
    this.gigDate = const Value.absent(),
    this.venue = const Value.absent(),
    this.origin = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistsCompanion.insert({
    required String id,
    required String bandId,
    required String name,
    this.gigDate = const Value.absent(),
    this.venue = const Value.absent(),
    this.origin = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.purged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bandId = Value(bandId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<SetlistEntry> custom({
    Expression<String>? id,
    Expression<String>? bandId,
    Expression<String>? name,
    Expression<DateTime>? gigDate,
    Expression<String>? venue,
    Expression<String>? origin,
    Expression<String>? updatedBy,
    Expression<int>? revision,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<bool>? purged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bandId != null) 'band_id': bandId,
      if (name != null) 'name': name,
      if (gigDate != null) 'gig_date': gigDate,
      if (venue != null) 'venue': venue,
      if (origin != null) 'origin': origin,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (revision != null) 'revision': revision,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (purged != null) 'purged': purged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistsCompanion copyWith({
    Value<String>? id,
    Value<String>? bandId,
    Value<String>? name,
    Value<DateTime?>? gigDate,
    Value<String?>? venue,
    Value<String?>? origin,
    Value<String?>? updatedBy,
    Value<int>? revision,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<DateTime?>? deletedAt,
    Value<bool>? purged,
    Value<int>? rowid,
  }) {
    return SetlistsCompanion(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      name: name ?? this.name,
      gigDate: gigDate ?? this.gigDate,
      venue: venue ?? this.venue,
      origin: origin ?? this.origin,
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      purged: purged ?? this.purged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bandId.present) {
      map['band_id'] = Variable<String>(bandId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (gigDate.present) {
      map['gig_date'] = Variable<DateTime>(gigDate.value);
    }
    if (venue.present) {
      map['venue'] = Variable<String>(venue.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (purged.present) {
      map['purged'] = Variable<bool>(purged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistsCompanion(')
          ..write('id: $id, ')
          ..write('bandId: $bandId, ')
          ..write('name: $name, ')
          ..write('gigDate: $gigDate, ')
          ..write('venue: $venue, ')
          ..write('origin: $origin, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('purged: $purged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetItemsTable extends SetItems
    with TableInfo<$SetItemsTable, SetItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES setlists (id)',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transposeMeta = const VerificationMeta(
    'transpose',
  );
  @override
  late final GeneratedColumn<int> transpose = GeneratedColumn<int>(
    'transpose',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<String> sequence = GeneratedColumn<String>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SetItemType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SetItemType>($SetItemsTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<PlayedValues?, String> played =
      GeneratedColumn<String>(
        'played',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PlayedValues?>($SetItemsTable.$converterplayed);
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    songId,
    position,
    transpose,
    sequence,
    note,
    type,
    played,
    extra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('transpose')) {
      context.handle(
        _transposeMeta,
        transpose.isAcceptableOrUnknown(data['transpose']!, _transposeMeta),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetItemEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      transpose: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transpose'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      type: $SetItemsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      played: $SetItemsTable.$converterplayed.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}played'],
        ),
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      ),
    );
  }

  @override
  $SetItemsTable createAlias(String alias) {
    return $SetItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SetItemType, String, String> $convertertype =
      const EnumNameConverter<SetItemType>(SetItemType.values);
  static TypeConverter<PlayedValues?, String?> $converterplayed =
      const PlayedValuesConverter();
}

class SetItemEntry extends DataClass implements Insertable<SetItemEntry> {
  final String id;
  final String setId;
  final String? songId;
  final int position;

  /// Set-specific transposition in semitones (layer 2, ADR-0006).
  final int transpose;

  /// Set-specific song sequence (`{x_sequence}` syntax, layer 2,
  /// ADR-0006); null = as in the song.
  final String? sequence;

  /// Label of a pause or text item.
  final String? note;
  final SetItemType type;

  /// How the song was played, frozen once the gig date is reached
  /// (ADR-0046); null before, and for sets of older clients.
  final PlayedValues? played;

  /// Fields of the server's item JSON this version does not know, as a JSON
  /// object, so that saving the set keeps them for newer clients (ADR-0046).
  final String? extra;
  const SetItemEntry({
    required this.id,
    required this.setId,
    this.songId,
    required this.position,
    required this.transpose,
    this.sequence,
    this.note,
    required this.type,
    this.played,
    this.extra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['set_id'] = Variable<String>(setId);
    if (!nullToAbsent || songId != null) {
      map['song_id'] = Variable<String>(songId);
    }
    map['position'] = Variable<int>(position);
    map['transpose'] = Variable<int>(transpose);
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<String>(sequence);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['type'] = Variable<String>($SetItemsTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || played != null) {
      map['played'] = Variable<String>(
        $SetItemsTable.$converterplayed.toSql(played),
      );
    }
    if (!nullToAbsent || extra != null) {
      map['extra'] = Variable<String>(extra);
    }
    return map;
  }

  SetItemsCompanion toCompanion(bool nullToAbsent) {
    return SetItemsCompanion(
      id: Value(id),
      setId: Value(setId),
      songId: songId == null && nullToAbsent
          ? const Value.absent()
          : Value(songId),
      position: Value(position),
      transpose: Value(transpose),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      type: Value(type),
      played: played == null && nullToAbsent
          ? const Value.absent()
          : Value(played),
      extra: extra == null && nullToAbsent
          ? const Value.absent()
          : Value(extra),
    );
  }

  factory SetItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetItemEntry(
      id: serializer.fromJson<String>(json['id']),
      setId: serializer.fromJson<String>(json['setId']),
      songId: serializer.fromJson<String?>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
      transpose: serializer.fromJson<int>(json['transpose']),
      sequence: serializer.fromJson<String?>(json['sequence']),
      note: serializer.fromJson<String?>(json['note']),
      type: $SetItemsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      played: serializer.fromJson<PlayedValues?>(json['played']),
      extra: serializer.fromJson<String?>(json['extra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'setId': serializer.toJson<String>(setId),
      'songId': serializer.toJson<String?>(songId),
      'position': serializer.toJson<int>(position),
      'transpose': serializer.toJson<int>(transpose),
      'sequence': serializer.toJson<String?>(sequence),
      'note': serializer.toJson<String?>(note),
      'type': serializer.toJson<String>(
        $SetItemsTable.$convertertype.toJson(type),
      ),
      'played': serializer.toJson<PlayedValues?>(played),
      'extra': serializer.toJson<String?>(extra),
    };
  }

  SetItemEntry copyWith({
    String? id,
    String? setId,
    Value<String?> songId = const Value.absent(),
    int? position,
    int? transpose,
    Value<String?> sequence = const Value.absent(),
    Value<String?> note = const Value.absent(),
    SetItemType? type,
    Value<PlayedValues?> played = const Value.absent(),
    Value<String?> extra = const Value.absent(),
  }) => SetItemEntry(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    songId: songId.present ? songId.value : this.songId,
    position: position ?? this.position,
    transpose: transpose ?? this.transpose,
    sequence: sequence.present ? sequence.value : this.sequence,
    note: note.present ? note.value : this.note,
    type: type ?? this.type,
    played: played.present ? played.value : this.played,
    extra: extra.present ? extra.value : this.extra,
  );
  SetItemEntry copyWithCompanion(SetItemsCompanion data) {
    return SetItemEntry(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
      transpose: data.transpose.present ? data.transpose.value : this.transpose,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      note: data.note.present ? data.note.value : this.note,
      type: data.type.present ? data.type.value : this.type,
      played: data.played.present ? data.played.value : this.played,
      extra: data.extra.present ? data.extra.value : this.extra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetItemEntry(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('transpose: $transpose, ')
          ..write('sequence: $sequence, ')
          ..write('note: $note, ')
          ..write('type: $type, ')
          ..write('played: $played, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    songId,
    position,
    transpose,
    sequence,
    note,
    type,
    played,
    extra,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetItemEntry &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.songId == this.songId &&
          other.position == this.position &&
          other.transpose == this.transpose &&
          other.sequence == this.sequence &&
          other.note == this.note &&
          other.type == this.type &&
          other.played == this.played &&
          other.extra == this.extra);
}

class SetItemsCompanion extends UpdateCompanion<SetItemEntry> {
  final Value<String> id;
  final Value<String> setId;
  final Value<String?> songId;
  final Value<int> position;
  final Value<int> transpose;
  final Value<String?> sequence;
  final Value<String?> note;
  final Value<SetItemType> type;
  final Value<PlayedValues?> played;
  final Value<String?> extra;
  final Value<int> rowid;
  const SetItemsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
    this.transpose = const Value.absent(),
    this.sequence = const Value.absent(),
    this.note = const Value.absent(),
    this.type = const Value.absent(),
    this.played = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetItemsCompanion.insert({
    required String id,
    required String setId,
    this.songId = const Value.absent(),
    required int position,
    this.transpose = const Value.absent(),
    this.sequence = const Value.absent(),
    this.note = const Value.absent(),
    required SetItemType type,
    this.played = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       setId = Value(setId),
       position = Value(position),
       type = Value(type);
  static Insertable<SetItemEntry> custom({
    Expression<String>? id,
    Expression<String>? setId,
    Expression<String>? songId,
    Expression<int>? position,
    Expression<int>? transpose,
    Expression<String>? sequence,
    Expression<String>? note,
    Expression<String>? type,
    Expression<String>? played,
    Expression<String>? extra,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
      if (transpose != null) 'transpose': transpose,
      if (sequence != null) 'sequence': sequence,
      if (note != null) 'note': note,
      if (type != null) 'type': type,
      if (played != null) 'played': played,
      if (extra != null) 'extra': extra,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? setId,
    Value<String?>? songId,
    Value<int>? position,
    Value<int>? transpose,
    Value<String?>? sequence,
    Value<String?>? note,
    Value<SetItemType>? type,
    Value<PlayedValues?>? played,
    Value<String?>? extra,
    Value<int>? rowid,
  }) {
    return SetItemsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      transpose: transpose ?? this.transpose,
      sequence: sequence ?? this.sequence,
      note: note ?? this.note,
      type: type ?? this.type,
      played: played ?? this.played,
      extra: extra ?? this.extra,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (transpose.present) {
      map['transpose'] = Variable<int>(transpose.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<String>(sequence.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $SetItemsTable.$convertertype.toSql(type.value),
      );
    }
    if (played.present) {
      map['played'] = Variable<String>(
        $SetItemsTable.$converterplayed.toSql(played.value),
      );
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetItemsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('transpose: $transpose, ')
          ..write('sequence: $sequence, ')
          ..write('note: $note, ')
          ..write('type: $type, ')
          ..write('played: $played, ')
          ..write('extra: $extra, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalOverlaysTable extends PersonalOverlays
    with TableInfo<$PersonalOverlaysTable, SongOverlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalOverlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(localOwnerId),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _transposeMeta = const VerificationMeta(
    'transpose',
  );
  @override
  late final GeneratedColumn<int> transpose = GeneratedColumn<int>(
    'transpose',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _capoMeta = const VerificationMeta('capo');
  @override
  late final GeneratedColumn<int> capo = GeneratedColumn<int>(
    'capo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _capoFretMeta = const VerificationMeta(
    'capoFret',
  );
  @override
  late final GeneratedColumn<int> capoFret = GeneratedColumn<int>(
    'capo_fret',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fontScaleMeta = const VerificationMeta(
    'fontScale',
  );
  @override
  late final GeneratedColumn<double> fontScale = GeneratedColumn<double>(
    'font_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nashvilleMeta = const VerificationMeta(
    'nashville',
  );
  @override
  late final GeneratedColumn<bool> nashville = GeneratedColumn<bool>(
    'nashville',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("nashville" IN (0, 1))',
    ),
  );
  static const VerificationMeta _liveViewMeta = const VerificationMeta(
    'liveView',
  );
  @override
  late final GeneratedColumn<String> liveView = GeneratedColumn<String>(
    'live_view',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hideAnnotationsMeta = const VerificationMeta(
    'hideAnnotations',
  );
  @override
  late final GeneratedColumn<bool> hideAnnotations = GeneratedColumn<bool>(
    'hide_annotations',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hide_annotations" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<VerseChords, String> verseChords =
      GeneratedColumn<String>(
        'verse_chords',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(VerseChords.all.name),
      ).withConverter<VerseChords>(
        $PersonalOverlaysTable.$converterverseChords,
      );
  @override
  late final GeneratedColumnWithTypeConverter<MidiProgram?, String> midi =
      GeneratedColumn<String>(
        'midi',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<MidiProgram?>($PersonalOverlaysTable.$convertermidi);
  @override
  late final GeneratedColumnWithTypeConverter<MidiPrograms?, String>
  midiPrograms = GeneratedColumn<String>(
    'midi_programs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<MidiPrograms?>($PersonalOverlaysTable.$convertermidiPrograms);
  static const VerificationMeta _clickGroupingMeta = const VerificationMeta(
    'clickGrouping',
  );
  @override
  late final GeneratedColumn<String> clickGrouping = GeneratedColumn<String>(
    'click_grouping',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Subdivision?, String>
  clickSubdivision =
      GeneratedColumn<String>(
        'click_subdivision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Subdivision?>(
        $PersonalOverlaysTable.$converterclickSubdivisionn,
      );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    songId,
    transpose,
    capo,
    capoFret,
    fontScale,
    notes,
    nashville,
    liveView,
    hideAnnotations,
    verseChords,
    midi,
    midiPrograms,
    clickGrouping,
    clickSubdivision,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_overlays';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongOverlay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('transpose')) {
      context.handle(
        _transposeMeta,
        transpose.isAcceptableOrUnknown(data['transpose']!, _transposeMeta),
      );
    }
    if (data.containsKey('capo')) {
      context.handle(
        _capoMeta,
        capo.isAcceptableOrUnknown(data['capo']!, _capoMeta),
      );
    }
    if (data.containsKey('capo_fret')) {
      context.handle(
        _capoFretMeta,
        capoFret.isAcceptableOrUnknown(data['capo_fret']!, _capoFretMeta),
      );
    }
    if (data.containsKey('font_scale')) {
      context.handle(
        _fontScaleMeta,
        fontScale.isAcceptableOrUnknown(data['font_scale']!, _fontScaleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('nashville')) {
      context.handle(
        _nashvilleMeta,
        nashville.isAcceptableOrUnknown(data['nashville']!, _nashvilleMeta),
      );
    }
    if (data.containsKey('live_view')) {
      context.handle(
        _liveViewMeta,
        liveView.isAcceptableOrUnknown(data['live_view']!, _liveViewMeta),
      );
    }
    if (data.containsKey('hide_annotations')) {
      context.handle(
        _hideAnnotationsMeta,
        hideAnnotations.isAcceptableOrUnknown(
          data['hide_annotations']!,
          _hideAnnotationsMeta,
        ),
      );
    }
    if (data.containsKey('click_grouping')) {
      context.handle(
        _clickGroupingMeta,
        clickGrouping.isAcceptableOrUnknown(
          data['click_grouping']!,
          _clickGroupingMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, songId};
  @override
  SongOverlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongOverlay(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      transpose: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transpose'],
      )!,
      capo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capo'],
      )!,
      capoFret: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capo_fret'],
      ),
      fontScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_scale'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      nashville: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}nashville'],
      ),
      liveView: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}live_view'],
      ),
      hideAnnotations: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hide_annotations'],
      )!,
      verseChords: $PersonalOverlaysTable.$converterverseChords.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}verse_chords'],
        )!,
      ),
      midi: $PersonalOverlaysTable.$convertermidi.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}midi'],
        ),
      ),
      midiPrograms: $PersonalOverlaysTable.$convertermidiPrograms.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}midi_programs'],
        ),
      ),
      clickGrouping: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}click_grouping'],
      ),
      clickSubdivision: $PersonalOverlaysTable.$converterclickSubdivisionn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}click_subdivision'],
            ),
          ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PersonalOverlaysTable createAlias(String alias) {
    return $PersonalOverlaysTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VerseChords, String, String> $converterverseChords =
      const EnumNameConverter<VerseChords>(VerseChords.values);
  static TypeConverter<MidiProgram?, String?> $convertermidi =
      const MidiProgramConverter();
  static TypeConverter<MidiPrograms?, String?> $convertermidiPrograms =
      const MidiProgramsConverter();
  static JsonTypeConverter2<Subdivision, String, String>
  $converterclickSubdivision = const EnumNameConverter<Subdivision>(
    Subdivision.values,
  );
  static JsonTypeConverter2<Subdivision?, String?, String?>
  $converterclickSubdivisionn = JsonTypeConverter2.asNullable(
    $converterclickSubdivision,
  );
}

class SongOverlay extends DataClass implements Insertable<SongOverlay> {
  /// Server user ID, or [localOwnerId] (schema 8).
  final String ownerId;
  final String songId;
  final int transpose;

  /// Legacy capo (schema 1, 0 = none); replaced by [capoFret].
  final int capo;

  /// Personal capo; null = as written in the song (`{capo}`), 0 = no capo
  /// (schema 2).
  final int? capoFret;
  final double fontScale;
  final String? notes;

  /// Per-song Nashville override; null = use device setting.
  final bool? nashville;

  /// What live mode shows: null = ChordPro, otherwise an attachment ID.
  final String? liveView;

  /// Freehand annotations of this song hidden (ADR-0032, schema 16).
  final bool hideAnnotations;

  /// How verses show their chords: all, in the first verse only (#518) or
  /// stacked line by line (#521) (schema 18; a boolean in schema 17).
  final VerseChords verseChords;

  /// Keyboard program sent in live mode (ADR-0039, schema 19); null =
  /// none, the keyboard keeps its program.
  final MidiProgram? midi;

  /// Keyboard programs per device profile (ADR-0042, schema 20). Null =
  /// never written: [midi] (v0.16.0) counts for the device's profile; once
  /// written, even empty, [midi] is ignored.
  final MidiPrograms? midiPrograms;

  /// Grouping of an odd meter for the click and the beat display (#698,
  /// schema 27): `3+2+2`, or the numerator alone for no groups; null = as
  /// in the song (`{x_time_grouping}`).
  final String? clickGrouping;

  /// Subdivisions of the click for this song (#698, schema 27); null = the
  /// personal setting.
  final Subdivision? clickSubdivision;

  /// Server revision; 0 = not on the server (schema 9, ADR-0020).
  final int revision;
  const SongOverlay({
    required this.ownerId,
    required this.songId,
    required this.transpose,
    required this.capo,
    this.capoFret,
    required this.fontScale,
    this.notes,
    this.nashville,
    this.liveView,
    required this.hideAnnotations,
    required this.verseChords,
    this.midi,
    this.midiPrograms,
    this.clickGrouping,
    this.clickSubdivision,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['song_id'] = Variable<String>(songId);
    map['transpose'] = Variable<int>(transpose);
    map['capo'] = Variable<int>(capo);
    if (!nullToAbsent || capoFret != null) {
      map['capo_fret'] = Variable<int>(capoFret);
    }
    map['font_scale'] = Variable<double>(fontScale);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || nashville != null) {
      map['nashville'] = Variable<bool>(nashville);
    }
    if (!nullToAbsent || liveView != null) {
      map['live_view'] = Variable<String>(liveView);
    }
    map['hide_annotations'] = Variable<bool>(hideAnnotations);
    {
      map['verse_chords'] = Variable<String>(
        $PersonalOverlaysTable.$converterverseChords.toSql(verseChords),
      );
    }
    if (!nullToAbsent || midi != null) {
      map['midi'] = Variable<String>(
        $PersonalOverlaysTable.$convertermidi.toSql(midi),
      );
    }
    if (!nullToAbsent || midiPrograms != null) {
      map['midi_programs'] = Variable<String>(
        $PersonalOverlaysTable.$convertermidiPrograms.toSql(midiPrograms),
      );
    }
    if (!nullToAbsent || clickGrouping != null) {
      map['click_grouping'] = Variable<String>(clickGrouping);
    }
    if (!nullToAbsent || clickSubdivision != null) {
      map['click_subdivision'] = Variable<String>(
        $PersonalOverlaysTable.$converterclickSubdivisionn.toSql(
          clickSubdivision,
        ),
      );
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PersonalOverlaysCompanion toCompanion(bool nullToAbsent) {
    return PersonalOverlaysCompanion(
      ownerId: Value(ownerId),
      songId: Value(songId),
      transpose: Value(transpose),
      capo: Value(capo),
      capoFret: capoFret == null && nullToAbsent
          ? const Value.absent()
          : Value(capoFret),
      fontScale: Value(fontScale),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      nashville: nashville == null && nullToAbsent
          ? const Value.absent()
          : Value(nashville),
      liveView: liveView == null && nullToAbsent
          ? const Value.absent()
          : Value(liveView),
      hideAnnotations: Value(hideAnnotations),
      verseChords: Value(verseChords),
      midi: midi == null && nullToAbsent ? const Value.absent() : Value(midi),
      midiPrograms: midiPrograms == null && nullToAbsent
          ? const Value.absent()
          : Value(midiPrograms),
      clickGrouping: clickGrouping == null && nullToAbsent
          ? const Value.absent()
          : Value(clickGrouping),
      clickSubdivision: clickSubdivision == null && nullToAbsent
          ? const Value.absent()
          : Value(clickSubdivision),
      revision: Value(revision),
    );
  }

  factory SongOverlay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongOverlay(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      songId: serializer.fromJson<String>(json['songId']),
      transpose: serializer.fromJson<int>(json['transpose']),
      capo: serializer.fromJson<int>(json['capo']),
      capoFret: serializer.fromJson<int?>(json['capoFret']),
      fontScale: serializer.fromJson<double>(json['fontScale']),
      notes: serializer.fromJson<String?>(json['notes']),
      nashville: serializer.fromJson<bool?>(json['nashville']),
      liveView: serializer.fromJson<String?>(json['liveView']),
      hideAnnotations: serializer.fromJson<bool>(json['hideAnnotations']),
      verseChords: $PersonalOverlaysTable.$converterverseChords.fromJson(
        serializer.fromJson<String>(json['verseChords']),
      ),
      midi: serializer.fromJson<MidiProgram?>(json['midi']),
      midiPrograms: serializer.fromJson<MidiPrograms?>(json['midiPrograms']),
      clickGrouping: serializer.fromJson<String?>(json['clickGrouping']),
      clickSubdivision: $PersonalOverlaysTable.$converterclickSubdivisionn
          .fromJson(serializer.fromJson<String?>(json['clickSubdivision'])),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'songId': serializer.toJson<String>(songId),
      'transpose': serializer.toJson<int>(transpose),
      'capo': serializer.toJson<int>(capo),
      'capoFret': serializer.toJson<int?>(capoFret),
      'fontScale': serializer.toJson<double>(fontScale),
      'notes': serializer.toJson<String?>(notes),
      'nashville': serializer.toJson<bool?>(nashville),
      'liveView': serializer.toJson<String?>(liveView),
      'hideAnnotations': serializer.toJson<bool>(hideAnnotations),
      'verseChords': serializer.toJson<String>(
        $PersonalOverlaysTable.$converterverseChords.toJson(verseChords),
      ),
      'midi': serializer.toJson<MidiProgram?>(midi),
      'midiPrograms': serializer.toJson<MidiPrograms?>(midiPrograms),
      'clickGrouping': serializer.toJson<String?>(clickGrouping),
      'clickSubdivision': serializer.toJson<String?>(
        $PersonalOverlaysTable.$converterclickSubdivisionn.toJson(
          clickSubdivision,
        ),
      ),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SongOverlay copyWith({
    String? ownerId,
    String? songId,
    int? transpose,
    int? capo,
    Value<int?> capoFret = const Value.absent(),
    double? fontScale,
    Value<String?> notes = const Value.absent(),
    Value<bool?> nashville = const Value.absent(),
    Value<String?> liveView = const Value.absent(),
    bool? hideAnnotations,
    VerseChords? verseChords,
    Value<MidiProgram?> midi = const Value.absent(),
    Value<MidiPrograms?> midiPrograms = const Value.absent(),
    Value<String?> clickGrouping = const Value.absent(),
    Value<Subdivision?> clickSubdivision = const Value.absent(),
    int? revision,
  }) => SongOverlay(
    ownerId: ownerId ?? this.ownerId,
    songId: songId ?? this.songId,
    transpose: transpose ?? this.transpose,
    capo: capo ?? this.capo,
    capoFret: capoFret.present ? capoFret.value : this.capoFret,
    fontScale: fontScale ?? this.fontScale,
    notes: notes.present ? notes.value : this.notes,
    nashville: nashville.present ? nashville.value : this.nashville,
    liveView: liveView.present ? liveView.value : this.liveView,
    hideAnnotations: hideAnnotations ?? this.hideAnnotations,
    verseChords: verseChords ?? this.verseChords,
    midi: midi.present ? midi.value : this.midi,
    midiPrograms: midiPrograms.present ? midiPrograms.value : this.midiPrograms,
    clickGrouping: clickGrouping.present
        ? clickGrouping.value
        : this.clickGrouping,
    clickSubdivision: clickSubdivision.present
        ? clickSubdivision.value
        : this.clickSubdivision,
    revision: revision ?? this.revision,
  );
  SongOverlay copyWithCompanion(PersonalOverlaysCompanion data) {
    return SongOverlay(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      songId: data.songId.present ? data.songId.value : this.songId,
      transpose: data.transpose.present ? data.transpose.value : this.transpose,
      capo: data.capo.present ? data.capo.value : this.capo,
      capoFret: data.capoFret.present ? data.capoFret.value : this.capoFret,
      fontScale: data.fontScale.present ? data.fontScale.value : this.fontScale,
      notes: data.notes.present ? data.notes.value : this.notes,
      nashville: data.nashville.present ? data.nashville.value : this.nashville,
      liveView: data.liveView.present ? data.liveView.value : this.liveView,
      hideAnnotations: data.hideAnnotations.present
          ? data.hideAnnotations.value
          : this.hideAnnotations,
      verseChords: data.verseChords.present
          ? data.verseChords.value
          : this.verseChords,
      midi: data.midi.present ? data.midi.value : this.midi,
      midiPrograms: data.midiPrograms.present
          ? data.midiPrograms.value
          : this.midiPrograms,
      clickGrouping: data.clickGrouping.present
          ? data.clickGrouping.value
          : this.clickGrouping,
      clickSubdivision: data.clickSubdivision.present
          ? data.clickSubdivision.value
          : this.clickSubdivision,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongOverlay(')
          ..write('ownerId: $ownerId, ')
          ..write('songId: $songId, ')
          ..write('transpose: $transpose, ')
          ..write('capo: $capo, ')
          ..write('capoFret: $capoFret, ')
          ..write('fontScale: $fontScale, ')
          ..write('notes: $notes, ')
          ..write('nashville: $nashville, ')
          ..write('liveView: $liveView, ')
          ..write('hideAnnotations: $hideAnnotations, ')
          ..write('verseChords: $verseChords, ')
          ..write('midi: $midi, ')
          ..write('midiPrograms: $midiPrograms, ')
          ..write('clickGrouping: $clickGrouping, ')
          ..write('clickSubdivision: $clickSubdivision, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    songId,
    transpose,
    capo,
    capoFret,
    fontScale,
    notes,
    nashville,
    liveView,
    hideAnnotations,
    verseChords,
    midi,
    midiPrograms,
    clickGrouping,
    clickSubdivision,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongOverlay &&
          other.ownerId == this.ownerId &&
          other.songId == this.songId &&
          other.transpose == this.transpose &&
          other.capo == this.capo &&
          other.capoFret == this.capoFret &&
          other.fontScale == this.fontScale &&
          other.notes == this.notes &&
          other.nashville == this.nashville &&
          other.liveView == this.liveView &&
          other.hideAnnotations == this.hideAnnotations &&
          other.verseChords == this.verseChords &&
          other.midi == this.midi &&
          other.midiPrograms == this.midiPrograms &&
          other.clickGrouping == this.clickGrouping &&
          other.clickSubdivision == this.clickSubdivision &&
          other.revision == this.revision);
}

class PersonalOverlaysCompanion extends UpdateCompanion<SongOverlay> {
  final Value<String> ownerId;
  final Value<String> songId;
  final Value<int> transpose;
  final Value<int> capo;
  final Value<int?> capoFret;
  final Value<double> fontScale;
  final Value<String?> notes;
  final Value<bool?> nashville;
  final Value<String?> liveView;
  final Value<bool> hideAnnotations;
  final Value<VerseChords> verseChords;
  final Value<MidiProgram?> midi;
  final Value<MidiPrograms?> midiPrograms;
  final Value<String?> clickGrouping;
  final Value<Subdivision?> clickSubdivision;
  final Value<int> revision;
  final Value<int> rowid;
  const PersonalOverlaysCompanion({
    this.ownerId = const Value.absent(),
    this.songId = const Value.absent(),
    this.transpose = const Value.absent(),
    this.capo = const Value.absent(),
    this.capoFret = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.notes = const Value.absent(),
    this.nashville = const Value.absent(),
    this.liveView = const Value.absent(),
    this.hideAnnotations = const Value.absent(),
    this.verseChords = const Value.absent(),
    this.midi = const Value.absent(),
    this.midiPrograms = const Value.absent(),
    this.clickGrouping = const Value.absent(),
    this.clickSubdivision = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalOverlaysCompanion.insert({
    this.ownerId = const Value.absent(),
    required String songId,
    this.transpose = const Value.absent(),
    this.capo = const Value.absent(),
    this.capoFret = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.notes = const Value.absent(),
    this.nashville = const Value.absent(),
    this.liveView = const Value.absent(),
    this.hideAnnotations = const Value.absent(),
    this.verseChords = const Value.absent(),
    this.midi = const Value.absent(),
    this.midiPrograms = const Value.absent(),
    this.clickGrouping = const Value.absent(),
    this.clickSubdivision = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : songId = Value(songId);
  static Insertable<SongOverlay> custom({
    Expression<String>? ownerId,
    Expression<String>? songId,
    Expression<int>? transpose,
    Expression<int>? capo,
    Expression<int>? capoFret,
    Expression<double>? fontScale,
    Expression<String>? notes,
    Expression<bool>? nashville,
    Expression<String>? liveView,
    Expression<bool>? hideAnnotations,
    Expression<String>? verseChords,
    Expression<String>? midi,
    Expression<String>? midiPrograms,
    Expression<String>? clickGrouping,
    Expression<String>? clickSubdivision,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (songId != null) 'song_id': songId,
      if (transpose != null) 'transpose': transpose,
      if (capo != null) 'capo': capo,
      if (capoFret != null) 'capo_fret': capoFret,
      if (fontScale != null) 'font_scale': fontScale,
      if (notes != null) 'notes': notes,
      if (nashville != null) 'nashville': nashville,
      if (liveView != null) 'live_view': liveView,
      if (hideAnnotations != null) 'hide_annotations': hideAnnotations,
      if (verseChords != null) 'verse_chords': verseChords,
      if (midi != null) 'midi': midi,
      if (midiPrograms != null) 'midi_programs': midiPrograms,
      if (clickGrouping != null) 'click_grouping': clickGrouping,
      if (clickSubdivision != null) 'click_subdivision': clickSubdivision,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalOverlaysCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? songId,
    Value<int>? transpose,
    Value<int>? capo,
    Value<int?>? capoFret,
    Value<double>? fontScale,
    Value<String?>? notes,
    Value<bool?>? nashville,
    Value<String?>? liveView,
    Value<bool>? hideAnnotations,
    Value<VerseChords>? verseChords,
    Value<MidiProgram?>? midi,
    Value<MidiPrograms?>? midiPrograms,
    Value<String?>? clickGrouping,
    Value<Subdivision?>? clickSubdivision,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PersonalOverlaysCompanion(
      ownerId: ownerId ?? this.ownerId,
      songId: songId ?? this.songId,
      transpose: transpose ?? this.transpose,
      capo: capo ?? this.capo,
      capoFret: capoFret ?? this.capoFret,
      fontScale: fontScale ?? this.fontScale,
      notes: notes ?? this.notes,
      nashville: nashville ?? this.nashville,
      liveView: liveView ?? this.liveView,
      hideAnnotations: hideAnnotations ?? this.hideAnnotations,
      verseChords: verseChords ?? this.verseChords,
      midi: midi ?? this.midi,
      midiPrograms: midiPrograms ?? this.midiPrograms,
      clickGrouping: clickGrouping ?? this.clickGrouping,
      clickSubdivision: clickSubdivision ?? this.clickSubdivision,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (transpose.present) {
      map['transpose'] = Variable<int>(transpose.value);
    }
    if (capo.present) {
      map['capo'] = Variable<int>(capo.value);
    }
    if (capoFret.present) {
      map['capo_fret'] = Variable<int>(capoFret.value);
    }
    if (fontScale.present) {
      map['font_scale'] = Variable<double>(fontScale.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (nashville.present) {
      map['nashville'] = Variable<bool>(nashville.value);
    }
    if (liveView.present) {
      map['live_view'] = Variable<String>(liveView.value);
    }
    if (hideAnnotations.present) {
      map['hide_annotations'] = Variable<bool>(hideAnnotations.value);
    }
    if (verseChords.present) {
      map['verse_chords'] = Variable<String>(
        $PersonalOverlaysTable.$converterverseChords.toSql(verseChords.value),
      );
    }
    if (midi.present) {
      map['midi'] = Variable<String>(
        $PersonalOverlaysTable.$convertermidi.toSql(midi.value),
      );
    }
    if (midiPrograms.present) {
      map['midi_programs'] = Variable<String>(
        $PersonalOverlaysTable.$convertermidiPrograms.toSql(midiPrograms.value),
      );
    }
    if (clickGrouping.present) {
      map['click_grouping'] = Variable<String>(clickGrouping.value);
    }
    if (clickSubdivision.present) {
      map['click_subdivision'] = Variable<String>(
        $PersonalOverlaysTable.$converterclickSubdivisionn.toSql(
          clickSubdivision.value,
        ),
      );
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalOverlaysCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('songId: $songId, ')
          ..write('transpose: $transpose, ')
          ..write('capo: $capo, ')
          ..write('capoFret: $capoFret, ')
          ..write('fontScale: $fontScale, ')
          ..write('notes: $notes, ')
          ..write('nashville: $nashville, ')
          ..write('liveView: $liveView, ')
          ..write('hideAnnotations: $hideAnnotations, ')
          ..write('verseChords: $verseChords, ')
          ..write('midi: $midi, ')
          ..write('midiPrograms: $midiPrograms, ')
          ..write('clickGrouping: $clickGrouping, ')
          ..write('clickSubdivision: $clickSubdivision, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BandArrangementsTable extends BandArrangements
    with TableInfo<$BandArrangementsTable, BandArrangement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BandArrangementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bandIdMeta = const VerificationMeta('bandId');
  @override
  late final GeneratedColumn<String> bandId = GeneratedColumn<String>(
    'band_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _transposeMeta = const VerificationMeta(
    'transpose',
  );
  @override
  late final GeneratedColumn<int> transpose = GeneratedColumn<int>(
    'transpose',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<String> sequence = GeneratedColumn<String>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempoMeta = const VerificationMeta('tempo');
  @override
  late final GeneratedColumn<int> tempo = GeneratedColumn<int>(
    'tempo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    bandId,
    songId,
    transpose,
    sequence,
    tempo,
    updatedBy,
    revision,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'band_arrangements';
  @override
  VerificationContext validateIntegrity(
    Insertable<BandArrangement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('band_id')) {
      context.handle(
        _bandIdMeta,
        bandId.isAcceptableOrUnknown(data['band_id']!, _bandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bandIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('transpose')) {
      context.handle(
        _transposeMeta,
        transpose.isAcceptableOrUnknown(data['transpose']!, _transposeMeta),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('tempo')) {
      context.handle(
        _tempoMeta,
        tempo.isAcceptableOrUnknown(data['tempo']!, _tempoMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bandId, songId};
  @override
  BandArrangement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BandArrangement(
      bandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      transpose: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transpose'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence'],
      ),
      tempo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tempo'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $BandArrangementsTable createAlias(String alias) {
    return $BandArrangementsTable(attachedDatabase, alias);
  }
}

class BandArrangement extends DataClass implements Insertable<BandArrangement> {
  final String bandId;
  final String songId;

  /// Semitones relative to the song's key.
  final int transpose;

  /// Song sequence (`{x_sequence}` syntax); null = as in the song.
  final String? sequence;

  /// Tempo in BPM; null = as in the song (`{tempo}`).
  final int? tempo;

  /// User who changed the arrangement last, as the server reports it
  /// (ADR-0045, schema 22). Null for the local band and for arrangements
  /// synced before.
  final String? updatedBy;

  /// Server revision; 0 = not on the server.
  final int revision;

  /// Removed ("as in the song"); kept until the removal reached the server.
  final bool deleted;
  const BandArrangement({
    required this.bandId,
    required this.songId,
    required this.transpose,
    this.sequence,
    this.tempo,
    this.updatedBy,
    required this.revision,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['band_id'] = Variable<String>(bandId);
    map['song_id'] = Variable<String>(songId);
    map['transpose'] = Variable<int>(transpose);
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<String>(sequence);
    }
    if (!nullToAbsent || tempo != null) {
      map['tempo'] = Variable<int>(tempo);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['revision'] = Variable<int>(revision);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  BandArrangementsCompanion toCompanion(bool nullToAbsent) {
    return BandArrangementsCompanion(
      bandId: Value(bandId),
      songId: Value(songId),
      transpose: Value(transpose),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
      tempo: tempo == null && nullToAbsent
          ? const Value.absent()
          : Value(tempo),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      revision: Value(revision),
      deleted: Value(deleted),
    );
  }

  factory BandArrangement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BandArrangement(
      bandId: serializer.fromJson<String>(json['bandId']),
      songId: serializer.fromJson<String>(json['songId']),
      transpose: serializer.fromJson<int>(json['transpose']),
      sequence: serializer.fromJson<String?>(json['sequence']),
      tempo: serializer.fromJson<int?>(json['tempo']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      revision: serializer.fromJson<int>(json['revision']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bandId': serializer.toJson<String>(bandId),
      'songId': serializer.toJson<String>(songId),
      'transpose': serializer.toJson<int>(transpose),
      'sequence': serializer.toJson<String?>(sequence),
      'tempo': serializer.toJson<int?>(tempo),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'revision': serializer.toJson<int>(revision),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  BandArrangement copyWith({
    String? bandId,
    String? songId,
    int? transpose,
    Value<String?> sequence = const Value.absent(),
    Value<int?> tempo = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    int? revision,
    bool? deleted,
  }) => BandArrangement(
    bandId: bandId ?? this.bandId,
    songId: songId ?? this.songId,
    transpose: transpose ?? this.transpose,
    sequence: sequence.present ? sequence.value : this.sequence,
    tempo: tempo.present ? tempo.value : this.tempo,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    revision: revision ?? this.revision,
    deleted: deleted ?? this.deleted,
  );
  BandArrangement copyWithCompanion(BandArrangementsCompanion data) {
    return BandArrangement(
      bandId: data.bandId.present ? data.bandId.value : this.bandId,
      songId: data.songId.present ? data.songId.value : this.songId,
      transpose: data.transpose.present ? data.transpose.value : this.transpose,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      tempo: data.tempo.present ? data.tempo.value : this.tempo,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      revision: data.revision.present ? data.revision.value : this.revision,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BandArrangement(')
          ..write('bandId: $bandId, ')
          ..write('songId: $songId, ')
          ..write('transpose: $transpose, ')
          ..write('sequence: $sequence, ')
          ..write('tempo: $tempo, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bandId,
    songId,
    transpose,
    sequence,
    tempo,
    updatedBy,
    revision,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BandArrangement &&
          other.bandId == this.bandId &&
          other.songId == this.songId &&
          other.transpose == this.transpose &&
          other.sequence == this.sequence &&
          other.tempo == this.tempo &&
          other.updatedBy == this.updatedBy &&
          other.revision == this.revision &&
          other.deleted == this.deleted);
}

class BandArrangementsCompanion extends UpdateCompanion<BandArrangement> {
  final Value<String> bandId;
  final Value<String> songId;
  final Value<int> transpose;
  final Value<String?> sequence;
  final Value<int?> tempo;
  final Value<String?> updatedBy;
  final Value<int> revision;
  final Value<bool> deleted;
  final Value<int> rowid;
  const BandArrangementsCompanion({
    this.bandId = const Value.absent(),
    this.songId = const Value.absent(),
    this.transpose = const Value.absent(),
    this.sequence = const Value.absent(),
    this.tempo = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BandArrangementsCompanion.insert({
    required String bandId,
    required String songId,
    this.transpose = const Value.absent(),
    this.sequence = const Value.absent(),
    this.tempo = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bandId = Value(bandId),
       songId = Value(songId);
  static Insertable<BandArrangement> custom({
    Expression<String>? bandId,
    Expression<String>? songId,
    Expression<int>? transpose,
    Expression<String>? sequence,
    Expression<int>? tempo,
    Expression<String>? updatedBy,
    Expression<int>? revision,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bandId != null) 'band_id': bandId,
      if (songId != null) 'song_id': songId,
      if (transpose != null) 'transpose': transpose,
      if (sequence != null) 'sequence': sequence,
      if (tempo != null) 'tempo': tempo,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (revision != null) 'revision': revision,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BandArrangementsCompanion copyWith({
    Value<String>? bandId,
    Value<String>? songId,
    Value<int>? transpose,
    Value<String?>? sequence,
    Value<int?>? tempo,
    Value<String?>? updatedBy,
    Value<int>? revision,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return BandArrangementsCompanion(
      bandId: bandId ?? this.bandId,
      songId: songId ?? this.songId,
      transpose: transpose ?? this.transpose,
      sequence: sequence ?? this.sequence,
      tempo: tempo ?? this.tempo,
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bandId.present) {
      map['band_id'] = Variable<String>(bandId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (transpose.present) {
      map['transpose'] = Variable<int>(transpose.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<String>(sequence.value);
    }
    if (tempo.present) {
      map['tempo'] = Variable<int>(tempo.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BandArrangementsCompanion(')
          ..write('bandId: $bandId, ')
          ..write('songId: $songId, ')
          ..write('transpose: $transpose, ')
          ..write('sequence: $sequence, ')
          ..write('tempo: $tempo, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _dirtyKeysMeta = const VerificationMeta(
    'dirtyKeys',
  );
  @override
  late final GeneratedColumn<String> dirtyKeys = GeneratedColumn<String>(
    'dirty_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _adoptingMeta = const VerificationMeta(
    'adopting',
  );
  @override
  late final GeneratedColumn<bool> adopting = GeneratedColumn<bool>(
    'adopting',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("adopting" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    data,
    dirtyKeys,
    revision,
    adopting,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('dirty_keys')) {
      context.handle(
        _dirtyKeysMeta,
        dirtyKeys.isAcceptableOrUnknown(data['dirty_keys']!, _dirtyKeysMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('adopting')) {
      context.handle(
        _adoptingMeta,
        adopting.isAcceptableOrUnknown(data['adopting']!, _adoptingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId};
  @override
  UserSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSettingsRow(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      dirtyKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dirty_keys'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      adopting: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}adopting'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSettingsRow extends DataClass implements Insertable<UserSettingsRow> {
  /// Server user ID, or [localOwnerId] while signed out.
  final String ownerId;

  /// The settings as a JSON object; keys this app version does not know
  /// (from a newer version on another device) are kept.
  final String data;

  /// JSON list of the keys changed here and not yet on the server.
  final String dirtyKeys;

  /// Server revision; 0 = not on the server.
  final int revision;

  /// Copied from the signed-out settings at the first sign-in on this
  /// device: replaced by the person's settings from the server, or
  /// uploaded if the server has none yet (ADR-0027).
  final bool adopting;
  const UserSettingsRow({
    required this.ownerId,
    required this.data,
    required this.dirtyKeys,
    required this.revision,
    required this.adopting,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['data'] = Variable<String>(data);
    map['dirty_keys'] = Variable<String>(dirtyKeys);
    map['revision'] = Variable<int>(revision);
    map['adopting'] = Variable<bool>(adopting);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      ownerId: Value(ownerId),
      data: Value(data),
      dirtyKeys: Value(dirtyKeys),
      revision: Value(revision),
      adopting: Value(adopting),
    );
  }

  factory UserSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSettingsRow(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      data: serializer.fromJson<String>(json['data']),
      dirtyKeys: serializer.fromJson<String>(json['dirtyKeys']),
      revision: serializer.fromJson<int>(json['revision']),
      adopting: serializer.fromJson<bool>(json['adopting']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'data': serializer.toJson<String>(data),
      'dirtyKeys': serializer.toJson<String>(dirtyKeys),
      'revision': serializer.toJson<int>(revision),
      'adopting': serializer.toJson<bool>(adopting),
    };
  }

  UserSettingsRow copyWith({
    String? ownerId,
    String? data,
    String? dirtyKeys,
    int? revision,
    bool? adopting,
  }) => UserSettingsRow(
    ownerId: ownerId ?? this.ownerId,
    data: data ?? this.data,
    dirtyKeys: dirtyKeys ?? this.dirtyKeys,
    revision: revision ?? this.revision,
    adopting: adopting ?? this.adopting,
  );
  UserSettingsRow copyWithCompanion(UserSettingsCompanion data) {
    return UserSettingsRow(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      data: data.data.present ? data.data.value : this.data,
      dirtyKeys: data.dirtyKeys.present ? data.dirtyKeys.value : this.dirtyKeys,
      revision: data.revision.present ? data.revision.value : this.revision,
      adopting: data.adopting.present ? data.adopting.value : this.adopting,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsRow(')
          ..write('ownerId: $ownerId, ')
          ..write('data: $data, ')
          ..write('dirtyKeys: $dirtyKeys, ')
          ..write('revision: $revision, ')
          ..write('adopting: $adopting')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, data, dirtyKeys, revision, adopting);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettingsRow &&
          other.ownerId == this.ownerId &&
          other.data == this.data &&
          other.dirtyKeys == this.dirtyKeys &&
          other.revision == this.revision &&
          other.adopting == this.adopting);
}

class UserSettingsCompanion extends UpdateCompanion<UserSettingsRow> {
  final Value<String> ownerId;
  final Value<String> data;
  final Value<String> dirtyKeys;
  final Value<int> revision;
  final Value<bool> adopting;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.ownerId = const Value.absent(),
    this.data = const Value.absent(),
    this.dirtyKeys = const Value.absent(),
    this.revision = const Value.absent(),
    this.adopting = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String ownerId,
    this.data = const Value.absent(),
    this.dirtyKeys = const Value.absent(),
    this.revision = const Value.absent(),
    this.adopting = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId);
  static Insertable<UserSettingsRow> custom({
    Expression<String>? ownerId,
    Expression<String>? data,
    Expression<String>? dirtyKeys,
    Expression<int>? revision,
    Expression<bool>? adopting,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (data != null) 'data': data,
      if (dirtyKeys != null) 'dirty_keys': dirtyKeys,
      if (revision != null) 'revision': revision,
      if (adopting != null) 'adopting': adopting,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? data,
    Value<String>? dirtyKeys,
    Value<int>? revision,
    Value<bool>? adopting,
    Value<int>? rowid,
  }) {
    return UserSettingsCompanion(
      ownerId: ownerId ?? this.ownerId,
      data: data ?? this.data,
      dirtyKeys: dirtyKeys ?? this.dirtyKeys,
      revision: revision ?? this.revision,
      adopting: adopting ?? this.adopting,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (dirtyKeys.present) {
      map['dirty_keys'] = Variable<String>(dirtyKeys.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (adopting.present) {
      map['adopting'] = Variable<bool>(adopting.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('data: $data, ')
          ..write('dirtyKeys: $dirtyKeys, ')
          ..write('revision: $revision, ')
          ..write('adopting: $adopting, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, AnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _strokeMeta = const VerificationMeta('stroke');
  @override
  late final GeneratedColumn<String> stroke = GeneratedColumn<String>(
    'stroke',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingMeta = const VerificationMeta(
    'pending',
  );
  @override
  late final GeneratedColumn<int> pending = GeneratedColumn<int>(
    'pending',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    songId,
    target,
    stroke,
    updatedAt,
    pending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnnotationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('stroke')) {
      context.handle(
        _strokeMeta,
        stroke.isAcceptableOrUnknown(data['stroke']!, _strokeMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pending')) {
      context.handle(
        _pendingMeta,
        pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      stroke: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stroke'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      pending: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending'],
      )!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class AnnotationRow extends DataClass implements Insertable<AnnotationRow> {
  /// UUID of the stroke.
  final String id;

  /// Server user ID, or [localOwnerId] (as for personal overlays).
  final String ownerId;
  final String songId;

  /// What is annotated: empty for the ChordPro text, otherwise the ID of a
  /// PDF attachment.
  final String target;

  /// The stroke as JSON (`AnnotationStroke.toJson`); null for an erased
  /// stroke whose erase is not on the server yet (tombstone).
  final String? stroke;

  /// Last change in milliseconds since the epoch; also the drawing order.
  final int updatedAt;

  /// Grows with every local change not yet pushed; 0 = as on the server.
  final int pending;
  const AnnotationRow({
    required this.id,
    required this.ownerId,
    required this.songId,
    required this.target,
    this.stroke,
    required this.updatedAt,
    required this.pending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['song_id'] = Variable<String>(songId);
    map['target'] = Variable<String>(target);
    if (!nullToAbsent || stroke != null) {
      map['stroke'] = Variable<String>(stroke);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['pending'] = Variable<int>(pending);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      songId: Value(songId),
      target: Value(target),
      stroke: stroke == null && nullToAbsent
          ? const Value.absent()
          : Value(stroke),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
    );
  }

  factory AnnotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      songId: serializer.fromJson<String>(json['songId']),
      target: serializer.fromJson<String>(json['target']),
      stroke: serializer.fromJson<String?>(json['stroke']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      pending: serializer.fromJson<int>(json['pending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'songId': serializer.toJson<String>(songId),
      'target': serializer.toJson<String>(target),
      'stroke': serializer.toJson<String?>(stroke),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'pending': serializer.toJson<int>(pending),
    };
  }

  AnnotationRow copyWith({
    String? id,
    String? ownerId,
    String? songId,
    String? target,
    Value<String?> stroke = const Value.absent(),
    int? updatedAt,
    int? pending,
  }) => AnnotationRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    songId: songId ?? this.songId,
    target: target ?? this.target,
    stroke: stroke.present ? stroke.value : this.stroke,
    updatedAt: updatedAt ?? this.updatedAt,
    pending: pending ?? this.pending,
  );
  AnnotationRow copyWithCompanion(AnnotationsCompanion data) {
    return AnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      songId: data.songId.present ? data.songId.value : this.songId,
      target: data.target.present ? data.target.value : this.target,
      stroke: data.stroke.present ? data.stroke.value : this.stroke,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pending: data.pending.present ? data.pending.value : this.pending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('songId: $songId, ')
          ..write('target: $target, ')
          ..write('stroke: $stroke, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ownerId, songId, target, stroke, updatedAt, pending);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.songId == this.songId &&
          other.target == this.target &&
          other.stroke == this.stroke &&
          other.updatedAt == this.updatedAt &&
          other.pending == this.pending);
}

class AnnotationsCompanion extends UpdateCompanion<AnnotationRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> songId;
  final Value<String> target;
  final Value<String?> stroke;
  final Value<int> updatedAt;
  final Value<int> pending;
  final Value<int> rowid;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.songId = const Value.absent(),
    this.target = const Value.absent(),
    this.stroke = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    required String id,
    required String ownerId,
    required String songId,
    this.target = const Value.absent(),
    this.stroke = const Value.absent(),
    required int updatedAt,
    this.pending = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       songId = Value(songId),
       updatedAt = Value(updatedAt);
  static Insertable<AnnotationRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? songId,
    Expression<String>? target,
    Expression<String>? stroke,
    Expression<int>? updatedAt,
    Expression<int>? pending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (songId != null) 'song_id': songId,
      if (target != null) 'target': target,
      if (stroke != null) 'stroke': stroke,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pending != null) 'pending': pending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? songId,
    Value<String>? target,
    Value<String?>? stroke,
    Value<int>? updatedAt,
    Value<int>? pending,
    Value<int>? rowid,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      songId: songId ?? this.songId,
      target: target ?? this.target,
      stroke: stroke ?? this.stroke,
      updatedAt: updatedAt ?? this.updatedAt,
      pending: pending ?? this.pending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (stroke.present) {
      map['stroke'] = Variable<String>(stroke.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (pending.present) {
      map['pending'] = Variable<int>(pending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('songId: $songId, ')
          ..write('target: $target, ')
          ..write('stroke: $stroke, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pending: $pending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [collection, recordId, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, recordId};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  /// Server collection: `songs`, `setlists` or `attachments`.
  final String collection;
  final String recordId;
  final int version;
  const OutboxEntry({
    required this.collection,
    required this.recordId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['record_id'] = Variable<String>(recordId);
    map['version'] = Variable<int>(version);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      collection: Value(collection),
      recordId: Value(recordId),
      version: Value(version),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      collection: serializer.fromJson<String>(json['collection']),
      recordId: serializer.fromJson<String>(json['recordId']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'recordId': serializer.toJson<String>(recordId),
      'version': serializer.toJson<int>(version),
    };
  }

  OutboxEntry copyWith({String? collection, String? recordId, int? version}) =>
      OutboxEntry(
        collection: collection ?? this.collection,
        recordId: recordId ?? this.recordId,
        version: version ?? this.version,
      );
  OutboxEntry copyWithCompanion(SyncOutboxCompanion data) {
    return OutboxEntry(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('collection: $collection, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, recordId, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.collection == this.collection &&
          other.recordId == this.recordId &&
          other.version == this.version);
}

class SyncOutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> collection;
  final Value<String> recordId;
  final Value<int> version;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.collection = const Value.absent(),
    this.recordId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String collection,
    required String recordId,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       recordId = Value(recordId);
  static Insertable<OutboxEntry> custom({
    Expression<String>? collection,
    Expression<String>? recordId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (recordId != null) 'record_id': recordId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? collection,
    Value<String>? recordId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      collection: collection ?? this.collection,
      recordId: recordId ?? this.recordId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('collection: $collection, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [scope, collection, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, collection};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String scope;
  final String collection;
  final int revision;
  const SyncCursor({
    required this.scope,
    required this.collection,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['collection'] = Variable<String>(collection);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      scope: Value(scope),
      collection: Value(collection),
      revision: Value(revision),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      scope: serializer.fromJson<String>(json['scope']),
      collection: serializer.fromJson<String>(json['collection']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'collection': serializer.toJson<String>(collection),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SyncCursor copyWith({String? scope, String? collection, int? revision}) =>
      SyncCursor(
        scope: scope ?? this.scope,
        collection: collection ?? this.collection,
        revision: revision ?? this.revision,
      );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      scope: data.scope.present ? data.scope.value : this.scope,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('scope: $scope, ')
          ..write('collection: $collection, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, collection, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.scope == this.scope &&
          other.collection == this.collection &&
          other.revision == this.revision);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> scope;
  final Value<String> collection;
  final Value<int> revision;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.scope = const Value.absent(),
    this.collection = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String scope,
    required String collection,
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       collection = Value(collection);
  static Insertable<SyncCursor> custom({
    Expression<String>? scope,
    Expression<String>? collection,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (collection != null) 'collection': collection,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? scope,
    Value<String>? collection,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      scope: scope ?? this.scope,
      collection: collection ?? this.collection,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('scope: $scope, ')
          ..write('collection: $collection, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongConflictsTable extends SongConflicts
    with TableInfo<$SongConflictsTable, SongConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chordproSourceMeta = const VerificationMeta(
    'chordproSource',
  );
  @override
  late final GeneratedColumn<String> chordproSource = GeneratedColumn<String>(
    'chordpro_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    songId,
    title,
    chordproSource,
    revision,
    deleted,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('chordpro_source')) {
      context.handle(
        _chordproSourceMeta,
        chordproSource.isAcceptableOrUnknown(
          data['chordpro_source']!,
          _chordproSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chordproSourceMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  SongConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongConflict(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      chordproSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chordpro_source'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
    );
  }

  @override
  $SongConflictsTable createAlias(String alias) {
    return $SongConflictsTable(attachedDatabase, alias);
  }
}

class SongConflict extends DataClass implements Insertable<SongConflict> {
  final String songId;
  final String title;
  final String chordproSource;
  final int revision;

  /// The song was deleted on the server.
  final bool deleted;
  final DateTime detectedAt;
  const SongConflict({
    required this.songId,
    required this.title,
    required this.chordproSource,
    required this.revision,
    required this.deleted,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['title'] = Variable<String>(title);
    map['chordpro_source'] = Variable<String>(chordproSource);
    map['revision'] = Variable<int>(revision);
    map['deleted'] = Variable<bool>(deleted);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  SongConflictsCompanion toCompanion(bool nullToAbsent) {
    return SongConflictsCompanion(
      songId: Value(songId),
      title: Value(title),
      chordproSource: Value(chordproSource),
      revision: Value(revision),
      deleted: Value(deleted),
      detectedAt: Value(detectedAt),
    );
  }

  factory SongConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongConflict(
      songId: serializer.fromJson<String>(json['songId']),
      title: serializer.fromJson<String>(json['title']),
      chordproSource: serializer.fromJson<String>(json['chordproSource']),
      revision: serializer.fromJson<int>(json['revision']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'title': serializer.toJson<String>(title),
      'chordproSource': serializer.toJson<String>(chordproSource),
      'revision': serializer.toJson<int>(revision),
      'deleted': serializer.toJson<bool>(deleted),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  SongConflict copyWith({
    String? songId,
    String? title,
    String? chordproSource,
    int? revision,
    bool? deleted,
    DateTime? detectedAt,
  }) => SongConflict(
    songId: songId ?? this.songId,
    title: title ?? this.title,
    chordproSource: chordproSource ?? this.chordproSource,
    revision: revision ?? this.revision,
    deleted: deleted ?? this.deleted,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  SongConflict copyWithCompanion(SongConflictsCompanion data) {
    return SongConflict(
      songId: data.songId.present ? data.songId.value : this.songId,
      title: data.title.present ? data.title.value : this.title,
      chordproSource: data.chordproSource.present
          ? data.chordproSource.value
          : this.chordproSource,
      revision: data.revision.present ? data.revision.value : this.revision,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongConflict(')
          ..write('songId: $songId, ')
          ..write('title: $title, ')
          ..write('chordproSource: $chordproSource, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(songId, title, chordproSource, revision, deleted, detectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongConflict &&
          other.songId == this.songId &&
          other.title == this.title &&
          other.chordproSource == this.chordproSource &&
          other.revision == this.revision &&
          other.deleted == this.deleted &&
          other.detectedAt == this.detectedAt);
}

class SongConflictsCompanion extends UpdateCompanion<SongConflict> {
  final Value<String> songId;
  final Value<String> title;
  final Value<String> chordproSource;
  final Value<int> revision;
  final Value<bool> deleted;
  final Value<DateTime> detectedAt;
  final Value<int> rowid;
  const SongConflictsCompanion({
    this.songId = const Value.absent(),
    this.title = const Value.absent(),
    this.chordproSource = const Value.absent(),
    this.revision = const Value.absent(),
    this.deleted = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongConflictsCompanion.insert({
    required String songId,
    required String title,
    required String chordproSource,
    required int revision,
    this.deleted = const Value.absent(),
    required DateTime detectedAt,
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       title = Value(title),
       chordproSource = Value(chordproSource),
       revision = Value(revision),
       detectedAt = Value(detectedAt);
  static Insertable<SongConflict> custom({
    Expression<String>? songId,
    Expression<String>? title,
    Expression<String>? chordproSource,
    Expression<int>? revision,
    Expression<bool>? deleted,
    Expression<DateTime>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (title != null) 'title': title,
      if (chordproSource != null) 'chordpro_source': chordproSource,
      if (revision != null) 'revision': revision,
      if (deleted != null) 'deleted': deleted,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongConflictsCompanion copyWith({
    Value<String>? songId,
    Value<String>? title,
    Value<String>? chordproSource,
    Value<int>? revision,
    Value<bool>? deleted,
    Value<DateTime>? detectedAt,
    Value<int>? rowid,
  }) {
    return SongConflictsCompanion(
      songId: songId ?? this.songId,
      title: title ?? this.title,
      chordproSource: chordproSource ?? this.chordproSource,
      revision: revision ?? this.revision,
      deleted: deleted ?? this.deleted,
      detectedAt: detectedAt ?? this.detectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (chordproSource.present) {
      map['chordpro_source'] = Variable<String>(chordproSource.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongConflictsCompanion(')
          ..write('songId: $songId, ')
          ..write('title: $title, ')
          ..write('chordproSource: $chordproSource, ')
          ..write('revision: $revision, ')
          ..write('deleted: $deleted, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangeLogTable extends ChangeLog
    with TableInfo<$ChangeLogTable, ChangeLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangeLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ChangeKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ChangeKind>($ChangeLogTable.$converterkind);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    kind,
    scopeId,
    recordId,
    title,
    userId,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChangeLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      kind: $ChangeLogTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
    );
  }

  @override
  $ChangeLogTable createAlias(String alias) {
    return $ChangeLogTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChangeKind, String, String> $converterkind =
      const EnumNameConverter<ChangeKind>(ChangeKind.values);
}

class ChangeLogRow extends DataClass implements Insertable<ChangeLogRow> {
  final int id;

  /// When the sync applied the change on this device (compared with the
  /// overview's "last shown", also a time on this device).
  final DateTime at;
  final ChangeKind kind;

  /// The organization of a song, the band of a set.
  final String scopeId;

  /// The song or set.
  final String recordId;

  /// Title of the song or name of the set at the time of the change.
  final String title;

  /// Who made the change (`created_by` of a new song, otherwise
  /// `updated_by`).
  final String? userId;

  /// What changed, as the JSON of `ChangeDetails`.
  final String details;
  const ChangeLogRow({
    required this.id,
    required this.at,
    required this.kind,
    required this.scopeId,
    required this.recordId,
    required this.title,
    this.userId,
    required this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    {
      map['kind'] = Variable<String>(
        $ChangeLogTable.$converterkind.toSql(kind),
      );
    }
    map['scope_id'] = Variable<String>(scopeId);
    map['record_id'] = Variable<String>(recordId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['details'] = Variable<String>(details);
    return map;
  }

  ChangeLogCompanion toCompanion(bool nullToAbsent) {
    return ChangeLogCompanion(
      id: Value(id),
      at: Value(at),
      kind: Value(kind),
      scopeId: Value(scopeId),
      recordId: Value(recordId),
      title: Value(title),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      details: Value(details),
    );
  }

  factory ChangeLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeLogRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      kind: $ChangeLogTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      recordId: serializer.fromJson<String>(json['recordId']),
      title: serializer.fromJson<String>(json['title']),
      userId: serializer.fromJson<String?>(json['userId']),
      details: serializer.fromJson<String>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'kind': serializer.toJson<String>(
        $ChangeLogTable.$converterkind.toJson(kind),
      ),
      'scopeId': serializer.toJson<String>(scopeId),
      'recordId': serializer.toJson<String>(recordId),
      'title': serializer.toJson<String>(title),
      'userId': serializer.toJson<String?>(userId),
      'details': serializer.toJson<String>(details),
    };
  }

  ChangeLogRow copyWith({
    int? id,
    DateTime? at,
    ChangeKind? kind,
    String? scopeId,
    String? recordId,
    String? title,
    Value<String?> userId = const Value.absent(),
    String? details,
  }) => ChangeLogRow(
    id: id ?? this.id,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    scopeId: scopeId ?? this.scopeId,
    recordId: recordId ?? this.recordId,
    title: title ?? this.title,
    userId: userId.present ? userId.value : this.userId,
    details: details ?? this.details,
  );
  ChangeLogRow copyWithCompanion(ChangeLogCompanion data) {
    return ChangeLogRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      kind: data.kind.present ? data.kind.value : this.kind,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      title: data.title.present ? data.title.value : this.title,
      userId: data.userId.present ? data.userId.value : this.userId,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('scopeId: $scopeId, ')
          ..write('recordId: $recordId, ')
          ..write('title: $title, ')
          ..write('userId: $userId, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, kind, scopeId, recordId, title, userId, details);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeLogRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.kind == this.kind &&
          other.scopeId == this.scopeId &&
          other.recordId == this.recordId &&
          other.title == this.title &&
          other.userId == this.userId &&
          other.details == this.details);
}

class ChangeLogCompanion extends UpdateCompanion<ChangeLogRow> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<ChangeKind> kind;
  final Value<String> scopeId;
  final Value<String> recordId;
  final Value<String> title;
  final Value<String?> userId;
  final Value<String> details;
  const ChangeLogCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.kind = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.recordId = const Value.absent(),
    this.title = const Value.absent(),
    this.userId = const Value.absent(),
    this.details = const Value.absent(),
  });
  ChangeLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required ChangeKind kind,
    required String scopeId,
    required String recordId,
    required String title,
    this.userId = const Value.absent(),
    this.details = const Value.absent(),
  }) : at = Value(at),
       kind = Value(kind),
       scopeId = Value(scopeId),
       recordId = Value(recordId),
       title = Value(title);
  static Insertable<ChangeLogRow> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<String>? kind,
    Expression<String>? scopeId,
    Expression<String>? recordId,
    Expression<String>? title,
    Expression<String>? userId,
    Expression<String>? details,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (kind != null) 'kind': kind,
      if (scopeId != null) 'scope_id': scopeId,
      if (recordId != null) 'record_id': recordId,
      if (title != null) 'title': title,
      if (userId != null) 'user_id': userId,
      if (details != null) 'details': details,
    });
  }

  ChangeLogCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<ChangeKind>? kind,
    Value<String>? scopeId,
    Value<String>? recordId,
    Value<String>? title,
    Value<String?>? userId,
    Value<String>? details,
  }) {
    return ChangeLogCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      kind: kind ?? this.kind,
      scopeId: scopeId ?? this.scopeId,
      recordId: recordId ?? this.recordId,
      title: title ?? this.title,
      userId: userId ?? this.userId,
      details: details ?? this.details,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ChangeLogTable.$converterkind.toSql(kind.value),
      );
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('scopeId: $scopeId, ')
          ..write('recordId: $recordId, ')
          ..write('title: $title, ')
          ..write('userId: $userId, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }
}

class $OrgPlaysTable extends OrgPlays with TableInfo<$OrgPlaysTable, OrgPlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrgPlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandIdMeta = const VerificationMeta('bandId');
  @override
  late final GeneratedColumn<String> bandId = GeneratedColumn<String>(
    'band_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandNameMeta = const VerificationMeta(
    'bandName',
  );
  @override
  late final GeneratedColumn<String> bandName = GeneratedColumn<String>(
    'band_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPlayedMeta = const VerificationMeta(
    'lastPlayed',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayed = GeneratedColumn<DateTime>(
    'last_played',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedKeyMeta = const VerificationMeta(
    'playedKey',
  );
  @override
  late final GeneratedColumn<String> playedKey = GeneratedColumn<String>(
    'played_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    organizationId,
    songId,
    bandId,
    bandName,
    playCount,
    lastPlayed,
    playedKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'org_plays';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrgPlay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_organizationIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('band_id')) {
      context.handle(
        _bandIdMeta,
        bandId.isAcceptableOrUnknown(data['band_id']!, _bandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bandIdMeta);
    }
    if (data.containsKey('band_name')) {
      context.handle(
        _bandNameMeta,
        bandName.isAcceptableOrUnknown(data['band_name']!, _bandNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bandNameMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    } else if (isInserting) {
      context.missing(_playCountMeta);
    }
    if (data.containsKey('last_played')) {
      context.handle(
        _lastPlayedMeta,
        lastPlayed.isAcceptableOrUnknown(data['last_played']!, _lastPlayedMeta),
      );
    } else if (isInserting) {
      context.missing(_lastPlayedMeta);
    }
    if (data.containsKey('played_key')) {
      context.handle(
        _playedKeyMeta,
        playedKey.isAcceptableOrUnknown(data['played_key']!, _playedKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId, bandId};
  @override
  OrgPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrgPlay(
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      bandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_id'],
      )!,
      bandName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_name'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      lastPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played'],
      )!,
      playedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}played_key'],
      ),
    );
  }

  @override
  $OrgPlaysTable createAlias(String alias) {
    return $OrgPlaysTable(attachedDatabase, alias);
  }
}

class OrgPlay extends DataClass implements Insertable<OrgPlay> {
  final String organizationId;
  final String songId;
  final String bandId;
  final String bandName;

  /// Past sets of the band with the song.
  final int playCount;
  final DateTime lastPlayed;

  /// The key of the most recent play with frozen values, if any.
  final String? playedKey;
  const OrgPlay({
    required this.organizationId,
    required this.songId,
    required this.bandId,
    required this.bandName,
    required this.playCount,
    required this.lastPlayed,
    this.playedKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['organization_id'] = Variable<String>(organizationId);
    map['song_id'] = Variable<String>(songId);
    map['band_id'] = Variable<String>(bandId);
    map['band_name'] = Variable<String>(bandName);
    map['play_count'] = Variable<int>(playCount);
    map['last_played'] = Variable<DateTime>(lastPlayed);
    if (!nullToAbsent || playedKey != null) {
      map['played_key'] = Variable<String>(playedKey);
    }
    return map;
  }

  OrgPlaysCompanion toCompanion(bool nullToAbsent) {
    return OrgPlaysCompanion(
      organizationId: Value(organizationId),
      songId: Value(songId),
      bandId: Value(bandId),
      bandName: Value(bandName),
      playCount: Value(playCount),
      lastPlayed: Value(lastPlayed),
      playedKey: playedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(playedKey),
    );
  }

  factory OrgPlay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrgPlay(
      organizationId: serializer.fromJson<String>(json['organizationId']),
      songId: serializer.fromJson<String>(json['songId']),
      bandId: serializer.fromJson<String>(json['bandId']),
      bandName: serializer.fromJson<String>(json['bandName']),
      playCount: serializer.fromJson<int>(json['playCount']),
      lastPlayed: serializer.fromJson<DateTime>(json['lastPlayed']),
      playedKey: serializer.fromJson<String?>(json['playedKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'organizationId': serializer.toJson<String>(organizationId),
      'songId': serializer.toJson<String>(songId),
      'bandId': serializer.toJson<String>(bandId),
      'bandName': serializer.toJson<String>(bandName),
      'playCount': serializer.toJson<int>(playCount),
      'lastPlayed': serializer.toJson<DateTime>(lastPlayed),
      'playedKey': serializer.toJson<String?>(playedKey),
    };
  }

  OrgPlay copyWith({
    String? organizationId,
    String? songId,
    String? bandId,
    String? bandName,
    int? playCount,
    DateTime? lastPlayed,
    Value<String?> playedKey = const Value.absent(),
  }) => OrgPlay(
    organizationId: organizationId ?? this.organizationId,
    songId: songId ?? this.songId,
    bandId: bandId ?? this.bandId,
    bandName: bandName ?? this.bandName,
    playCount: playCount ?? this.playCount,
    lastPlayed: lastPlayed ?? this.lastPlayed,
    playedKey: playedKey.present ? playedKey.value : this.playedKey,
  );
  OrgPlay copyWithCompanion(OrgPlaysCompanion data) {
    return OrgPlay(
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      songId: data.songId.present ? data.songId.value : this.songId,
      bandId: data.bandId.present ? data.bandId.value : this.bandId,
      bandName: data.bandName.present ? data.bandName.value : this.bandName,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      lastPlayed: data.lastPlayed.present
          ? data.lastPlayed.value
          : this.lastPlayed,
      playedKey: data.playedKey.present ? data.playedKey.value : this.playedKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrgPlay(')
          ..write('organizationId: $organizationId, ')
          ..write('songId: $songId, ')
          ..write('bandId: $bandId, ')
          ..write('bandName: $bandName, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayed: $lastPlayed, ')
          ..write('playedKey: $playedKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    organizationId,
    songId,
    bandId,
    bandName,
    playCount,
    lastPlayed,
    playedKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrgPlay &&
          other.organizationId == this.organizationId &&
          other.songId == this.songId &&
          other.bandId == this.bandId &&
          other.bandName == this.bandName &&
          other.playCount == this.playCount &&
          other.lastPlayed == this.lastPlayed &&
          other.playedKey == this.playedKey);
}

class OrgPlaysCompanion extends UpdateCompanion<OrgPlay> {
  final Value<String> organizationId;
  final Value<String> songId;
  final Value<String> bandId;
  final Value<String> bandName;
  final Value<int> playCount;
  final Value<DateTime> lastPlayed;
  final Value<String?> playedKey;
  final Value<int> rowid;
  const OrgPlaysCompanion({
    this.organizationId = const Value.absent(),
    this.songId = const Value.absent(),
    this.bandId = const Value.absent(),
    this.bandName = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayed = const Value.absent(),
    this.playedKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrgPlaysCompanion.insert({
    required String organizationId,
    required String songId,
    required String bandId,
    required String bandName,
    required int playCount,
    required DateTime lastPlayed,
    this.playedKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : organizationId = Value(organizationId),
       songId = Value(songId),
       bandId = Value(bandId),
       bandName = Value(bandName),
       playCount = Value(playCount),
       lastPlayed = Value(lastPlayed);
  static Insertable<OrgPlay> custom({
    Expression<String>? organizationId,
    Expression<String>? songId,
    Expression<String>? bandId,
    Expression<String>? bandName,
    Expression<int>? playCount,
    Expression<DateTime>? lastPlayed,
    Expression<String>? playedKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (organizationId != null) 'organization_id': organizationId,
      if (songId != null) 'song_id': songId,
      if (bandId != null) 'band_id': bandId,
      if (bandName != null) 'band_name': bandName,
      if (playCount != null) 'play_count': playCount,
      if (lastPlayed != null) 'last_played': lastPlayed,
      if (playedKey != null) 'played_key': playedKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrgPlaysCompanion copyWith({
    Value<String>? organizationId,
    Value<String>? songId,
    Value<String>? bandId,
    Value<String>? bandName,
    Value<int>? playCount,
    Value<DateTime>? lastPlayed,
    Value<String?>? playedKey,
    Value<int>? rowid,
  }) {
    return OrgPlaysCompanion(
      organizationId: organizationId ?? this.organizationId,
      songId: songId ?? this.songId,
      bandId: bandId ?? this.bandId,
      bandName: bandName ?? this.bandName,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      playedKey: playedKey ?? this.playedKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (bandId.present) {
      map['band_id'] = Variable<String>(bandId.value);
    }
    if (bandName.present) {
      map['band_name'] = Variable<String>(bandName.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (lastPlayed.present) {
      map['last_played'] = Variable<DateTime>(lastPlayed.value);
    }
    if (playedKey.present) {
      map['played_key'] = Variable<String>(playedKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrgPlaysCompanion(')
          ..write('organizationId: $organizationId, ')
          ..write('songId: $songId, ')
          ..write('bandId: $bandId, ')
          ..write('bandName: $bandName, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayed: $lastPlayed, ')
          ..write('playedKey: $playedKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final SongsFts songsFts = SongsFts(this);
  late final $SongsTable songs = $SongsTable(this);
  late final Trigger songsFtsInsert = Trigger(
    'CREATE TRIGGER songs_fts_insert AFTER INSERT ON songs BEGIN INSERT INTO songs_fts ("rowid", title, artist, search_text) VALUES (new."rowid", new.title, new.artist, new.search_text);END',
    'songs_fts_insert',
  );
  late final Trigger songsFtsDelete = Trigger(
    'CREATE TRIGGER songs_fts_delete AFTER DELETE ON songs BEGIN INSERT INTO songs_fts (songs_fts, "rowid", title, artist, search_text) VALUES (\'delete\', old."rowid", old.title, old.artist, old.search_text);END',
    'songs_fts_delete',
  );
  late final Trigger songsFtsUpdate = Trigger(
    'CREATE TRIGGER songs_fts_update AFTER UPDATE ON songs BEGIN INSERT INTO songs_fts (songs_fts, "rowid", title, artist, search_text) VALUES (\'delete\', old."rowid", old.title, old.artist, old.search_text);INSERT INTO songs_fts ("rowid", title, artist, search_text) VALUES (new."rowid", new.title, new.artist, new.search_text);END',
    'songs_fts_update',
  );
  late final $OrganizationsTable organizations = $OrganizationsTable(this);
  late final $OrgMembershipsTable orgMemberships = $OrgMembershipsTable(this);
  late final $BandsTable bands = $BandsTable(this);
  late final $MembershipsTable memberships = $MembershipsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $SetlistsTable setlists = $SetlistsTable(this);
  late final $SetItemsTable setItems = $SetItemsTable(this);
  late final $PersonalOverlaysTable personalOverlays = $PersonalOverlaysTable(
    this,
  );
  late final $BandArrangementsTable bandArrangements = $BandArrangementsTable(
    this,
  );
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $SongConflictsTable songConflicts = $SongConflictsTable(this);
  late final $ChangeLogTable changeLog = $ChangeLogTable(this);
  late final $OrgPlaysTable orgPlays = $OrgPlaysTable(this);
  late final Index orgMembershipsUser = Index(
    'org_memberships_user',
    'CREATE INDEX org_memberships_user ON org_memberships (user_id)',
  );
  late final Index membershipsBand = Index(
    'memberships_band',
    'CREATE INDEX memberships_band ON memberships (band_id)',
  );
  late final Index membershipsUser = Index(
    'memberships_user',
    'CREATE INDEX memberships_user ON memberships (user_id)',
  );
  late final Index songsLibrary = Index(
    'songs_library',
    'CREATE INDEX songs_library ON songs (library_id, deleted)',
  );
  late final Index attachmentsSong = Index(
    'attachments_song',
    'CREATE INDEX attachments_song ON attachments (song_id)',
  );
  late final Index setlistsBand = Index(
    'setlists_band',
    'CREATE INDEX setlists_band ON setlists (band_id, deleted)',
  );
  late final Index setItemsSet = Index(
    'set_items_set',
    'CREATE INDEX set_items_set ON set_items (set_id, position)',
  );
  late final Index setItemsSong = Index(
    'set_items_song',
    'CREATE INDEX set_items_song ON set_items (song_id)',
  );
  late final Index annotationsOwnerSong = Index(
    'annotations_owner_song',
    'CREATE INDEX annotations_owner_song ON annotations (owner_id, song_id)',
  );
  late final Index changeLogScope = Index(
    'change_log_scope',
    'CREATE INDEX change_log_scope ON change_log (scope_id, at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    songsFts,
    songs,
    songsFtsInsert,
    songsFtsDelete,
    songsFtsUpdate,
    organizations,
    orgMemberships,
    bands,
    memberships,
    attachments,
    setlists,
    setItems,
    personalOverlays,
    bandArrangements,
    userSettings,
    annotations,
    syncOutbox,
    syncCursors,
    songConflicts,
    changeLog,
    orgPlays,
    orgMembershipsUser,
    membershipsBand,
    membershipsUser,
    songsLibrary,
    attachmentsSong,
    setlistsBand,
    setItemsSet,
    setItemsSong,
    annotationsOwnerSong,
    changeLogScope,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('songs_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('songs_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('songs_fts', kind: UpdateKind.insert)],
    ),
  ]);
}

typedef $SongsFtsCreateCompanionBuilder = SongsFtsCompanion Function({
  required String title,
  required String artist,
  required String searchText,
  Value<int> rowid,
});
typedef $SongsFtsUpdateCompanionBuilder = SongsFtsCompanion Function({
  Value<String> title,
  Value<String> artist,
  Value<String> searchText,
  Value<int> rowid,
});

class $SongsFtsFilterComposer extends Composer<_$AppDatabase, SongsFts> {
  $SongsFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );
}

class $SongsFtsOrderingComposer extends Composer<_$AppDatabase, SongsFts> {
  $SongsFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SongsFtsAnnotationComposer extends Composer<_$AppDatabase, SongsFts> {
  $SongsFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );
}

class $SongsFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SongsFts,
          SongsFt,
          $SongsFtsFilterComposer,
          $SongsFtsOrderingComposer,
          $SongsFtsAnnotationComposer,
          $SongsFtsCreateCompanionBuilder,
          $SongsFtsUpdateCompanionBuilder,
          (SongsFt, BaseReferences<_$AppDatabase, SongsFts, SongsFt>),
          SongsFt,
          PrefetchHooks Function()
        > {
  $SongsFtsTableManager(_$AppDatabase db, SongsFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SongsFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SongsFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SongsFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsFtsCompanion(
                title: title,
                artist: artist,
                searchText: searchText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String title,
                required String artist,
                required String searchText,
                Value<int> rowid = const Value.absent(),
              }) => SongsFtsCompanion.insert(
                title: title,
                artist: artist,
                searchText: searchText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SongsFts, SongsFt>(table),
                  BaseReferences<_$AppDatabase, SongsFts, SongsFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SongsFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SongsFts,
      SongsFt,
      $SongsFtsFilterComposer,
      $SongsFtsOrderingComposer,
      $SongsFtsAnnotationComposer,
      $SongsFtsCreateCompanionBuilder,
      $SongsFtsUpdateCompanionBuilder,
      (SongsFt, BaseReferences<_$AppDatabase, SongsFts, SongsFt>),
      SongsFt,
      PrefetchHooks Function()
    >;
typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  required String id,
  required String libraryId,
  Value<String> chordproSource,
  required String title,
  Value<String?> artist,
  Value<String?> songKey,
  Value<int?> tempo,
  Value<String?> sequence,
  Value<String?> sortTitle,
  Value<String?> sortArtist,
  Value<String?> searchText,
  Value<int> chordproProblems,
  Value<String?> tags,
  Value<String?> createdBy,
  Value<String?> updatedBy,
  Value<int> revision,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<bool> purged,
  Value<int> rowid,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<String> id,
  Value<String> libraryId,
  Value<String> chordproSource,
  Value<String> title,
  Value<String?> artist,
  Value<String?> songKey,
  Value<int?> tempo,
  Value<String?> sequence,
  Value<String?> sortTitle,
  Value<String?> sortArtist,
  Value<String?> searchText,
  Value<int> chordproProblems,
  Value<String?> tags,
  Value<String?> createdBy,
  Value<String?> updatedBy,
  Value<int> revision,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<bool> purged,
  Value<int> rowid,
});

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, SongEntry> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AttachmentsTable, List<AttachmentEntry>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'songs__id__attachments__song_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SetItemsTable, List<SetItemEntry>>
  _setItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setItems,
    aliasName: 'songs__id__set_items__song_id',
  );

  $$SetItemsTableProcessedTableManager get setItemsRefs {
    final manager = $$SetItemsTableTableManager(
      $_db,
      $_db.setItems,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PersonalOverlaysTable, List<SongOverlay>>
  _personalOverlaysRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.personalOverlays,
    aliasName: 'songs__id__personal_overlays__song_id',
  );

  $$PersonalOverlaysTableProcessedTableManager get personalOverlaysRefs {
    final manager = $$PersonalOverlaysTableTableManager(
      $_db,
      $_db.personalOverlays,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _personalOverlaysRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BandArrangementsTable, List<BandArrangement>>
  _bandArrangementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bandArrangements,
    aliasName: 'songs__id__band_arrangements__song_id',
  );

  $$BandArrangementsTableProcessedTableManager get bandArrangementsRefs {
    final manager = $$BandArrangementsTableTableManager(
      $_db,
      $_db.bandArrangements,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bandArrangementsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnnotationsTable, List<AnnotationRow>>
  _annotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.annotations,
    aliasName: 'songs__id__annotations__song_id',
  );

  $$AnnotationsTableProcessedTableManager get annotationsRefs {
    final manager = $$AnnotationsTableTableManager(
      $_db,
      $_db.annotations,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_annotationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryId => $composableBuilder(
    column: $table.libraryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songKey => $composableBuilder(
    column: $table.songKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortArtist => $composableBuilder(
    column: $table.sortArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chordproProblems => $composableBuilder(
    column: $table.chordproProblems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> setItemsRefs(
    Expression<bool> Function($$SetItemsTableFilterComposer f) f,
  ) {
    final $$SetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setItems,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetItemsTableFilterComposer(
            $db: $db,
            $table: $db.setItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> personalOverlaysRefs(
    Expression<bool> Function($$PersonalOverlaysTableFilterComposer f) f,
  ) {
    final $$PersonalOverlaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personalOverlays,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalOverlaysTableFilterComposer(
            $db: $db,
            $table: $db.personalOverlays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bandArrangementsRefs(
    Expression<bool> Function($$BandArrangementsTableFilterComposer f) f,
  ) {
    final $$BandArrangementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bandArrangements,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandArrangementsTableFilterComposer(
            $db: $db,
            $table: $db.bandArrangements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> annotationsRefs(
    Expression<bool> Function($$AnnotationsTableFilterComposer f) f,
  ) {
    final $$AnnotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableFilterComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryId => $composableBuilder(
    column: $table.libraryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songKey => $composableBuilder(
    column: $table.songKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortArtist => $composableBuilder(
    column: $table.sortArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chordproProblems => $composableBuilder(
    column: $table.chordproProblems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryId =>
      $composableBuilder(column: $table.libraryId, builder: (column) => column);

  GeneratedColumn<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get songKey =>
      $composableBuilder(column: $table.songKey, builder: (column) => column);

  GeneratedColumn<int> get tempo =>
      $composableBuilder(column: $table.tempo, builder: (column) => column);

  GeneratedColumn<String> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get sortTitle =>
      $composableBuilder(column: $table.sortTitle, builder: (column) => column);

  GeneratedColumn<String> get sortArtist => $composableBuilder(
    column: $table.sortArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chordproProblems => $composableBuilder(
    column: $table.chordproProblems,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get purged =>
      $composableBuilder(column: $table.purged, builder: (column) => column);

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> setItemsRefs<T extends Object>(
    Expression<T> Function($$SetItemsTableAnnotationComposer a) f,
  ) {
    final $$SetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setItems,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.setItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> personalOverlaysRefs<T extends Object>(
    Expression<T> Function($$PersonalOverlaysTableAnnotationComposer a) f,
  ) {
    final $$PersonalOverlaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personalOverlays,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalOverlaysTableAnnotationComposer(
            $db: $db,
            $table: $db.personalOverlays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bandArrangementsRefs<T extends Object>(
    Expression<T> Function($$BandArrangementsTableAnnotationComposer a) f,
  ) {
    final $$BandArrangementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bandArrangements,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandArrangementsTableAnnotationComposer(
            $db: $db,
            $table: $db.bandArrangements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> annotationsRefs<T extends Object>(
    Expression<T> Function($$AnnotationsTableAnnotationComposer a) f,
  ) {
    final $$AnnotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongsTable,
          SongEntry,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (SongEntry, $$SongsTableReferences),
          SongEntry,
          PrefetchHooks Function({
            bool attachmentsRefs,
            bool setItemsRefs,
            bool personalOverlaysRefs,
            bool bandArrangementsRefs,
            bool annotationsRefs,
          })
        > {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> chordproSource = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> songKey = const Value.absent(),
                Value<int?> tempo = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<String?> sortTitle = const Value.absent(),
                Value<String?> sortArtist = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<int> chordproProblems = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                libraryId: libraryId,
                chordproSource: chordproSource,
                title: title,
                artist: artist,
                songKey: songKey,
                tempo: tempo,
                sequence: sequence,
                sortTitle: sortTitle,
                sortArtist: sortArtist,
                searchText: searchText,
                chordproProblems: chordproProblems,
                tags: tags,
                createdBy: createdBy,
                updatedBy: updatedBy,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                Value<String> chordproSource = const Value.absent(),
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> songKey = const Value.absent(),
                Value<int?> tempo = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<String?> sortTitle = const Value.absent(),
                Value<String?> sortArtist = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<int> chordproProblems = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                libraryId: libraryId,
                chordproSource: chordproSource,
                title: title,
                artist: artist,
                songKey: songKey,
                tempo: tempo,
                sequence: sequence,
                sortTitle: sortTitle,
                sortArtist: sortArtist,
                searchText: searchText,
                chordproProblems: chordproProblems,
                tags: tags,
                createdBy: createdBy,
                updatedBy: updatedBy,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SongsTable, SongEntry>(table),
                  $$SongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                attachmentsRefs = false,
                setItemsRefs = false,
                personalOverlaysRefs = false,
                bandArrangementsRefs = false,
                annotationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attachmentsRefs) db.attachments,
                    if (setItemsRefs) db.setItems,
                    if (personalOverlaysRefs) db.personalOverlays,
                    if (bandArrangementsRefs) db.bandArrangements,
                    if (annotationsRefs) db.annotations,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attachmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          SongEntry,
                          $SongsTable,
                          AttachmentEntry,
                          $AttachmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'song_id',
                          typedResults: items,
                        ),
                      if (setItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          SongEntry,
                          $SongsTable,
                          SetItemEntry,
                          $SetItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._setItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).setItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'song_id',
                          typedResults: items,
                        ),
                      if (personalOverlaysRefs)
                        await $_getPrefetchedDataByColumns<
                          SongEntry,
                          $SongsTable,
                          SongOverlay,
                          $PersonalOverlaysTable
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._personalOverlaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).personalOverlaysRefs,
                          currentColumn: 'id',
                          referencedColumn: 'song_id',
                          typedResults: items,
                        ),
                      if (bandArrangementsRefs)
                        await $_getPrefetchedDataByColumns<
                          SongEntry,
                          $SongsTable,
                          BandArrangement,
                          $BandArrangementsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._bandArrangementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).bandArrangementsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'song_id',
                          typedResults: items,
                        ),
                      if (annotationsRefs)
                        await $_getPrefetchedDataByColumns<
                          SongEntry,
                          $SongsTable,
                          AnnotationRow,
                          $AnnotationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._annotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).annotationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'song_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongsTable,
      SongEntry,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (SongEntry, $$SongsTableReferences),
      SongEntry,
      PrefetchHooks Function({
        bool attachmentsRefs,
        bool setItemsRefs,
        bool personalOverlaysRefs,
        bool bandArrangementsRefs,
        bool annotationsRefs,
      })
    >;
typedef $$OrganizationsTableCreateCompanionBuilder =
    OrganizationsCompanion Function({
      required String id,
      required String name,
      Value<int> revision,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$OrganizationsTableUpdateCompanionBuilder =
    OrganizationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> revision,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$OrganizationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $OrganizationsTable, OrganizationEntry> {
  $$OrganizationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$OrgMembershipsTable, List<OrgMembershipEntry>>
  _orgMembershipsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.orgMemberships,
    aliasName: 'organizations__id__org_memberships__organization_id',
  );

  $$OrgMembershipsTableProcessedTableManager get orgMembershipsRefs {
    final manager = $$OrgMembershipsTableTableManager(
      $_db,
      $_db.orgMemberships,
    ).filter((f) => f.organizationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_orgMembershipsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BandsTable, List<BandEntry>> _bandsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.bands,
    aliasName: 'organizations__id__bands__organization_id',
  );

  $$BandsTableProcessedTableManager get bandsRefs {
    final manager = $$BandsTableTableManager(
      $_db,
      $_db.bands,
    ).filter((f) => f.organizationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bandsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OrganizationsTableFilterComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> orgMembershipsRefs(
    Expression<bool> Function($$OrgMembershipsTableFilterComposer f) f,
  ) {
    final $$OrgMembershipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orgMemberships,
      getReferencedColumn: (t) => t.organizationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrgMembershipsTableFilterComposer(
            $db: $db,
            $table: $db.orgMemberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bandsRefs(
    Expression<bool> Function($$BandsTableFilterComposer f) f,
  ) {
    final $$BandsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.organizationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableFilterComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OrganizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrganizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> orgMembershipsRefs<T extends Object>(
    Expression<T> Function($$OrgMembershipsTableAnnotationComposer a) f,
  ) {
    final $$OrgMembershipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orgMemberships,
      getReferencedColumn: (t) => t.organizationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrgMembershipsTableAnnotationComposer(
            $db: $db,
            $table: $db.orgMemberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bandsRefs<T extends Object>(
    Expression<T> Function($$BandsTableAnnotationComposer a) f,
  ) {
    final $$BandsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.organizationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableAnnotationComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OrganizationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrganizationsTable,
          OrganizationEntry,
          $$OrganizationsTableFilterComposer,
          $$OrganizationsTableOrderingComposer,
          $$OrganizationsTableAnnotationComposer,
          $$OrganizationsTableCreateCompanionBuilder,
          $$OrganizationsTableUpdateCompanionBuilder,
          (OrganizationEntry, $$OrganizationsTableReferences),
          OrganizationEntry,
          PrefetchHooks Function({bool orgMembershipsRefs, bool bandsRefs})
        > {
  $$OrganizationsTableTableManager(_$AppDatabase db, $OrganizationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrganizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrganizationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrganizationsCompanion(
                id: id,
                name: name,
                revision: revision,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrganizationsCompanion.insert(
                id: id,
                name: name,
                revision: revision,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OrganizationsTable, OrganizationEntry>(table),
                  $$OrganizationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({orgMembershipsRefs = false, bandsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (orgMembershipsRefs) db.orgMemberships,
                    if (bandsRefs) db.bands,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (orgMembershipsRefs)
                        await $_getPrefetchedDataByColumns<
                          OrganizationEntry,
                          $OrganizationsTable,
                          OrgMembershipEntry,
                          $OrgMembershipsTable
                        >(
                          currentTable: table,
                          referencedTable: $$OrganizationsTableReferences
                              ._orgMembershipsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OrganizationsTableReferences(
                                db,
                                table,
                                p0,
                              ).orgMembershipsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'organization_id',
                          typedResults: items,
                        ),
                      if (bandsRefs)
                        await $_getPrefetchedDataByColumns<
                          OrganizationEntry,
                          $OrganizationsTable,
                          BandEntry,
                          $BandsTable
                        >(
                          currentTable: table,
                          referencedTable: $$OrganizationsTableReferences
                              ._bandsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OrganizationsTableReferences(
                                db,
                                table,
                                p0,
                              ).bandsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'organization_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$OrganizationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrganizationsTable,
      OrganizationEntry,
      $$OrganizationsTableFilterComposer,
      $$OrganizationsTableOrderingComposer,
      $$OrganizationsTableAnnotationComposer,
      $$OrganizationsTableCreateCompanionBuilder,
      $$OrganizationsTableUpdateCompanionBuilder,
      (OrganizationEntry, $$OrganizationsTableReferences),
      OrganizationEntry,
      PrefetchHooks Function({bool orgMembershipsRefs, bool bandsRefs})
    >;
typedef $$OrgMembershipsTableCreateCompanionBuilder =
    OrgMembershipsCompanion Function({
      required String id,
      required String organizationId,
      required String userId,
      Value<String> userName,
      Value<String?> userEmail,
      required OrgRole role,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$OrgMembershipsTableUpdateCompanionBuilder =
    OrgMembershipsCompanion Function({
      Value<String> id,
      Value<String> organizationId,
      Value<String> userId,
      Value<String> userName,
      Value<String?> userEmail,
      Value<OrgRole> role,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$OrgMembershipsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OrgMembershipsTable,
          OrgMembershipEntry
        > {
  $$OrgMembershipsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $OrganizationsTable _organizationIdTable(_$AppDatabase db) => db
      .organizations
      .createAlias('org_memberships__organization_id__organizations__id');

  $$OrganizationsTableProcessedTableManager get organizationId {
    final $_column = $_itemColumn<String>('organization_id')!;

    final manager = $$OrganizationsTableTableManager(
      $_db,
      $_db.organizations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_organizationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OrgMembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $OrgMembershipsTable> {
  $$OrgMembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OrgRole, OrgRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$OrganizationsTableFilterComposer get organizationId {
    final $$OrganizationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableFilterComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgMembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrgMembershipsTable> {
  $$OrgMembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$OrganizationsTableOrderingComposer get organizationId {
    final $$OrganizationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableOrderingComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgMembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrgMembershipsTable> {
  $$OrgMembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OrgRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$OrganizationsTableAnnotationComposer get organizationId {
    final $$OrganizationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableAnnotationComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgMembershipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrgMembershipsTable,
          OrgMembershipEntry,
          $$OrgMembershipsTableFilterComposer,
          $$OrgMembershipsTableOrderingComposer,
          $$OrgMembershipsTableAnnotationComposer,
          $$OrgMembershipsTableCreateCompanionBuilder,
          $$OrgMembershipsTableUpdateCompanionBuilder,
          (OrgMembershipEntry, $$OrgMembershipsTableReferences),
          OrgMembershipEntry,
          PrefetchHooks Function({bool organizationId})
        > {
  $$OrgMembershipsTableTableManager(
    _$AppDatabase db,
    $OrgMembershipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrgMembershipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrgMembershipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrgMembershipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> organizationId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                Value<OrgRole> role = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrgMembershipsCompanion(
                id: id,
                organizationId: organizationId,
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                role: role,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String organizationId,
                required String userId,
                Value<String> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                required OrgRole role,
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrgMembershipsCompanion.insert(
                id: id,
                organizationId: organizationId,
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                role: role,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OrgMembershipsTable, OrgMembershipEntry>(table),
                  $$OrgMembershipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({organizationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (organizationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.organizationId,
                        referencedTable: $$OrgMembershipsTableReferences
                            ._organizationIdTable(db),
                        referencedColumn: $$OrgMembershipsTableReferences
                            ._organizationIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OrgMembershipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrgMembershipsTable,
      OrgMembershipEntry,
      $$OrgMembershipsTableFilterComposer,
      $$OrgMembershipsTableOrderingComposer,
      $$OrgMembershipsTableAnnotationComposer,
      $$OrgMembershipsTableCreateCompanionBuilder,
      $$OrgMembershipsTableUpdateCompanionBuilder,
      (OrgMembershipEntry, $$OrgMembershipsTableReferences),
      OrgMembershipEntry,
      PrefetchHooks Function({bool organizationId})
    >;
typedef $$BandsTableCreateCompanionBuilder = BandsCompanion Function({
  required String id,
  required String name,
  Value<String?> organizationId,
  Value<int> revision,
  Value<bool> deleted,
  Value<int> staleAfterMonths,
  Value<int> rowid,
});
typedef $$BandsTableUpdateCompanionBuilder = BandsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> organizationId,
  Value<int> revision,
  Value<bool> deleted,
  Value<int> staleAfterMonths,
  Value<int> rowid,
});

final class $$BandsTableReferences
    extends BaseReferences<_$AppDatabase, $BandsTable, BandEntry> {
  $$BandsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $OrganizationsTable _organizationIdTable(_$AppDatabase db) =>
      db.organizations.createAlias('bands__organization_id__organizations__id');

  $$OrganizationsTableProcessedTableManager? get organizationId {
    final $_column = $_itemColumn<String>('organization_id');
    if ($_column == null) return null;
    final manager = $$OrganizationsTableTableManager(
      $_db,
      $_db.organizations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_organizationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MembershipsTable, List<MembershipEntry>>
  _membershipsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memberships,
    aliasName: 'bands__id__memberships__band_id',
  );

  $$MembershipsTableProcessedTableManager get membershipsRefs {
    final manager = $$MembershipsTableTableManager(
      $_db,
      $_db.memberships,
    ).filter((f) => f.bandId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_membershipsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SetlistsTable, List<SetlistEntry>>
  _setlistsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setlists,
    aliasName: 'bands__id__setlists__band_id',
  );

  $$SetlistsTableProcessedTableManager get setlistsRefs {
    final manager = $$SetlistsTableTableManager(
      $_db,
      $_db.setlists,
    ).filter((f) => f.bandId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setlistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BandsTableFilterComposer extends Composer<_$AppDatabase, $BandsTable> {
  $$BandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get staleAfterMonths => $composableBuilder(
    column: $table.staleAfterMonths,
    builder: (column) => ColumnFilters(column),
  );

  $$OrganizationsTableFilterComposer get organizationId {
    final $$OrganizationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableFilterComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> membershipsRefs(
    Expression<bool> Function($$MembershipsTableFilterComposer f) f,
  ) {
    final $$MembershipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberships,
      getReferencedColumn: (t) => t.bandId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembershipsTableFilterComposer(
            $db: $db,
            $table: $db.memberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> setlistsRefs(
    Expression<bool> Function($$SetlistsTableFilterComposer f) f,
  ) {
    final $$SetlistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.bandId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableFilterComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BandsTableOrderingComposer
    extends Composer<_$AppDatabase, $BandsTable> {
  $$BandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get staleAfterMonths => $composableBuilder(
    column: $table.staleAfterMonths,
    builder: (column) => ColumnOrderings(column),
  );

  $$OrganizationsTableOrderingComposer get organizationId {
    final $$OrganizationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableOrderingComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BandsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BandsTable> {
  $$BandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get staleAfterMonths => $composableBuilder(
    column: $table.staleAfterMonths,
    builder: (column) => column,
  );

  $$OrganizationsTableAnnotationComposer get organizationId {
    final $$OrganizationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.organizationId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableAnnotationComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> membershipsRefs<T extends Object>(
    Expression<T> Function($$MembershipsTableAnnotationComposer a) f,
  ) {
    final $$MembershipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberships,
      getReferencedColumn: (t) => t.bandId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembershipsTableAnnotationComposer(
            $db: $db,
            $table: $db.memberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> setlistsRefs<T extends Object>(
    Expression<T> Function($$SetlistsTableAnnotationComposer a) f,
  ) {
    final $$SetlistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.bandId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableAnnotationComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BandsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BandsTable,
          BandEntry,
          $$BandsTableFilterComposer,
          $$BandsTableOrderingComposer,
          $$BandsTableAnnotationComposer,
          $$BandsTableCreateCompanionBuilder,
          $$BandsTableUpdateCompanionBuilder,
          (BandEntry, $$BandsTableReferences),
          BandEntry,
          PrefetchHooks Function({
            bool organizationId,
            bool membershipsRefs,
            bool setlistsRefs,
          })
        > {
  $$BandsTableTableManager(_$AppDatabase db, $BandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> staleAfterMonths = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BandsCompanion(
                id: id,
                name: name,
                organizationId: organizationId,
                revision: revision,
                deleted: deleted,
                staleAfterMonths: staleAfterMonths,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> organizationId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> staleAfterMonths = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BandsCompanion.insert(
                id: id,
                name: name,
                organizationId: organizationId,
                revision: revision,
                deleted: deleted,
                staleAfterMonths: staleAfterMonths,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BandsTable, BandEntry>(table),
                  $$BandsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                organizationId = false,
                membershipsRefs = false,
                setlistsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (membershipsRefs) db.memberships,
                    if (setlistsRefs) db.setlists,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (organizationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.organizationId,
                            referencedTable: $$BandsTableReferences
                                ._organizationIdTable(db),
                            referencedColumn: $$BandsTableReferences
                                ._organizationIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (membershipsRefs)
                        await $_getPrefetchedDataByColumns<
                          BandEntry,
                          $BandsTable,
                          MembershipEntry,
                          $MembershipsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BandsTableReferences
                              ._membershipsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BandsTableReferences(
                                db,
                                table,
                                p0,
                              ).membershipsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'band_id',
                          typedResults: items,
                        ),
                      if (setlistsRefs)
                        await $_getPrefetchedDataByColumns<
                          BandEntry,
                          $BandsTable,
                          SetlistEntry,
                          $SetlistsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BandsTableReferences
                              ._setlistsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BandsTableReferences(
                                db,
                                table,
                                p0,
                              ).setlistsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'band_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BandsTable,
      BandEntry,
      $$BandsTableFilterComposer,
      $$BandsTableOrderingComposer,
      $$BandsTableAnnotationComposer,
      $$BandsTableCreateCompanionBuilder,
      $$BandsTableUpdateCompanionBuilder,
      (BandEntry, $$BandsTableReferences),
      BandEntry,
      PrefetchHooks Function({
        bool organizationId,
        bool membershipsRefs,
        bool setlistsRefs,
      })
    >;
typedef $$MembershipsTableCreateCompanionBuilder =
    MembershipsCompanion Function({
      required String id,
      required String bandId,
      required String userId,
      Value<String> userName,
      Value<String?> userEmail,
      required BandRole role,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$MembershipsTableUpdateCompanionBuilder =
    MembershipsCompanion Function({
      Value<String> id,
      Value<String> bandId,
      Value<String> userId,
      Value<String> userName,
      Value<String?> userEmail,
      Value<BandRole> role,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$MembershipsTableReferences
    extends BaseReferences<_$AppDatabase, $MembershipsTable, MembershipEntry> {
  $$MembershipsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BandsTable _bandIdTable(_$AppDatabase db) =>
      db.bands.createAlias('memberships__band_id__bands__id');

  $$BandsTableProcessedTableManager get bandId {
    final $_column = $_itemColumn<String>('band_id')!;

    final manager = $$BandsTableTableManager(
      $_db,
      $_db.bands,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bandIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BandRole, BandRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$BandsTableFilterComposer get bandId {
    final $$BandsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableFilterComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEmail => $composableBuilder(
    column: $table.userEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$BandsTableOrderingComposer get bandId {
    final $$BandsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableOrderingComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get userEmail =>
      $composableBuilder(column: $table.userEmail, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BandRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$BandsTableAnnotationComposer get bandId {
    final $$BandsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableAnnotationComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembershipsTable,
          MembershipEntry,
          $$MembershipsTableFilterComposer,
          $$MembershipsTableOrderingComposer,
          $$MembershipsTableAnnotationComposer,
          $$MembershipsTableCreateCompanionBuilder,
          $$MembershipsTableUpdateCompanionBuilder,
          (MembershipEntry, $$MembershipsTableReferences),
          MembershipEntry,
          PrefetchHooks Function({bool bandId})
        > {
  $$MembershipsTableTableManager(_$AppDatabase db, $MembershipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembershipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembershipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembershipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bandId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                Value<BandRole> role = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembershipsCompanion(
                id: id,
                bandId: bandId,
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                role: role,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bandId,
                required String userId,
                Value<String> userName = const Value.absent(),
                Value<String?> userEmail = const Value.absent(),
                required BandRole role,
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembershipsCompanion.insert(
                id: id,
                bandId: bandId,
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                role: role,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MembershipsTable, MembershipEntry>(table),
                  $$MembershipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bandId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bandId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bandId,
                        referencedTable: $$MembershipsTableReferences
                            ._bandIdTable(db),
                        referencedColumn: $$MembershipsTableReferences
                            ._bandIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MembershipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembershipsTable,
      MembershipEntry,
      $$MembershipsTableFilterComposer,
      $$MembershipsTableOrderingComposer,
      $$MembershipsTableAnnotationComposer,
      $$MembershipsTableCreateCompanionBuilder,
      $$MembershipsTableUpdateCompanionBuilder,
      (MembershipEntry, $$MembershipsTableReferences),
      MembershipEntry,
      PrefetchHooks Function({bool bandId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String songId,
      required String name,
      required String fileName,
      Value<String?> remoteFile,
      Value<int?> pages,
      required int sizeBytes,
      Value<int> revision,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<bool> purged,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<String> name,
      Value<String> fileName,
      Value<String?> remoteFile,
      Value<int?> pages,
      Value<int> sizeBytes,
      Value<int> revision,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<DateTime?> deletedAt,
      Value<bool> purged,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentEntry> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('attachments__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteFile => $composableBuilder(
    column: $table.remoteFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteFile => $composableBuilder(
    column: $table.remoteFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get remoteFile => $composableBuilder(
    column: $table.remoteFile,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get purged =>
      $composableBuilder(column: $table.purged, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          AttachmentEntry,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (AttachmentEntry, $$AttachmentsTableReferences),
          AttachmentEntry,
          PrefetchHooks Function({bool songId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> remoteFile = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                songId: songId,
                name: name,
                fileName: fileName,
                remoteFile: remoteFile,
                pages: pages,
                sizeBytes: sizeBytes,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required String name,
                required String fileName,
                Value<String?> remoteFile = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                required int sizeBytes,
                Value<int> revision = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                songId: songId,
                name: name,
                fileName: fileName,
                remoteFile: remoteFile,
                pages: pages,
                sizeBytes: sizeBytes,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, AttachmentEntry>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$AttachmentsTableReferences
                            ._songIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      AttachmentEntry,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (AttachmentEntry, $$AttachmentsTableReferences),
      AttachmentEntry,
      PrefetchHooks Function({bool songId})
    >;
typedef $$SetlistsTableCreateCompanionBuilder = SetlistsCompanion Function({
  required String id,
  required String bandId,
  required String name,
  Value<DateTime?> gigDate,
  Value<String?> venue,
  Value<String?> origin,
  Value<String?> updatedBy,
  Value<int> revision,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<bool> purged,
  Value<int> rowid,
});
typedef $$SetlistsTableUpdateCompanionBuilder = SetlistsCompanion Function({
  Value<String> id,
  Value<String> bandId,
  Value<String> name,
  Value<DateTime?> gigDate,
  Value<String?> venue,
  Value<String?> origin,
  Value<String?> updatedBy,
  Value<int> revision,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<bool> purged,
  Value<int> rowid,
});

final class $$SetlistsTableReferences
    extends BaseReferences<_$AppDatabase, $SetlistsTable, SetlistEntry> {
  $$SetlistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BandsTable _bandIdTable(_$AppDatabase db) =>
      db.bands.createAlias('setlists__band_id__bands__id');

  $$BandsTableProcessedTableManager get bandId {
    final $_column = $_itemColumn<String>('band_id')!;

    final manager = $$BandsTableTableManager(
      $_db,
      $_db.bands,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bandIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SetItemsTable, List<SetItemEntry>>
  _setItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setItems,
    aliasName: 'setlists__id__set_items__set_id',
  );

  $$SetItemsTableProcessedTableManager get setItemsRefs {
    final manager = $$SetItemsTableTableManager(
      $_db,
      $_db.setItems,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SetlistsTableFilterComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gigDate => $composableBuilder(
    column: $table.gigDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get venue => $composableBuilder(
    column: $table.venue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnFilters(column),
  );

  $$BandsTableFilterComposer get bandId {
    final $$BandsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableFilterComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> setItemsRefs(
    Expression<bool> Function($$SetItemsTableFilterComposer f) f,
  ) {
    final $$SetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setItems,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetItemsTableFilterComposer(
            $db: $db,
            $table: $db.setItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SetlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gigDate => $composableBuilder(
    column: $table.gigDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get venue => $composableBuilder(
    column: $table.venue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get purged => $composableBuilder(
    column: $table.purged,
    builder: (column) => ColumnOrderings(column),
  );

  $$BandsTableOrderingComposer get bandId {
    final $$BandsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableOrderingComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get gigDate =>
      $composableBuilder(column: $table.gigDate, builder: (column) => column);

  GeneratedColumn<String> get venue =>
      $composableBuilder(column: $table.venue, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get purged =>
      $composableBuilder(column: $table.purged, builder: (column) => column);

  $$BandsTableAnnotationComposer get bandId {
    final $$BandsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bandId,
      referencedTable: $db.bands,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BandsTableAnnotationComposer(
            $db: $db,
            $table: $db.bands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> setItemsRefs<T extends Object>(
    Expression<T> Function($$SetItemsTableAnnotationComposer a) f,
  ) {
    final $$SetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setItems,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.setItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SetlistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetlistsTable,
          SetlistEntry,
          $$SetlistsTableFilterComposer,
          $$SetlistsTableOrderingComposer,
          $$SetlistsTableAnnotationComposer,
          $$SetlistsTableCreateCompanionBuilder,
          $$SetlistsTableUpdateCompanionBuilder,
          (SetlistEntry, $$SetlistsTableReferences),
          SetlistEntry,
          PrefetchHooks Function({bool bandId, bool setItemsRefs})
        > {
  $$SetlistsTableTableManager(_$AppDatabase db, $SetlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bandId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> gigDate = const Value.absent(),
                Value<String?> venue = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion(
                id: id,
                bandId: bandId,
                name: name,
                gigDate: gigDate,
                venue: venue,
                origin: origin,
                updatedBy: updatedBy,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bandId,
                required String name,
                Value<DateTime?> gigDate = const Value.absent(),
                Value<String?> venue = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> purged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion.insert(
                id: id,
                bandId: bandId,
                name: name,
                gigDate: gigDate,
                venue: venue,
                origin: origin,
                updatedBy: updatedBy,
                revision: revision,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                purged: purged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SetlistsTable, SetlistEntry>(table),
                  $$SetlistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bandId = false, setItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setItemsRefs) db.setItems],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bandId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bandId,
                        referencedTable: $$SetlistsTableReferences._bandIdTable(
                          db,
                        ),
                        referencedColumn: $$SetlistsTableReferences
                            ._bandIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      SetlistEntry,
                      $SetlistsTable,
                      SetItemEntry,
                      $SetItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SetlistsTableReferences
                          ._setItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SetlistsTableReferences(db, table, p0).setItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'set_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SetlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetlistsTable,
      SetlistEntry,
      $$SetlistsTableFilterComposer,
      $$SetlistsTableOrderingComposer,
      $$SetlistsTableAnnotationComposer,
      $$SetlistsTableCreateCompanionBuilder,
      $$SetlistsTableUpdateCompanionBuilder,
      (SetlistEntry, $$SetlistsTableReferences),
      SetlistEntry,
      PrefetchHooks Function({bool bandId, bool setItemsRefs})
    >;
typedef $$SetItemsTableCreateCompanionBuilder = SetItemsCompanion Function({
  required String id,
  required String setId,
  Value<String?> songId,
  required int position,
  Value<int> transpose,
  Value<String?> sequence,
  Value<String?> note,
  required SetItemType type,
  Value<PlayedValues?> played,
  Value<String?> extra,
  Value<int> rowid,
});
typedef $$SetItemsTableUpdateCompanionBuilder = SetItemsCompanion Function({
  Value<String> id,
  Value<String> setId,
  Value<String?> songId,
  Value<int> position,
  Value<int> transpose,
  Value<String?> sequence,
  Value<String?> note,
  Value<SetItemType> type,
  Value<PlayedValues?> played,
  Value<String?> extra,
  Value<int> rowid,
});

final class $$SetItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SetItemsTable, SetItemEntry> {
  $$SetItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SetlistsTable _setIdTable(_$AppDatabase db) =>
      db.setlists.createAlias('set_items__set_id__setlists__id');

  $$SetlistsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<String>('set_id')!;

    final manager = $$SetlistsTableTableManager(
      $_db,
      $_db.setlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('set_items__song_id__songs__id');

  $$SongsTableProcessedTableManager? get songId {
    final $_column = $_itemColumn<String>('song_id');
    if ($_column == null) return null;
    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SetItemsTable> {
  $$SetItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SetItemType, SetItemType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<PlayedValues?, PlayedValues, String>
  get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );

  $$SetlistsTableFilterComposer get setId {
    final $$SetlistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableFilterComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetItemsTable> {
  $$SetItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );

  $$SetlistsTableOrderingComposer get setId {
    final $$SetlistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableOrderingComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetItemsTable> {
  $$SetItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get transpose =>
      $composableBuilder(column: $table.transpose, builder: (column) => column);

  GeneratedColumn<String> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SetItemType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlayedValues?, String> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);

  $$SetlistsTableAnnotationComposer get setId {
    final $$SetlistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableAnnotationComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetItemsTable,
          SetItemEntry,
          $$SetItemsTableFilterComposer,
          $$SetItemsTableOrderingComposer,
          $$SetItemsTableAnnotationComposer,
          $$SetItemsTableCreateCompanionBuilder,
          $$SetItemsTableUpdateCompanionBuilder,
          (SetItemEntry, $$SetItemsTableReferences),
          SetItemEntry,
          PrefetchHooks Function({bool setId, bool songId})
        > {
  $$SetItemsTableTableManager(_$AppDatabase db, $SetItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<String?> songId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> transpose = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<SetItemType> type = const Value.absent(),
                Value<PlayedValues?> played = const Value.absent(),
                Value<String?> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetItemsCompanion(
                id: id,
                setId: setId,
                songId: songId,
                position: position,
                transpose: transpose,
                sequence: sequence,
                note: note,
                type: type,
                played: played,
                extra: extra,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String setId,
                Value<String?> songId = const Value.absent(),
                required int position,
                Value<int> transpose = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required SetItemType type,
                Value<PlayedValues?> played = const Value.absent(),
                Value<String?> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetItemsCompanion.insert(
                id: id,
                setId: setId,
                songId: songId,
                position: position,
                transpose: transpose,
                sequence: sequence,
                note: note,
                type: type,
                played: played,
                extra: extra,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SetItemsTable, SetItemEntry>(table),
                  $$SetItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $$SetItemsTableReferences._setIdTable(
                          db,
                        ),
                        referencedColumn: $$SetItemsTableReferences
                            ._setIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$SetItemsTableReferences._songIdTable(
                          db,
                        ),
                        referencedColumn: $$SetItemsTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetItemsTable,
      SetItemEntry,
      $$SetItemsTableFilterComposer,
      $$SetItemsTableOrderingComposer,
      $$SetItemsTableAnnotationComposer,
      $$SetItemsTableCreateCompanionBuilder,
      $$SetItemsTableUpdateCompanionBuilder,
      (SetItemEntry, $$SetItemsTableReferences),
      SetItemEntry,
      PrefetchHooks Function({bool setId, bool songId})
    >;
typedef $$PersonalOverlaysTableCreateCompanionBuilder =
    PersonalOverlaysCompanion Function({
      Value<String> ownerId,
      required String songId,
      Value<int> transpose,
      Value<int> capo,
      Value<int?> capoFret,
      Value<double> fontScale,
      Value<String?> notes,
      Value<bool?> nashville,
      Value<String?> liveView,
      Value<bool> hideAnnotations,
      Value<VerseChords> verseChords,
      Value<MidiProgram?> midi,
      Value<MidiPrograms?> midiPrograms,
      Value<String?> clickGrouping,
      Value<Subdivision?> clickSubdivision,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$PersonalOverlaysTableUpdateCompanionBuilder =
    PersonalOverlaysCompanion Function({
      Value<String> ownerId,
      Value<String> songId,
      Value<int> transpose,
      Value<int> capo,
      Value<int?> capoFret,
      Value<double> fontScale,
      Value<String?> notes,
      Value<bool?> nashville,
      Value<String?> liveView,
      Value<bool> hideAnnotations,
      Value<VerseChords> verseChords,
      Value<MidiProgram?> midi,
      Value<MidiPrograms?> midiPrograms,
      Value<String?> clickGrouping,
      Value<Subdivision?> clickSubdivision,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$PersonalOverlaysTableReferences
    extends BaseReferences<_$AppDatabase, $PersonalOverlaysTable, SongOverlay> {
  $$PersonalOverlaysTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('personal_overlays__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PersonalOverlaysTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalOverlaysTable> {
  $$PersonalOverlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capo => $composableBuilder(
    column: $table.capo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capoFret => $composableBuilder(
    column: $table.capoFret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nashville => $composableBuilder(
    column: $table.nashville,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get liveView => $composableBuilder(
    column: $table.liveView,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hideAnnotations => $composableBuilder(
    column: $table.hideAnnotations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VerseChords, VerseChords, String>
  get verseChords => $composableBuilder(
    column: $table.verseChords,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<MidiProgram?, MidiProgram, String> get midi =>
      $composableBuilder(
        column: $table.midi,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MidiPrograms?, MidiPrograms, String>
  get midiPrograms => $composableBuilder(
    column: $table.midiPrograms,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get clickGrouping => $composableBuilder(
    column: $table.clickGrouping,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Subdivision?, Subdivision, String>
  get clickSubdivision => $composableBuilder(
    column: $table.clickSubdivision,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalOverlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalOverlaysTable> {
  $$PersonalOverlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capo => $composableBuilder(
    column: $table.capo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capoFret => $composableBuilder(
    column: $table.capoFret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nashville => $composableBuilder(
    column: $table.nashville,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get liveView => $composableBuilder(
    column: $table.liveView,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hideAnnotations => $composableBuilder(
    column: $table.hideAnnotations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verseChords => $composableBuilder(
    column: $table.verseChords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get midi => $composableBuilder(
    column: $table.midi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get midiPrograms => $composableBuilder(
    column: $table.midiPrograms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clickGrouping => $composableBuilder(
    column: $table.clickGrouping,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clickSubdivision => $composableBuilder(
    column: $table.clickSubdivision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalOverlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalOverlaysTable> {
  $$PersonalOverlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get transpose =>
      $composableBuilder(column: $table.transpose, builder: (column) => column);

  GeneratedColumn<int> get capo =>
      $composableBuilder(column: $table.capo, builder: (column) => column);

  GeneratedColumn<int> get capoFret =>
      $composableBuilder(column: $table.capoFret, builder: (column) => column);

  GeneratedColumn<double> get fontScale =>
      $composableBuilder(column: $table.fontScale, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get nashville =>
      $composableBuilder(column: $table.nashville, builder: (column) => column);

  GeneratedColumn<String> get liveView =>
      $composableBuilder(column: $table.liveView, builder: (column) => column);

  GeneratedColumn<bool> get hideAnnotations => $composableBuilder(
    column: $table.hideAnnotations,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<VerseChords, String> get verseChords =>
      $composableBuilder(
        column: $table.verseChords,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<MidiProgram?, String> get midi =>
      $composableBuilder(column: $table.midi, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MidiPrograms?, String> get midiPrograms =>
      $composableBuilder(
        column: $table.midiPrograms,
        builder: (column) => column,
      );

  GeneratedColumn<String> get clickGrouping => $composableBuilder(
    column: $table.clickGrouping,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Subdivision?, String> get clickSubdivision =>
      $composableBuilder(
        column: $table.clickSubdivision,
        builder: (column) => column,
      );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalOverlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalOverlaysTable,
          SongOverlay,
          $$PersonalOverlaysTableFilterComposer,
          $$PersonalOverlaysTableOrderingComposer,
          $$PersonalOverlaysTableAnnotationComposer,
          $$PersonalOverlaysTableCreateCompanionBuilder,
          $$PersonalOverlaysTableUpdateCompanionBuilder,
          (SongOverlay, $$PersonalOverlaysTableReferences),
          SongOverlay,
          PrefetchHooks Function({bool songId})
        > {
  $$PersonalOverlaysTableTableManager(
    _$AppDatabase db,
    $PersonalOverlaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalOverlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalOverlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalOverlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> transpose = const Value.absent(),
                Value<int> capo = const Value.absent(),
                Value<int?> capoFret = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool?> nashville = const Value.absent(),
                Value<String?> liveView = const Value.absent(),
                Value<bool> hideAnnotations = const Value.absent(),
                Value<VerseChords> verseChords = const Value.absent(),
                Value<MidiProgram?> midi = const Value.absent(),
                Value<MidiPrograms?> midiPrograms = const Value.absent(),
                Value<String?> clickGrouping = const Value.absent(),
                Value<Subdivision?> clickSubdivision = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalOverlaysCompanion(
                ownerId: ownerId,
                songId: songId,
                transpose: transpose,
                capo: capo,
                capoFret: capoFret,
                fontScale: fontScale,
                notes: notes,
                nashville: nashville,
                liveView: liveView,
                hideAnnotations: hideAnnotations,
                verseChords: verseChords,
                midi: midi,
                midiPrograms: midiPrograms,
                clickGrouping: clickGrouping,
                clickSubdivision: clickSubdivision,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                required String songId,
                Value<int> transpose = const Value.absent(),
                Value<int> capo = const Value.absent(),
                Value<int?> capoFret = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool?> nashville = const Value.absent(),
                Value<String?> liveView = const Value.absent(),
                Value<bool> hideAnnotations = const Value.absent(),
                Value<VerseChords> verseChords = const Value.absent(),
                Value<MidiProgram?> midi = const Value.absent(),
                Value<MidiPrograms?> midiPrograms = const Value.absent(),
                Value<String?> clickGrouping = const Value.absent(),
                Value<Subdivision?> clickSubdivision = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalOverlaysCompanion.insert(
                ownerId: ownerId,
                songId: songId,
                transpose: transpose,
                capo: capo,
                capoFret: capoFret,
                fontScale: fontScale,
                notes: notes,
                nashville: nashville,
                liveView: liveView,
                hideAnnotations: hideAnnotations,
                verseChords: verseChords,
                midi: midi,
                midiPrograms: midiPrograms,
                clickGrouping: clickGrouping,
                clickSubdivision: clickSubdivision,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonalOverlaysTable, SongOverlay>(table),
                  $$PersonalOverlaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$PersonalOverlaysTableReferences
                            ._songIdTable(db),
                        referencedColumn: $$PersonalOverlaysTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PersonalOverlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalOverlaysTable,
      SongOverlay,
      $$PersonalOverlaysTableFilterComposer,
      $$PersonalOverlaysTableOrderingComposer,
      $$PersonalOverlaysTableAnnotationComposer,
      $$PersonalOverlaysTableCreateCompanionBuilder,
      $$PersonalOverlaysTableUpdateCompanionBuilder,
      (SongOverlay, $$PersonalOverlaysTableReferences),
      SongOverlay,
      PrefetchHooks Function({bool songId})
    >;
typedef $$BandArrangementsTableCreateCompanionBuilder =
    BandArrangementsCompanion Function({
      required String bandId,
      required String songId,
      Value<int> transpose,
      Value<String?> sequence,
      Value<int?> tempo,
      Value<String?> updatedBy,
      Value<int> revision,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$BandArrangementsTableUpdateCompanionBuilder =
    BandArrangementsCompanion Function({
      Value<String> bandId,
      Value<String> songId,
      Value<int> transpose,
      Value<String?> sequence,
      Value<int?> tempo,
      Value<String?> updatedBy,
      Value<int> revision,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$BandArrangementsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BandArrangementsTable, BandArrangement> {
  $$BandArrangementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('band_arrangements__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BandArrangementsTableFilterComposer
    extends Composer<_$AppDatabase, $BandArrangementsTable> {
  $$BandArrangementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bandId => $composableBuilder(
    column: $table.bandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BandArrangementsTableOrderingComposer
    extends Composer<_$AppDatabase, $BandArrangementsTable> {
  $$BandArrangementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bandId => $composableBuilder(
    column: $table.bandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transpose => $composableBuilder(
    column: $table.transpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BandArrangementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BandArrangementsTable> {
  $$BandArrangementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bandId =>
      $composableBuilder(column: $table.bandId, builder: (column) => column);

  GeneratedColumn<int> get transpose =>
      $composableBuilder(column: $table.transpose, builder: (column) => column);

  GeneratedColumn<String> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get tempo =>
      $composableBuilder(column: $table.tempo, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BandArrangementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BandArrangementsTable,
          BandArrangement,
          $$BandArrangementsTableFilterComposer,
          $$BandArrangementsTableOrderingComposer,
          $$BandArrangementsTableAnnotationComposer,
          $$BandArrangementsTableCreateCompanionBuilder,
          $$BandArrangementsTableUpdateCompanionBuilder,
          (BandArrangement, $$BandArrangementsTableReferences),
          BandArrangement,
          PrefetchHooks Function({bool songId})
        > {
  $$BandArrangementsTableTableManager(
    _$AppDatabase db,
    $BandArrangementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BandArrangementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BandArrangementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BandArrangementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bandId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> transpose = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<int?> tempo = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BandArrangementsCompanion(
                bandId: bandId,
                songId: songId,
                transpose: transpose,
                sequence: sequence,
                tempo: tempo,
                updatedBy: updatedBy,
                revision: revision,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bandId,
                required String songId,
                Value<int> transpose = const Value.absent(),
                Value<String?> sequence = const Value.absent(),
                Value<int?> tempo = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BandArrangementsCompanion.insert(
                bandId: bandId,
                songId: songId,
                transpose: transpose,
                sequence: sequence,
                tempo: tempo,
                updatedBy: updatedBy,
                revision: revision,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BandArrangementsTable, BandArrangement>(table),
                  $$BandArrangementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$BandArrangementsTableReferences
                            ._songIdTable(db),
                        referencedColumn: $$BandArrangementsTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BandArrangementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BandArrangementsTable,
      BandArrangement,
      $$BandArrangementsTableFilterComposer,
      $$BandArrangementsTableOrderingComposer,
      $$BandArrangementsTableAnnotationComposer,
      $$BandArrangementsTableCreateCompanionBuilder,
      $$BandArrangementsTableUpdateCompanionBuilder,
      (BandArrangement, $$BandArrangementsTableReferences),
      BandArrangement,
      PrefetchHooks Function({bool songId})
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      required String ownerId,
      Value<String> data,
      Value<String> dirtyKeys,
      Value<int> revision,
      Value<bool> adopting,
      Value<int> rowid,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<String> ownerId,
      Value<String> data,
      Value<String> dirtyKeys,
      Value<int> revision,
      Value<bool> adopting,
      Value<int> rowid,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dirtyKeys => $composableBuilder(
    column: $table.dirtyKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get adopting => $composableBuilder(
    column: $table.adopting,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dirtyKeys => $composableBuilder(
    column: $table.dirtyKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get adopting => $composableBuilder(
    column: $table.adopting,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get dirtyKeys =>
      $composableBuilder(column: $table.dirtyKeys, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get adopting =>
      $composableBuilder(column: $table.adopting, builder: (column) => column);
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSettingsRow,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSettingsRow,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingsRow>,
          ),
          UserSettingsRow,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> dirtyKeys = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> adopting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion(
                ownerId: ownerId,
                data: data,
                dirtyKeys: dirtyKeys,
                revision: revision,
                adopting: adopting,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                Value<String> data = const Value.absent(),
                Value<String> dirtyKeys = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> adopting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                ownerId: ownerId,
                data: data,
                dirtyKeys: dirtyKeys,
                revision: revision,
                adopting: adopting,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserSettingsTable, UserSettingsRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserSettingsTable,
                    UserSettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSettingsRow,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSettingsRow,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingsRow>,
      ),
      UserSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$AnnotationsTableCreateCompanionBuilder =
    AnnotationsCompanion Function({
      required String id,
      required String ownerId,
      required String songId,
      Value<String> target,
      Value<String?> stroke,
      required int updatedAt,
      Value<int> pending,
      Value<int> rowid,
    });
typedef $$AnnotationsTableUpdateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> songId,
      Value<String> target,
      Value<String?> stroke,
      Value<int> updatedAt,
      Value<int> pending,
      Value<int> rowid,
    });

final class $$AnnotationsTableReferences
    extends BaseReferences<_$AppDatabase, $AnnotationsTable, AnnotationRow> {
  $$AnnotationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('annotations__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stroke => $composableBuilder(
    column: $table.stroke,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get stroke =>
      $composableBuilder(column: $table.stroke, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          AnnotationRow,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (AnnotationRow, $$AnnotationsTableReferences),
          AnnotationRow,
          PrefetchHooks Function({bool songId})
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String?> stroke = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> pending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                ownerId: ownerId,
                songId: songId,
                target: target,
                stroke: stroke,
                updatedAt: updatedAt,
                pending: pending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String songId,
                Value<String> target = const Value.absent(),
                Value<String?> stroke = const Value.absent(),
                required int updatedAt,
                Value<int> pending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion.insert(
                id: id,
                ownerId: ownerId,
                songId: songId,
                target: target,
                stroke: stroke,
                updatedAt: updatedAt,
                pending: pending,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnnotationsTable, AnnotationRow>(table),
                  $$AnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$AnnotationsTableReferences
                            ._songIdTable(db),
                        referencedColumn: $$AnnotationsTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      AnnotationRow,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (AnnotationRow, $$AnnotationsTableReferences),
      AnnotationRow,
      PrefetchHooks Function({bool songId})
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String collection,
  required String recordId,
  Value<int> version,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> collection,
  Value<String> recordId,
  Value<int> version,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          OutboxEntry,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                collection: collection,
                recordId: recordId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String recordId,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                collection: collection,
                recordId: recordId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, OutboxEntry>(table),
                  BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      OutboxEntry,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String scope,
      required String collection,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> scope,
      Value<String> collection,
      Value<int> revision,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> collection = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                scope: scope,
                collection: collection,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String collection,
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                scope: scope,
                collection: collection,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$SongConflictsTableCreateCompanionBuilder =
    SongConflictsCompanion Function({
      required String songId,
      required String title,
      required String chordproSource,
      required int revision,
      Value<bool> deleted,
      required DateTime detectedAt,
      Value<int> rowid,
    });
typedef $$SongConflictsTableUpdateCompanionBuilder =
    SongConflictsCompanion Function({
      Value<String> songId,
      Value<String> title,
      Value<String> chordproSource,
      Value<int> revision,
      Value<bool> deleted,
      Value<DateTime> detectedAt,
      Value<int> rowid,
    });

class $$SongConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SongConflictsTable> {
  $$SongConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SongConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongConflictsTable> {
  $$SongConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongConflictsTable> {
  $$SongConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get chordproSource => $composableBuilder(
    column: $table.chordproSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );
}

class $$SongConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongConflictsTable,
          SongConflict,
          $$SongConflictsTableFilterComposer,
          $$SongConflictsTableOrderingComposer,
          $$SongConflictsTableAnnotationComposer,
          $$SongConflictsTableCreateCompanionBuilder,
          $$SongConflictsTableUpdateCompanionBuilder,
          (
            SongConflict,
            BaseReferences<_$AppDatabase, $SongConflictsTable, SongConflict>,
          ),
          SongConflict,
          PrefetchHooks Function()
        > {
  $$SongConflictsTableTableManager(_$AppDatabase db, $SongConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> songId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> chordproSource = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongConflictsCompanion(
                songId: songId,
                title: title,
                chordproSource: chordproSource,
                revision: revision,
                deleted: deleted,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String songId,
                required String title,
                required String chordproSource,
                required int revision,
                Value<bool> deleted = const Value.absent(),
                required DateTime detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => SongConflictsCompanion.insert(
                songId: songId,
                title: title,
                chordproSource: chordproSource,
                revision: revision,
                deleted: deleted,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SongConflictsTable, SongConflict>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SongConflictsTable,
                    SongConflict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SongConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongConflictsTable,
      SongConflict,
      $$SongConflictsTableFilterComposer,
      $$SongConflictsTableOrderingComposer,
      $$SongConflictsTableAnnotationComposer,
      $$SongConflictsTableCreateCompanionBuilder,
      $$SongConflictsTableUpdateCompanionBuilder,
      (
        SongConflict,
        BaseReferences<_$AppDatabase, $SongConflictsTable, SongConflict>,
      ),
      SongConflict,
      PrefetchHooks Function()
    >;
typedef $$ChangeLogTableCreateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> id,
  required DateTime at,
  required ChangeKind kind,
  required String scopeId,
  required String recordId,
  required String title,
  Value<String?> userId,
  Value<String> details,
});
typedef $$ChangeLogTableUpdateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> id,
  Value<DateTime> at,
  Value<ChangeKind> kind,
  Value<String> scopeId,
  Value<String> recordId,
  Value<String> title,
  Value<String?> userId,
  Value<String> details,
});

class $$ChangeLogTableFilterComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ChangeKind, ChangeKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangeLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangeLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChangeKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$ChangeLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChangeLogTable,
          ChangeLogRow,
          $$ChangeLogTableFilterComposer,
          $$ChangeLogTableOrderingComposer,
          $$ChangeLogTableAnnotationComposer,
          $$ChangeLogTableCreateCompanionBuilder,
          $$ChangeLogTableUpdateCompanionBuilder,
          (
            ChangeLogRow,
            BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>,
          ),
          ChangeLogRow,
          PrefetchHooks Function()
        > {
  $$ChangeLogTableTableManager(_$AppDatabase db, $ChangeLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangeLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangeLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangeLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<ChangeKind> kind = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> details = const Value.absent(),
              }) => ChangeLogCompanion(
                id: id,
                at: at,
                kind: kind,
                scopeId: scopeId,
                recordId: recordId,
                title: title,
                userId: userId,
                details: details,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                required ChangeKind kind,
                required String scopeId,
                required String recordId,
                required String title,
                Value<String?> userId = const Value.absent(),
                Value<String> details = const Value.absent(),
              }) => ChangeLogCompanion.insert(
                id: id,
                at: at,
                kind: kind,
                scopeId: scopeId,
                recordId: recordId,
                title: title,
                userId: userId,
                details: details,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangeLogTable, ChangeLogRow>(table),
                  BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangeLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChangeLogTable,
      ChangeLogRow,
      $$ChangeLogTableFilterComposer,
      $$ChangeLogTableOrderingComposer,
      $$ChangeLogTableAnnotationComposer,
      $$ChangeLogTableCreateCompanionBuilder,
      $$ChangeLogTableUpdateCompanionBuilder,
      (
        ChangeLogRow,
        BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>,
      ),
      ChangeLogRow,
      PrefetchHooks Function()
    >;
typedef $$OrgPlaysTableCreateCompanionBuilder = OrgPlaysCompanion Function({
  required String organizationId,
  required String songId,
  required String bandId,
  required String bandName,
  required int playCount,
  required DateTime lastPlayed,
  Value<String?> playedKey,
  Value<int> rowid,
});
typedef $$OrgPlaysTableUpdateCompanionBuilder = OrgPlaysCompanion Function({
  Value<String> organizationId,
  Value<String> songId,
  Value<String> bandId,
  Value<String> bandName,
  Value<int> playCount,
  Value<DateTime> lastPlayed,
  Value<String?> playedKey,
  Value<int> rowid,
});

class $$OrgPlaysTableFilterComposer
    extends Composer<_$AppDatabase, $OrgPlaysTable> {
  $$OrgPlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bandId => $composableBuilder(
    column: $table.bandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bandName => $composableBuilder(
    column: $table.bandName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playedKey => $composableBuilder(
    column: $table.playedKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrgPlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $OrgPlaysTable> {
  $$OrgPlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bandId => $composableBuilder(
    column: $table.bandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bandName => $composableBuilder(
    column: $table.bandName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playedKey => $composableBuilder(
    column: $table.playedKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrgPlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrgPlaysTable> {
  $$OrgPlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get bandId =>
      $composableBuilder(column: $table.bandId, builder: (column) => column);

  GeneratedColumn<String> get bandName =>
      $composableBuilder(column: $table.bandName, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayed => $composableBuilder(
    column: $table.lastPlayed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playedKey =>
      $composableBuilder(column: $table.playedKey, builder: (column) => column);
}

class $$OrgPlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrgPlaysTable,
          OrgPlay,
          $$OrgPlaysTableFilterComposer,
          $$OrgPlaysTableOrderingComposer,
          $$OrgPlaysTableAnnotationComposer,
          $$OrgPlaysTableCreateCompanionBuilder,
          $$OrgPlaysTableUpdateCompanionBuilder,
          (OrgPlay, BaseReferences<_$AppDatabase, $OrgPlaysTable, OrgPlay>),
          OrgPlay,
          PrefetchHooks Function()
        > {
  $$OrgPlaysTableTableManager(_$AppDatabase db, $OrgPlaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrgPlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrgPlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrgPlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> organizationId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<String> bandId = const Value.absent(),
                Value<String> bandName = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<DateTime> lastPlayed = const Value.absent(),
                Value<String?> playedKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrgPlaysCompanion(
                organizationId: organizationId,
                songId: songId,
                bandId: bandId,
                bandName: bandName,
                playCount: playCount,
                lastPlayed: lastPlayed,
                playedKey: playedKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String organizationId,
                required String songId,
                required String bandId,
                required String bandName,
                required int playCount,
                required DateTime lastPlayed,
                Value<String?> playedKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrgPlaysCompanion.insert(
                organizationId: organizationId,
                songId: songId,
                bandId: bandId,
                bandName: bandName,
                playCount: playCount,
                lastPlayed: lastPlayed,
                playedKey: playedKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OrgPlaysTable, OrgPlay>(table),
                  BaseReferences<_$AppDatabase, $OrgPlaysTable, OrgPlay>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrgPlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrgPlaysTable,
      OrgPlay,
      $$OrgPlaysTableFilterComposer,
      $$OrgPlaysTableOrderingComposer,
      $$OrgPlaysTableAnnotationComposer,
      $$OrgPlaysTableCreateCompanionBuilder,
      $$OrgPlaysTableUpdateCompanionBuilder,
      (OrgPlay, BaseReferences<_$AppDatabase, $OrgPlaysTable, OrgPlay>),
      OrgPlay,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $SongsFtsTableManager get songsFts =>
      $SongsFtsTableManager(_db, _db.songsFts);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$OrganizationsTableTableManager get organizations =>
      $$OrganizationsTableTableManager(_db, _db.organizations);
  $$OrgMembershipsTableTableManager get orgMemberships =>
      $$OrgMembershipsTableTableManager(_db, _db.orgMemberships);
  $$BandsTableTableManager get bands =>
      $$BandsTableTableManager(_db, _db.bands);
  $$MembershipsTableTableManager get memberships =>
      $$MembershipsTableTableManager(_db, _db.memberships);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$SetlistsTableTableManager get setlists =>
      $$SetlistsTableTableManager(_db, _db.setlists);
  $$SetItemsTableTableManager get setItems =>
      $$SetItemsTableTableManager(_db, _db.setItems);
  $$PersonalOverlaysTableTableManager get personalOverlays =>
      $$PersonalOverlaysTableTableManager(_db, _db.personalOverlays);
  $$BandArrangementsTableTableManager get bandArrangements =>
      $$BandArrangementsTableTableManager(_db, _db.bandArrangements);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$SongConflictsTableTableManager get songConflicts =>
      $$SongConflictsTableTableManager(_db, _db.songConflicts);
  $$ChangeLogTableTableManager get changeLog =>
      $$ChangeLogTableTableManager(_db, _db.changeLog);
  $$OrgPlaysTableTableManager get orgPlays =>
      $$OrgPlaysTableTableManager(_db, _db.orgPlays);
}
