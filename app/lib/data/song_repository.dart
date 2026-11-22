import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'deletions.dart';
import 'language_detection.dart';
import 'outbox.dart';
import 'text.dart';

const _uuid = Uuid();

/// Metadata extracted from a ChordPro source (ADR-0003).
class SongMeta {
  const SongMeta({
    this.title,
    this.artist,
    this.key,
    this.tempo,
    this.sortTitle,
    this.sortArtist,
    this.tags = const [],
    this.searchText,
    this.sequence,
    this.problems = 0,
    this.conversions = 0,
    this.language,
  });

  factory SongMeta.fromSource(String source) {
    final song = cp.parseChordPro(source);
    final searchText = blankToNull(
      [
        for (final section in song.sections)
          for (final line in section.lines)
            if (line is cp.LyricLine)
              line.plainText
            else if (line is cp.CommentLine)
              cp.stripMarkup(line.text),
      ].join('\n'),
    );
    return SongMeta(
      problems: cp.validateChordPro(source).length,
      conversions: cp.countChordProConversions(source),
      title: blankToNull(song.title),
      artist: blankToNull(song.artist),
      key: blankToNull(song.keyName),
      tempo: song.tempo,
      sortTitle: blankToNull(song.sortTitle),
      sortArtist: blankToNull(song.sortArtist),
      sequence: cp.findSequence(source),
      tags: [
        for (final t in song.tags)
          if (t.trim().isNotEmpty) t.trim(),
      ],
      searchText: searchText,
      language: detectLanguage(searchText),
    );
  }

  final String? title;
  final String? artist;
  final String? key;
  final int? tempo;
  final String? sortTitle;
  final String? sortArtist;

  final List<String> tags;

  /// Lyrics and comments without chords and markup (full-text search).
  final String? searchText;

  /// Raw `{x_sequence}` value (song list).
  final String? sequence;

  /// Number of ChordPro problems (`validateChordPro`, #314).
  final int problems;

  /// Number of places the editor offers to convert
  /// (`countChordProConversions`, #798).
  final int conversions;

  /// Language detected from the lyrics (ADR-0053, `detectLanguage`), or
  /// null when it is unclear.
  final String? language;

  /// Tags as stored in the database (see `Songs.tags`).
  String? get tagsColumn => tags.isEmpty ? null : '\n${tags.join('\n')}\n';
}

/// Metadata of ChordPro [sources]; larger batches (e.g. the first sync of a
/// library) are parsed outside the UI isolate.
Future<List<SongMeta>> songMetas(List<String> sources) => sources.length < 20
    ? Future.value(_metas(sources))
    : compute(_metas, sources);

List<SongMeta> _metas(List<String> sources) => [
  for (final s in sources) SongMeta.fromSource(s),
];

/// The FTS5 query for a search text: every word must occur as the start of
/// a word, in any order. Null when the text has no letters or digits.
String? songSearchMatch(String query) {
  final words = [
    for (final w in query.trim().split(RegExp(r'\s+')))
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(w)) w,
  ];
  if (words.isEmpty) return null;
  return words.map((w) => '"${w.replaceAll('"', '""')}"*').join(' ');
}

/// Start and end of a search hit in the texts of [SearchHit].
const hitStart = '\u0002', hitEnd = '\u0003';

/// Where a search matched a song: title and artist with the hits marked
/// ([hitStart] … [hitEnd]), and a snippet of the lyrics around a hit (null
/// when the lyrics did not match).
typedef SearchHit = ({String title, String? artist, String? lyrics});

/// Owner of personal adjustments of songs in [libraryId] for [userId]
/// (ADR-0020).
String overlayOwnerFor(String libraryId, String? userId) =>
    libraryId == localBandId || userId == null ? localOwnerId : userId;

/// Gives [userId] the adjustments of the local owner for songs of
/// organizations, once per device after the upgrade to schema 8 (ADR-0020);
/// returns how many were taken over. Adjustments of the local library stay
/// with the local owner.
Future<int> adoptLocalOverlays(AppDatabase db, String userId) =>
    db.customUpdate(
      'UPDATE OR IGNORE personal_overlays SET owner_id = ? '
      'WHERE owner_id = ? AND song_id IN '
      '(SELECT id FROM songs WHERE library_id != ?)',
      variables: [
        Variable.withString(userId),
        Variable.withString(localOwnerId),
        Variable.withString(localBandId),
      ],
      updates: {db.personalOverlays},
      updateKind: UpdateKind.update,
    );

/// Tags of a song as stored in the database.
List<String> songTags(SongEntry song) => _tags(song.tags);

List<String> _tags(String? column) => [
  for (final t in (column ?? '').split('\n'))
    if (t.isNotEmpty) t,
];

/// Order of the song list.
enum SongSort {
  /// By `{sorttitle}` or title.
  title,

  /// By `{sortartist}` or artist, songs without one last; then by title.
  artist,

  /// By key (C to B, major before minor), songs without one last; then by
  /// title.
  key,

  /// Last edited first.
  recent,

  /// Last played by the current band first, never played last (ADR-0046);
  /// the song list sorts by the band's plays, the database by title.
  lastPlayed,
}

/// A song as lists show it (see [SongRepository.watchSongList]).
@immutable
class SongListEntry {
  const SongListEntry({
    required this.id,
    required this.title,
    this.artist,
    this.songKey,
    this.tempo,
    this.sequence,
    this.tags,
    this.sortTitle,
    this.sortArtist,
    this.hasChords = true,
    this.problems = 0,
    this.conversions = 0,
    this.createdBy,
    this.updatedBy,
    this.language,
    this.languageByHand = false,
    this.workId,
  });

  final String id;
  final String title;
  final String? artist;
  final String? songKey;

  /// `{tempo}` in BPM.
  final int? tempo;

  /// Raw `{x_sequence}` value of the song.
  final String? sequence;

  /// As stored in the database (see `Songs.tags`).
  final String? tags;

  /// `{sorttitle}` / `{sortartist}`.
  final String? sortTitle;
  final String? sortArtist;

  /// The song has ChordPro text; false for songs with sheet music (PDF)
  /// only.
  final bool hasChords;

  /// Number of ChordPro problems (`validateChordPro`, #314).
  final int problems;

  /// Number of places the editor offers to convert
  /// (`countChordProConversions`, #798).
  final int conversions;

  /// Creator and last editor, for the edit permission of band leaders
  /// (ADR-0023).
  final String? createdBy;
  final String? updatedBy;

  /// Language of the song (ADR-0053): set by hand ([languageByHand]) or
  /// detected from the lyrics; null if neither.
  final String? language;
  final bool languageByHand;

  /// Group of the song's language versions (ADR-0053), or null.
  final String? workId;

  List<String> get tagList => _tags(tags);

  @override
  bool operator ==(Object other) =>
      other is SongListEntry &&
      other.id == id &&
      other.title == title &&
      other.artist == artist &&
      other.songKey == songKey &&
      other.tempo == tempo &&
      other.sequence == sequence &&
      other.tags == tags &&
      other.sortTitle == sortTitle &&
      other.sortArtist == sortArtist &&
      other.hasChords == hasChords &&
      other.problems == problems &&
      other.conversions == conversions &&
      other.createdBy == createdBy &&
      other.updatedBy == updatedBy &&
      other.language == language &&
      other.languageByHand == languageByHand &&
      other.workId == workId;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    songKey,
    tempo,
    sequence,
    tags,
    sortTitle,
    sortArtist,
    hasChords,
    problems,
    conversions,
    createdBy,
    updatedBy,
    language,
    languageByHand,
    workId,
  );
}

/// Access to songs, attachments and personal overlays of one song library:
/// an organization's library (ADR-0017), or the local library by default.
/// Lists and new songs use [libraryId]; operations on a single song use the
/// song's own library.
class SongRepository {
  SongRepository(
    this.db,
    this.storage, {
    this.libraryId = localBandId,
    this.userId,
  });

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Library whose songs are listed and to which new songs belong.
  final String libraryId;

  /// The signed-in user, or null.
  final String? userId;

  /// Whose personal adjustments of songs in [libraryId] are shown and
  /// changed (ADR-0020): the signed-in user for songs of an organization,
  /// the local owner for the local library (and without an account).
  String get overlayOwner => overlayOwnerFor(libraryId, userId);

  /// Library of the song [songId]; [libraryId] if it is unknown.
  Future<String> _libraryOf(String songId) async =>
      await (db.selectOnly(db.songs)
            ..addColumns([db.songs.libraryId])
            ..where(db.songs.id.equals(songId)))
          .map((r) => r.read(db.songs.libraryId)!)
          .getSingleOrNull() ??
      libraryId;

  /// Creator and last editor of a change in [library] (ADR-0023): the
  /// signed-in user for an organization's songs, as the server will record
  /// it; nobody for the local library.
  String? _editorIn(String library) => library == localBandId ? null : userId;

  /// Owner of the personal adjustments of [songId], by the song's library.
  Future<String> _overlayOwnerOf(String songId) async =>
      overlayOwnerFor(await _libraryOf(songId), userId);

  /// Songs sorted by `{sorttitle}` (or title); optionally filtered by a
  /// search [query] and [tags] (songs with any of them; all songs when
  /// empty).
  Stream<List<SongEntry>> watchSongs({
    String query = '',
    Set<String> tags = const {},
  }) =>
      (db.select(db.songs)
            ..where((_) => _filter(query, tags))
            ..orderBy([(_) => _order]))
          .watch();

  /// Like [watchSongs], with only what a list shows (without the ChordPro
  /// text, which can be long).
  Stream<List<SongListEntry>> watchSongList({
    String query = '',
    Set<String> tags = const {},
    SongSort sort = SongSort.title,
  }) {
    final s = db.songs;
    final hasChords = s.chordproSource.trim().length.isBiggerThanValue(0);
    final q = db.selectOnly(s)
      ..addColumns([
        s.id,
        s.title,
        s.artist,
        s.songKey,
        s.tempo,
        s.sequence,
        s.tags,
        s.sortTitle,
        s.sortArtist,
        hasChords,
        s.chordproProblems,
        s.chordproConversions,
        s.createdBy,
        s.updatedBy,
        s.language,
        s.detectedLanguage,
        s.workId,
      ])
      ..where(_filter(query, tags))
      // Title, artist and key are sorted in Dart (sortedFor).
      ..orderBy(switch (sort) {
        SongSort.recent => [OrderingTerm.desc(s.updatedAt), _order],
        _ => [_order],
      });
    return q.watch().map(
      (rows) => <SongListEntry>[
        for (final r in rows)
          SongListEntry(
            id: r.read(s.id)!,
            title: r.read(s.title)!,
            artist: r.read(s.artist),
            songKey: r.read(s.songKey),
            tempo: r.read(s.tempo),
            sequence: r.read(s.sequence),
            tags: r.read(s.tags),
            sortTitle: r.read(s.sortTitle),
            sortArtist: r.read(s.sortArtist),
            hasChords: r.read(hasChords) ?? true,
            problems: r.read(s.chordproProblems) ?? 0,
            conversions: r.read(s.chordproConversions) ?? 0,
            createdBy: r.read(s.createdBy),
            updatedBy: r.read(s.updatedBy),
            language: r.read(s.language) ?? r.read(s.detectedLanguage),
            languageByHand: r.read(s.language) != null,
            workId: r.read(s.workId),
          ),
      ].sortedFor(sort),
    );
  }

  OrderingTerm get _order => OrderingTerm.asc(
    coalesce([db.songs.sortTitle, db.songs.title]).collate(Collate.noCase),
  );

  Expression<bool> _filter(String query, Set<String> tags) {
    final s = db.songs;
    var filter = s.deleted.equals(false) & s.libraryId.equals(libraryId);
    if (tags.isNotEmpty) {
      // Songs with any of the tags (#816).
      filter =
          filter &
          Expression.or([
            for (final t in tags)
              s.tags.lower().like('%\n${t.toLowerCase()}\n%'),
          ]);
    }
    if (query.trim().isNotEmpty) {
      final match = songSearchMatch(query);
      // Full-text index (search.drift): words starting with the search
      // terms in title, artist or lyrics, without chords.
      filter =
          filter &
          (match == null
              ? const Constant(false)
              : CustomExpression<bool>(
                  'songs.rowid IN (SELECT rowid FROM songs_fts '
                  "WHERE songs_fts MATCH '${match.replaceAll("'", "''")}')",
                ));
    }
    return filter;
  }

  /// The hits of a search [query] (see [songSearchMatch]) by song, marked
  /// by the full-text index itself, so that they follow the same rules as
  /// the search (word starts, accents ignored).
  Stream<Map<String, SearchHit>> watchSearchHits(String query) {
    final match = songSearchMatch(query);
    if (match == null) return Stream.value(const {});
    const marks = "'$hitStart', '$hitEnd'";
    return db
        .customSelect(
          'SELECT s.id AS id, highlight(songs_fts, 0, $marks) AS title, '
          'highlight(songs_fts, 1, $marks) AS artist, '
          "snippet(songs_fts, 2, $marks, '…', 10) AS lyrics "
          'FROM songs_fts JOIN songs s ON s.rowid = songs_fts.rowid '
          'WHERE songs_fts MATCH ? AND s.library_id = ? AND s.deleted = 0',
          variables: [
            Variable.withString(match),
            Variable.withString(libraryId),
          ],
          readsFrom: {db.songs},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              r.read<String>('id'): (
                title: r.read<String>('title'),
                artist: r.readNullable<String>('artist'),
                lyrics: switch (r.readNullable<String>('lyrics')) {
                  final l? when l.contains(hitStart) => l.replaceAll(
                    RegExp(r'\s*\n\s*'),
                    ' / ',
                  ),
                  _ => null,
                },
              ),
          },
        );
  }

  Stream<SongEntry?> watchSong(String id) =>
      (db.select(db.songs)
            ..where((s) => s.id.equals(id) & s.deleted.equals(false)))
          .watchSingleOrNull();

  Future<SongEntry?> getSong(String id) => (db.select(
    db.songs,
  )..where((s) => s.id.equals(id) & s.deleted.equals(false))).getSingleOrNull();

  /// Creates a song. Title and artist from the source take precedence;
  /// [title]/[artist] are used for songs without ChordPro text (PDF only).
  Future<String> createSong({
    String source = '',
    String? title,
    String? artist,
  }) async {
    final meta = SongMeta.fromSource(source);
    final id = _uuid.v4();
    await _write(() async {
      await db
          .into(db.songs)
          .insert(
            SongsCompanion.insert(
              id: id,
              libraryId: libraryId,
              chordproSource: Value(source),
              title: meta.title ?? blankToNull(title) ?? '',
              artist: Value(meta.artist ?? blankToNull(artist)),
              songKey: Value(meta.key),
              sequence: Value(meta.sequence),
              tempo: Value(meta.tempo),
              sortTitle: Value(meta.sortTitle),
              sortArtist: Value(meta.sortArtist),
              tags: Value(meta.tagsColumn),
              searchText: Value(meta.searchText),
              chordproProblems: Value(meta.problems),
              chordproConversions: Value(meta.conversions),
              detectedLanguage: Value(meta.language),
              updatedAt: DateTime.now(),
              createdBy: Value(_editorIn(libraryId)),
              updatedBy: Value(_editorIn(libraryId)),
            ),
          );
      await markDirty(db, SyncCollection.songs, id, scope: libraryId);
    });
    return id;
  }

  /// Saves a new ChordPro source and refreshes the extracted metadata.
  Future<void> updateSource(String id, String source) async {
    final meta = SongMeta.fromSource(source);
    await _write(() async {
      final existing = await getSong(id);
      if (existing == null) return;
      await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          chordproSource: Value(source),
          title: Value(meta.title ?? existing.title),
          artist: Value(meta.artist ?? existing.artist),
          songKey: Value(meta.key),
          sequence: Value(meta.sequence),
          tempo: Value(meta.tempo),
          sortTitle: Value(meta.sortTitle),
          sortArtist: Value(meta.sortArtist),
          tags: Value(meta.tagsColumn),
          searchText: Value(meta.searchText),
          chordproProblems: Value(meta.problems),
          chordproConversions: Value(meta.conversions),
          detectedLanguage: Value(meta.language),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(_editorIn(existing.libraryId)),
        ),
      );
      await markDirty(db, SyncCollection.songs, id, scope: existing.libraryId);
    });
  }

  /// All tags used in the library, sorted.
  Stream<List<String>> watchTags() =>
      (db.selectOnly(db.songs)
            ..addColumns([db.songs.tags])
            ..where(
              db.songs.deleted.equals(false) &
                  db.songs.libraryId.equals(libraryId) &
                  db.songs.tags.isNotNull(),
            ))
          .watch()
          .map((rows) {
            // Tags are matched case-insensitively; show one spelling per
            // tag (the first in sort order, e.g. "Rock" before "rock").
            final byKey = <String, String>{};
            for (final r in rows) {
              for (final t in (r.read(db.songs.tags) ?? '').split('\n')) {
                if (t.isEmpty) continue;
                final key = t.toLowerCase();
                final known = byKey[key];
                if (known == null || t.compareTo(known) < 0) byKey[key] = t;
              }
            }
            return byKey.values.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          });

  /// The languages of the songs of [libraryId] (ADR-0053): set by hand or
  /// detected, and the empty string when a song has neither (#843).
  Stream<Set<String>> watchLanguages() {
    final s = db.songs;
    final language = coalesce([
      s.language,
      s.detectedLanguage,
      const Constant(''),
    ]);
    return (db.selectOnly(s, distinct: true)
          ..addColumns([language])
          ..where(s.deleted.equals(false) & s.libraryId.equals(libraryId)))
        .watch()
        .map((rows) => {for (final r in rows) r.read(language)!});
  }

  /// How many songs of [libraryId] that are not in the trash share each
  /// group of language versions (ADR-0053).
  Stream<Map<String, int>> watchWorkCounts() {
    final s = db.songs;
    final count = s.id.count();
    return (db.selectOnly(s)
          ..addColumns([s.workId, count])
          ..where(
            s.deleted.equals(false) &
                s.libraryId.equals(libraryId) &
                s.workId.isNotNull(),
          )
          ..groupBy([s.workId]))
        .watch()
        .map(
          (rows) => {for (final r in rows) r.read(s.workId)!: r.read(count)!},
        );
  }

  /// The language of [id] detected from its lyrics (ADR-0053), or null.
  Future<String?> detectedLanguage(String id) =>
      (db.selectOnly(db.songs)
            ..addColumns([db.songs.detectedLanguage])
            ..where(db.songs.id.equals(id)))
          .map((r) => r.read(db.songs.detectedLanguage))
          .getSingleOrNull();

  /// Recomputes the stored metadata of all songs from their ChordPro
  /// source (used after a database upgrade).
  Future<void> refreshAllMetadata() async {
    final all = [
      for (final song in await db.select(db.songs).get())
        if (song.chordproSource.trim().isNotEmpty) song,
    ];
    final metas = await songMetas([for (final s in all) s.chordproSource]);
    await db.transaction(() async {
      for (final (i, song) in all.indexed) {
        final meta = metas[i];
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(
            sortTitle: Value(meta.sortTitle),
            sortArtist: Value(meta.sortArtist),
            tags: Value(meta.tagsColumn),
            searchText: Value(meta.searchText),
            sequence: Value(meta.sequence),
            chordproProblems: Value(meta.problems),
            chordproConversions: Value(meta.conversions),
            detectedLanguage: Value(meta.language),
          ),
        );
      }
    });
  }

  /// Updates title and artist of a song without ChordPro metadata.
  Future<void> updateTitleArtist(String id, String title, String? artist) =>
      _write(() async {
        final existing = await getSong(id);
        if (existing == null) return;
        await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
          SongsCompanion(
            title: Value(title.trim()),
            artist: Value(blankToNull(artist)),
            updatedAt: Value(DateTime.now()),
            updatedBy: Value(_editorIn(existing.libraryId)),
          ),
        );
        await markDirty(
          db,
          SyncCollection.songs,
          id,
          scope: existing.libraryId,
        );
      });

  // Language versions (ADR-0053) ---------------------------------------------

  /// Links [a] and [b] as language versions of one work (ADR-0053): both get
  /// the same group ID, a new one if neither has one. Linking two groups
  /// moves the smaller one (on a tie the one of [b]) into the other. Both
  /// songs must be in the same library.
  ///
  /// Only songs [mayEdit] allows are moved (the server refuses the others,
  /// ADR-0023): if the preferred way would move another, the other group
  /// moves instead. Returns false, changing nothing, when neither way works.
  Future<bool> linkLanguageVersions(
    String a,
    String b, {
    bool Function(SongEntry song)? mayEdit,
  }) => _write(() async {
    if (a == b) return true;
    final songA = await getSong(a);
    final songB = await getSong(b);
    if (songA == null || songB == null) return false;
    if (songA.libraryId != songB.libraryId) {
      throw ArgumentError('Language versions belong to one library');
    }
    final library = songA.libraryId;
    final workA = songA.workId;
    final workB = songB.workId;
    if (workA != null && workA == workB) return true;
    Future<List<SongEntry>> group(SongEntry song) async =>
        song.workId == null ? [song] : await _workSongs(library, song.workId!);
    final groupA = await group(songA);
    final groupB = await group(songB);
    bool movable(List<SongEntry> songs) =>
        mayEdit == null || songs.every(mayEdit);
    // (target group ID, songs moved into it), in order of preference.
    final ways = <(String, List<SongEntry>)>[
      if (workA == null && workB == null)
        (_uuid.v4(), [songA, songB])
      else if (workA == null)
        (workB!, groupA)
      else if (workB == null)
        (workA, groupB)
      else if (groupB.length > groupA.length)
        (workB, groupA)
      else
        (workA, groupB),
      // The other way round.
      if (workB != null) (workB, groupA),
      if (workA != null) (workA, groupB),
    ];
    for (final (target, moved) in ways) {
      if (!movable(moved)) continue;
      for (final song in moved) {
        if (song.workId == target) continue;
        await _setLink(song.id, library, SongLinkField.workId, target);
      }
      return true;
    }
    return false;
  });

  /// Changes the language versions of [id] at once (ADR-0053, #851): takes
  /// the songs of [remove] out of its group, then links the songs of [add]
  /// to it as [linkLanguageVersions] does, with [mayEdit].
  ///
  /// Returns the songs of [add] that could not be linked and the group ID
  /// every touched song had before, for [setWorkId] to undo the change.
  Future<({List<String> notLinked, Map<String, String?> before})>
  updateLanguageVersions(
    String id, {
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
    bool Function(SongEntry song)? mayEdit,
  }) async {
    final before = <String, String?>{};
    Future<void> remember(String songId) async {
      final song = await getSong(songId);
      if (song == null) return;
      final group = song.workId == null
          ? [song]
          : await _workSongs(song.libraryId, song.workId!);
      for (final s in group) {
        before.putIfAbsent(s.id, () => s.workId);
      }
    }

    for (final s in [id, ...add, ...remove]) {
      await remember(s);
    }
    for (final s in remove) {
      if (s == id) continue;
      final song = await getSong(s);
      if (song == null || (mayEdit != null && !mayEdit(song))) continue;
      await unlinkLanguageVersion(s);
    }
    final notLinked = <String>[];
    for (final s in add) {
      if (!await linkLanguageVersions(id, s, mayEdit: mayEdit)) {
        notLinked.add(s);
      }
    }
    return (notLinked: notLinked, before: before);
  }

  /// Puts [id] into the group [work] again, e.g. to undo
  /// [unlinkLanguageVersion] (ADR-0053).
  Future<void> setWorkId(String id, String? work) => _write(() async {
    final song = await getSong(id);
    if (song == null || song.workId == work) return;
    await _setLink(id, song.libraryId, SongLinkField.workId, work);
  });

  /// The language versions of the work of [id] that are not in the trash,
  /// including [id] itself; empty while it has no group (ADR-0053).
  Stream<List<SongEntry>> watchLanguageVersions(String id) => db
      .customSelect(
        'SELECT o.* FROM songs s JOIN songs o '
        'ON o.work_id = s.work_id AND o.library_id = s.library_id '
        'WHERE s.id = ? AND o.deleted = 0 ORDER BY o.title',
        variables: [Variable.withString(id)],
        readsFrom: {db.songs},
      )
      .watch()
      .map((rows) => [for (final r in rows) db.songs.map(r.data)]);

  /// Songs of [library] in the group [work], also those in the trash:
  /// restored, they are linked again.
  Future<List<SongEntry>> _workSongs(String library, String work) => (db.select(
    db.songs,
  )..where((s) => s.libraryId.equals(library) & s.workId.equals(work))).get();

  /// Removes [id] from its group of language versions (ADR-0053). A version
  /// left alone keeps the group ID; it shows no other versions.
  Future<void> unlinkLanguageVersion(String id) => _write(() async {
    final song = await getSong(id);
    if (song == null || song.workId == null) return;
    await _setLink(id, song.libraryId, SongLinkField.workId, null);
  });

  /// Sets the language of [id] by hand (ADR-0053): a code of
  /// [songLanguages], or null for the detected one.
  Future<void> setLanguage(String id, String? language) => _write(() async {
    if (language != null && !songLanguages.contains(language)) {
      throw ArgumentError.value(language, 'language');
    }
    final song = await getSong(id);
    if (song == null || song.language == language) return;
    await _setLink(id, song.libraryId, SongLinkField.language, language);
  });

  /// The other language versions of [id] (ADR-0053) that are not in the
  /// trash, by title.
  Future<List<SongEntry>> languageVersions(String id) async {
    final song = await getSong(id);
    final work = song?.workId;
    if (song == null || work == null) return const [];
    return (db.select(db.songs)
          ..where(
            (s) =>
                s.libraryId.equals(song.libraryId) &
                s.workId.equals(work) &
                s.id.equals(id).not() &
                s.deleted.equals(false),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.title)]))
        .get();
  }

  /// Writes a link field and queues it for the sync on its own, last
  /// writer wins (ADR-0053). The last editor stays, as on the server.
  Future<void> _setLink(
    String id,
    String library,
    SongLinkField field,
    String? value,
  ) async {
    await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
      switch (field) {
        SongLinkField.workId => SongsCompanion(workId: Value(value)),
        SongLinkField.language => SongsCompanion(language: Value(value)),
      },
    );
    await markDirty(
      db,
      SyncCollection.songLinks,
      songLinkRecordId(id, field.serverName),
      scope: library,
    );
  }

  /// Soft-deletes a song with its attachments and removes it from all
  /// sets. The attachment files are kept for an undo ([restoreSong]) until
  /// [purgeFiles].
  Future<DeletedSong> deleteSong(String id) => _write(() async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final files = await (db.select(
      db.attachments,
    )..where((a) => a.songId.equals(id) & a.deleted.equals(false))).get();
    final setIds =
        await (db.selectOnly(db.setItems)
              ..addColumns([db.setItems.setId])
              ..where(db.setItems.songId.equals(id)))
            .map((r) => r.read(db.setItems.setId)!)
            .get();
    final items = await itemsToRemove(db, setIds, (i) => i.songId == id);
    // Sets that lose the song are changed, too.
    final sets = await (db.select(
      db.setlists,
    )..where((s) => s.id.isIn(setIds))).get();
    // One time for the song and its attachments: restoring the song from
    // the trash brings back the attachments deleted with it (ADR-0043).
    final now = DateTime.now();
    await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(
        deleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await (db.update(
      db.attachments,
    )..where((a) => a.songId.equals(id) & a.deleted.equals(false))).write(
      AttachmentsCompanion(deleted: const Value(true), deletedAt: Value(now)),
    );
    await (db.delete(db.setItems)..where((i) => i.songId.equals(id))).go();
    if (song != null) {
      await markDirty(db, SyncCollection.songs, id, scope: song.libraryId);
    }
    for (final set in sets) {
      await markDirty(db, SyncCollection.setlists, set.id, scope: set.bandId);
    }
    return DeletedSong(id, attachments: files, setItems: items);
  });

  /// Undoes [deleteSong]: the song, its attachments and its set items are
  /// back, as a new local change that is synced like an edit (#267).
  Future<void> restoreSong(DeletedSong deleted) => _write(() async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(deleted.songId))).getSingleOrNull();
    if (song == null) return;
    await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
      SongsCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (db.update(
          db.attachments,
        )..where((a) => a.id.isIn([for (final a in deleted.attachments) a.id])))
        .write(
          const AttachmentsCompanion(
            deleted: Value(false),
            deletedAt: Value(null),
          ),
        );
    await markDirty(db, SyncCollection.songs, song.id, scope: song.libraryId);
    for (final set in await restoreSetItems(db, deleted.setItems)) {
      await markDirty(db, SyncCollection.setlists, set.id, scope: set.bandId);
    }
  });

  /// Deletes the files of [attachments] that are still deleted (also by
  /// their song) once an undo is no longer possible.
  Future<void> purgeFiles(Iterable<AttachmentEntry> attachments) async {
    final ids = [for (final a in attachments) a.id];
    if (ids.isEmpty) return;
    final live = await _liveFileNames();
    final rows = await _attachmentsWithSong(db.attachments.id.isIn(ids));
    for (final (a, song) in rows) {
      // Deleted songs of the local library keep their files for the trash
      // (ADR-0043, TrashRepository.purgeLocal); synced files are downloaded
      // again after a restore.
      if (song.deleted && song.libraryId == localBandId) continue;
      if ((a.deleted || song.deleted) && !live.contains(a.fileName)) {
        await storage.delete(a.fileName);
      }
    }
  }

  /// Deletes the files of all deleted attachments and of the attachments of
  /// deleted songs, e.g. left behind when the app was closed while an undo
  /// was offered. Run at start.
  Future<void> purgeDeletedFiles() async {
    final live = await _liveFileNames();
    final rows = await _attachmentsWithSong(
      (db.attachments.deleted.equals(true) | db.songs.deleted.equals(true)) &
          (db.songs.deleted.equals(true) &
                  db.songs.libraryId.equals(localBandId))
              .not(),
    );
    for (final (a, _) in rows) {
      if (!live.contains(a.fileName) && await storage.exists(a.fileName)) {
        await storage.delete(a.fileName);
      }
    }
  }

  /// Attachments matching [filter] with their song.
  Future<List<(AttachmentEntry, SongEntry)>> _attachmentsWithSong(
    Expression<bool> filter,
  ) async =>
      (await (db.select(db.attachments).join([
            innerJoin(db.songs, db.songs.id.equalsExp(db.attachments.songId)),
          ])..where(filter)).get())
          .map((r) => (r.readTable(db.attachments), r.readTable(db.songs)))
          .toList();

  /// File names of attachments in use (not deleted, song not deleted).
  Future<Set<String>> _liveFileNames() async => {
    for (final (a, _) in await _attachmentsWithSong(
      db.attachments.deleted.equals(false) & db.songs.deleted.equals(false),
    ))
      a.fileName,
  };

  // Attachments -------------------------------------------------------------

  Stream<List<AttachmentEntry>> watchAttachments(String songId) =>
      (db.select(db.attachments)
            ..where((a) => a.songId.equals(songId) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<List<AttachmentEntry>> getAttachments(String songId) =>
      (db.select(db.attachments)
            ..where((a) => a.songId.equals(songId) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  /// Number of attachments per song ID.
  Stream<Map<String, int>> watchAttachmentCounts() {
    final count = db.attachments.id.count();
    final q = db.selectOnly(db.attachments)
      ..addColumns([db.attachments.songId, count])
      ..where(db.attachments.deleted.equals(false))
      ..groupBy([db.attachments.songId]);
    return q.watch().map(
      (rows) => {
        for (final r in rows) r.read(db.attachments.songId)!: r.read(count)!,
      },
    );
  }

  /// Adds a PDF or image attachment ([extension] without dot). Throws
  /// [AttachmentTooLargeException] above 20 MB.
  Future<String> addAttachment(
    String songId, {
    required String name,
    required Uint8List bytes,
    int? pages,
    String extension = 'pdf',
  }) async {
    if (bytes.length > maxAttachmentBytes) {
      throw AttachmentTooLargeException(bytes.length);
    }
    final id = _uuid.v4();
    final ext = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final fileName = '$id.${ext.isEmpty ? 'bin' : ext}';
    await storage.write(fileName, bytes);
    try {
      await _write(() async {
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: id,
                songId: songId,
                name: name,
                fileName: fileName,
                pages: Value(pages),
                sizeBytes: bytes.length,
                updatedAt: DateTime.now(),
              ),
            );
        await _markAttachment(id, songId, fileName);
      });
    } catch (_) {
      // Not stored: the file would be an orphan.
      await storage.delete(fileName);
      rethrow;
    }
    return id;
  }

  /// Only PDF attachments are synced (ADR-0009); images stay on the device.
  Future<void> _markAttachment(
    String id,
    String songId,
    String fileName,
  ) async {
    if (!isPdfFile(fileName)) return;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null) return;
    await markDirty(db, SyncCollection.attachments, id, scope: song.libraryId);
  }

  Future<void> renameAttachment(String id, String name) => _write(() async {
    await (db.update(db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
    final a = await (db.select(
      db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (a != null) await _markAttachment(a.id, a.songId, a.fileName);
  });

  /// Soft-deletes an attachment; its file is kept for an undo
  /// ([restoreAttachment]) until [purgeFiles].
  Future<DeletedAttachment> deleteAttachment(AttachmentEntry attachment) =>
      _write(() async {
        final owners =
            await (db.selectOnly(db.personalOverlays)
                  ..addColumns([db.personalOverlays.ownerId])
                  ..where(db.personalOverlays.liveView.equals(attachment.id)))
                .map((r) => r.read(db.personalOverlays.ownerId)!)
                .get();
        await (db.update(
          db.attachments,
        )..where((a) => a.id.equals(attachment.id))).write(
          AttachmentsCompanion(
            deleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
        await _markAttachment(
          attachment.id,
          attachment.songId,
          attachment.fileName,
        );
        await (db.update(db.personalOverlays)
              ..where((o) => o.liveView.equals(attachment.id)))
            .write(const PersonalOverlaysCompanion(liveView: Value(null)));
        return DeletedAttachment(attachment, liveViewOwners: owners);
      });

  /// Undoes [deleteAttachment], including the live view of personal
  /// adjustments that showed it (unless changed since).
  Future<void> restoreAttachment(DeletedAttachment deleted) => _write(() async {
    final a = deleted.attachment;
    await (db.update(db.attachments)..where((x) => x.id.equals(a.id))).write(
      AttachmentsCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _markAttachment(a.id, a.songId, a.fileName);
    await (db.update(db.personalOverlays)..where(
          (o) =>
              o.songId.equals(a.songId) &
              o.ownerId.isIn(deleted.liveViewOwners) &
              o.liveView.isNull(),
        ))
        .write(PersonalOverlaysCompanion(liveView: Value(a.id)));
  });

  /// Runs a change together with its outbox entries ([markDirty]) in one
  /// transaction, so that no change is stored without being synced.
  Future<T> _write<T>(Future<T> Function() change) => db.transaction(change);

  // Personal overlays --------------------------------------------------------

  SimpleSelectStatement<$PersonalOverlaysTable, SongOverlay> _overlay(
    String owner,
    String songId,
  ) =>
      db.select(db.personalOverlays)
        ..where((o) => o.ownerId.equals(owner) & o.songId.equals(songId));

  Stream<SongOverlay> watchOverlay(String songId) =>
      Stream.fromFuture(_overlayOwnerOf(songId)).asyncExpand(
        (owner) => _overlay(owner, songId).watchSingleOrNull().map(
          (o) => o ?? defaultOverlay(songId, ownerId: owner),
        ),
      );

  Future<SongOverlay> getOverlay(String songId) async {
    final owner = await _overlayOwnerOf(songId);
    return await _overlay(owner, songId).getSingleOrNull() ??
        defaultOverlay(songId, ownerId: owner);
  }

  /// Changes the personal adjustments of a song (song screen, set view).
  Future<void> updateOverlay(
    String songId,
    SongOverlay Function(SongOverlay) change,
  ) async => saveOverlay(change(await getOverlay(songId)));

  /// The keyboard programs of [overlay] per device profile (ADR-0042).
  /// While none were written, a v0.16.0 program in `midi` (ADR-0039)
  /// counts for [deviceProfile], the profile of this device.
  static MidiPrograms midiProgramsOf(
    SongOverlay overlay,
    String deviceProfile,
  ) =>
      overlay.midiPrograms ??
      switch (overlay.midi) {
        final legacy? => MidiPrograms({deviceProfile: legacy}),
        null => const MidiPrograms(),
      };

  /// The keyboard program of a song for [profile], the profile of this
  /// device (ADR-0039, ADR-0042), part of the personal adjustments; null =
  /// none, live mode sends nothing.
  Future<MidiProgram?> midiProgram(String songId, String profile) async =>
      midiProgramsOf(await getOverlay(songId), profile)[profile];

  /// The keyboard programs of a song per profile, as they change (e.g.
  /// after a sync); [deviceProfile] as in [midiProgramsOf].
  Stream<MidiPrograms> watchMidiPrograms(String songId, String deviceProfile) =>
      watchOverlay(songId)
          .map((o) => midiProgramsOf(o, deviceProfile))
          .distinct();

  /// Stores the keyboard program of a song for [profile]; null removes it.
  /// The first change moves a v0.16.0 program to [deviceProfile] (the
  /// profile of this device); `midi` itself stays for older clients.
  /// Synced with the other personal adjustments (last writer wins,
  /// ADR-0020).
  Future<void> setMidiProgram(
    String songId,
    String profile,
    MidiProgram? program, {
    required String deviceProfile,
  }) => updateOverlay(
    songId,
    (o) => o.copyWith(
      midiPrograms: Value(
        midiProgramsOf(o, deviceProfile).withProgram(profile, program),
      ),
    ),
  );

  /// Puts back the keyboard programs of a song as [stored] in the overlay
  /// before a change, null included (never written: a v0.16.0 program
  /// counts again), to undo a change in live mode (#607).
  Future<void> restoreMidiPrograms(String songId, MidiPrograms? stored) =>
      updateOverlay(songId, (o) => o.copyWith(midiPrograms: Value(stored)));

  /// Removes the keyboard program of a song for [profile].
  Future<void> removeMidiProgram(
    String songId,
    String profile, {
    required String deviceProfile,
  }) => setMidiProgram(songId, profile, null, deviceProfile: deviceProfile);

  /// Whether [overlay] has musical adjustments (ADR-0053): a transposition,
  /// a capo, keyboard programs or the click. Notes, the font size, the
  /// display and annotations are not musical; they are never copied.
  static bool hasMusicalAdjustments(SongOverlay overlay) =>
      overlay.transpose != 0 ||
      overlay.capoFret != null ||
      !(overlay.midiPrograms?.isEmpty ?? overlay.midi == null) ||
      overlay.clickGrouping != null ||
      overlay.clickSubdivision != null;

  /// The other language versions of [songId] whose personal adjustments
  /// are musical (ADR-0053), with them, by title.
  Future<List<(SongEntry, SongOverlay)>> musicalAdjustmentSources(
    String songId,
  ) async => [
    for (final version in await languageVersions(songId))
      if (await getOverlay(version.id) case final o
          when hasMusicalAdjustments(o))
        (version, o),
  ];

  /// Copies the musical adjustments of [from] to [to] (ADR-0053), replacing
  /// those of [to]; the rest of [to]'s adjustments stays. Returns what [to]
  /// had before, for an undo with [saveOverlay].
  Future<SongOverlay> copyMusicalAdjustments({
    required String from,
    required String to,
  }) => _write(() async {
    final source = await getOverlay(from);
    final before = await getOverlay(to);
    await saveOverlay(
      before.copyWith(
        transpose: source.transpose,
        capoFret: Value(source.capoFret),
        midi: Value(source.midi),
        midiPrograms: Value(source.midiPrograms),
        clickGrouping: Value(source.clickGrouping),
        clickSubdivision: Value(source.clickSubdivision),
      ),
    );
    return before;
  });

  /// No adjustments: as written in the song.
  static SongOverlay defaultOverlay(
    String songId, {
    String ownerId = localOwnerId,
  }) => SongOverlay(
    ownerId: ownerId,
    songId: songId,
    transpose: 0,
    capo: 0,
    fontScale: 1.0,
    revision: 0,
    hideAnnotations: false,
    verseChords: VerseChords.all,
  );

  /// Saves all fields, including null values (e.g. resetting Nashville to
  /// the device setting or removing a note), always for the owner the
  /// song's library calls for; adjustments of organization songs are synced
  /// with the account (ADR-0020).
  Future<void> saveOverlay(SongOverlay overlay) => _write(() async {
    final library = await _libraryOf(overlay.songId);
    final owner = overlayOwnerFor(library, userId);
    await db
        .into(db.personalOverlays)
        .insertOnConflictUpdate(
          overlay
              .copyWith(ownerId: owner)
              .toCompanion(false)
              // The server revision is kept as stored.
              .copyWith(revision: const Value.absent()),
        );
    if (owner != localOwnerId) {
      await markDirty(
        db,
        SyncCollection.overlays,
        overlayRecordId(owner, overlay.songId),
        scope: library,
      );
    }
  });
}

/// Position of a song's key in the list sorted by key: C to B, major before
/// minor; songs without a (readable) key last.
int songKeyRank(String? key) {
  final parsed = key == null ? null : cp.Key.tryParse(key);
  return parsed == null ? 24 : parsed.tonic.pitch * 2 + (parsed.minor ? 1 : 0);
}

extension on List<SongListEntry> {
  /// Sorted for [sort] without regard to case and accents (SQLite's NOCASE
  /// only folds ASCII); [SongSort.recent] keeps the database order.
  List<SongListEntry> sortedFor(SongSort sort) {
    if (sort == SongSort.recent) return this;
    final keys = [
      for (final s in this)
        (
          rank: switch (sort) {
            SongSort.key => songKeyRank(s.songKey),
            SongSort.artist => s.artist == null ? 1 : 0,
            _ => 0,
          },
          artist: sort == SongSort.artist
              ? foldForSort(s.sortArtist ?? s.artist ?? '')
              : '',
          title: foldForSort(s.sortTitle ?? s.title),
        ),
    ];
    final order = [for (var i = 0; i < length; i++) i]
      ..sort((a, b) {
        final x = keys[a], y = keys[b];
        var c = x.rank.compareTo(y.rank);
        if (c == 0) c = x.artist.compareTo(y.artist);
        if (c == 0) c = x.title.compareTo(y.title);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final i in order) this[i]];
  }
}
