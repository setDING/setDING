import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'deletions.dart';
import 'outbox.dart';
import 'play_history.dart';
import 'text.dart';

const _uuid = Uuid();

/// A set item together with its song (if any).
class SetItemView {
  const SetItemView(this.item, this.song);

  final SetItemEntry item;
  final SongEntry? song;
}

/// The next set a song is played in (see [SetRepository.watchUpcomingGigs]).
typedef UpcomingGig = ({String setName, DateTime date});

/// Whether [userId] plays [set] (ADR-0061): with a lineup of its own, when
/// they are in it; otherwise the whole band plays it, so when they are a
/// [bandMember]. Without a signed-in user (the local library) every set.
bool plannedFor(
  SetlistEntry set, {
  required String? userId,
  bool bandMember = true,
}) {
  if (userId == null) return true;
  return set.lineupCustom ? set.lineup.contains(userId) : bandMember;
}

/// An upcoming set the user plays as a substitute (ADR-0061), with its
/// band.
typedef SubstituteGig = ({SetlistEntry set, String bandId, String bandName});

/// The set [id] on this device, in any band and deleted ones too: a link
/// opens it whichever band it is in (ADR-0065 §3).
Stream<SetlistEntry?> watchAnySet(AppDatabase db, String id) =>
    (db.select(db.setlists)..where((s) => s.id.equals(id))).watchSingleOrNull();

/// How many sets of [bandId] are not in the trash.
Future<int> countBandSets(AppDatabase db, String bandId) {
  final count = db.setlists.id.count();
  return (db.selectOnly(db.setlists)
        ..addColumns([count])
        ..where(
          db.setlists.bandId.equals(bandId) & db.setlists.deleted.equals(false),
        ))
      .map((r) => r.read(count) ?? 0)
      .getSingle();
}

/// The sets with a gig date from [today] on in the bands the user sees only
/// as a substitute (ADR-0061), next gig first: on this device these are
/// exactly the sets whose lineup has the user.
Stream<List<SubstituteGig>> watchSubstituteGigs(
  AppDatabase db, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final l = db.setlists, b = db.bands;
  final q = db.select(l).join([innerJoin(b, b.id.equalsExp(l.bandId))])
    ..where(
      b.substitute.equals(true) &
          b.deleted.equals(false) &
          l.deleted.equals(false) &
          l.gigDate.isBiggerOrEqualValue(start),
    )
    ..orderBy([OrderingTerm.asc(l.gigDate), OrderingTerm.asc(l.name)]);
  return q.watch().map(
    (rows) => [
      for (final row in rows)
        (
          set: row.readTable(l),
          bandId: row.readTable(b).id,
          bandName: row.readTable(b).name,
        ),
    ],
  );
}

/// The sets with a gig date from [today] on and a lineup of their own that
/// has [userId] (ADR-0061), in every band of this device, next gig first:
/// the gigs the user was planned for by name.
Stream<List<SubstituteGig>> watchPlannedGigs(
  AppDatabase db,
  String userId, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final l = db.setlists, b = db.bands;
  final q = db.select(l).join([innerJoin(b, b.id.equalsExp(l.bandId))])
    ..where(
      b.deleted.equals(false) &
          l.deleted.equals(false) &
          l.lineupCustom.equals(true) &
          l.gigDate.isBiggerOrEqualValue(start),
    )
    ..orderBy([OrderingTerm.asc(l.gigDate), OrderingTerm.asc(l.name)]);
  return q.watch().map(
    (rows) => [
      for (final row in rows)
        if (row.readTable(l).lineup.contains(userId))
          (
            set: row.readTable(l),
            bandId: row.readTable(b).id,
            bandName: row.readTable(b).name,
          ),
    ],
  );
}

/// Summary of a set for list views.
class SetSummary {
  const SetSummary(this.set, this.itemCount);

  final SetlistEntry set;
  final int itemCount;
}

/// The sets of the sets tab by gig date (#265): [upcoming] from [today] on,
/// next gig first; [undated] by name; [past] most recent first.
typedef SetGroups = ({
  List<SetSummary> upcoming,
  List<SetSummary> undated,
  List<SetSummary> past,
});

/// Groups [sets] into upcoming, undated and past sets. A gig on [today]
/// counts as upcoming, as for the song list's upcoming-gig icon
/// ([SetRepository.watchUpcomingGigs]).
SetGroups groupSets(List<SetSummary> sets, DateTime today) {
  final start = DateTime(today.year, today.month, today.day);
  int byName(SetSummary a, SetSummary b) =>
      a.set.name.toLowerCase().compareTo(b.set.name.toLowerCase());
  final upcoming = <SetSummary>[], undated = <SetSummary>[];
  final past = <SetSummary>[];
  for (final s in sets) {
    final date = s.set.gigDate;
    (date == null
            ? undated
            : date.isBefore(start)
            ? past
            : upcoming)
        .add(s);
  }
  upcoming.sort((a, b) {
    final c = a.set.gigDate!.compareTo(b.set.gigDate!);
    return c != 0 ? c : byName(a, b);
  });
  past.sort((a, b) {
    final c = b.set.gigDate!.compareTo(a.set.gigDate!);
    return c != 0 ? c : byName(a, b);
  });
  undated.sort(byName);
  return (upcoming: upcoming, undated: undated, past: past);
}

/// Access to sets (setlists) and their items of one band (the current
/// band, or the local library by default).
class SetRepository {
  SetRepository(
    this.db,
    this.storage, {
    this.bandId = localBandId,
    this.userId,
    this.bandMember = true,
  });

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Band whose sets are listed and to which new sets belong.
  final String bandId;

  /// The signed-in user, or null.
  final String? userId;

  /// The signed-in user is a member of the band; false for an organization
  /// admin outside it and for a substitute (ADR-0061).
  final bool bandMember;

  /// Whether the signed-in user plays [set] (ADR-0061, [plannedFor]).
  bool isPlanned(SetlistEntry set) =>
      plannedFor(set, userId: userId, bandMember: bandMember);

  /// Last editor of a change of a set of [band] (ADR-0045): the signed-in
  /// user for a band's sets, as the server will record it; nobody for the
  /// local band.
  String? _editorIn(String band) => band == localBandId ? null : userId;

  /// For each song in a set of the band with a gig date on [today] or
  /// later that the user plays ([isPlanned], ADR-0061): the first of these
  /// sets (by date).
  Stream<Map<String, UpcomingGig>> watchUpcomingGigs({DateTime? today}) {
    final now = today ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final l = db.setlists, i = db.setItems;
    final q = db.select(i).join([innerJoin(l, l.id.equalsExp(i.setId))])
      ..where(
        l.bandId.equals(bandId) &
            l.deleted.equals(false) &
            l.gigDate.isBiggerOrEqualValue(start) &
            i.songId.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(l.gigDate), OrderingTerm.asc(l.name)]);
    return q.watch().map((rows) {
      final gigs = <String, UpcomingGig>{};
      for (final row in rows) {
        final set = row.readTable(l);
        if (!isPlanned(set)) continue;
        gigs.putIfAbsent(
          row.readTable(i).songId!,
          () => (setName: set.name, date: set.gigDate!),
        );
      }
      return gigs;
    });
  }

  Stream<List<SetSummary>> watchSets() {
    final count = db.setItems.id.count();
    final q =
        db.select(db.setlists).join([
            leftOuterJoin(
              db.setItems,
              db.setItems.setId.equalsExp(db.setlists.id),
              useColumns: false,
            ),
          ])
          ..addColumns([count])
          ..where(
            db.setlists.deleted.equals(false) &
                db.setlists.bandId.equals(bandId),
          )
          ..groupBy([db.setlists.id])
          ..orderBy([
            OrderingTerm(
              expression: db.setlists.gigDate,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.asc(db.setlists.name.collate(Collate.noCase)),
          ]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          SetSummary(r.readTable(db.setlists), r.read(count) ?? 0),
      ],
    );
  }

  Future<SetlistEntry?> getSet(String id) =>
      (db.select(db.setlists)..where((s) => s.id.equals(id))).getSingleOrNull();

  Stream<SetlistEntry?> watchSet(String id) =>
      (db.select(db.setlists)
            ..where((s) => s.id.equals(id) & s.deleted.equals(false)))
          .watchSingleOrNull();

  /// Creates a set; [origin] is the set an imported one was made from
  /// (ADR-0043 §1b). [id]: kept when the local library is restored
  /// (ADR-0054); default a new one.
  Future<String> createSet({
    required String name,
    DateTime? gigDate,
    String? venue,
    String? origin,
    String? id,
  }) async {
    final newId = id ?? _uuid.v4();
    await db.transaction(() async {
      await db
          .into(db.setlists)
          .insert(
            SetlistsCompanion.insert(
              id: newId,
              bandId: bandId,
              name: name.trim(),
              gigDate: Value(gigDate),
              venue: Value(blankToNull(venue)),
              origin: Value(origin),
              updatedAt: DateTime.now(),
              updatedBy: Value(_editorIn(bandId)),
            ),
          );
      await markDirty(db, SyncCollection.setlists, newId, scope: bandId);
    });
    return newId;
  }

  Future<void> updateSet(
    String id, {
    required String name,
    DateTime? gigDate,
    String? venue,
  }) => db.transaction(() async {
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        name: Value(name.trim()),
        gigDate: Value(gigDate),
        venue: Value(blankToNull(venue)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _touch(id);
  });

  /// Sets the people who play the set (ADR-0061): user IDs of the band and
  /// its organization and the IDs of [contacts], people without an account
  /// (ADR-0064), or null for the whole band. Synced like an edit; the
  /// server refuses people and contacts outside the organization.
  Future<void> setLineup(
    String id,
    List<String>? people, {
    List<String> contacts = const [],
  }) => db.transaction(() async {
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        lineup: Value(people == null ? const [] : people.toSet().toList()),
        lineupContacts: Value(
          people == null ? const [] : contacts.toSet().toList(),
        ),
        lineupCustom: Value(people != null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _touch(id);
  });

  /// Soft-deletes a set; [restoreSet] undoes it. The set keeps its items,
  /// so it is complete when it is restored from the trash (ADR-0043).
  Future<DeletedSet> deleteSet(String id) => db.transaction(() async {
    final items = await itemsToRemove(db, [id], (_) => true);
    final now = DateTime.now();
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        deleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _touch(id);
    return DeletedSet(id, items: items);
  });

  /// Undoes [deleteSet] with its items, as a new change that is synced like
  /// an edit (#267).
  Future<void> restoreSet(DeletedSet deleted) => db.transaction(() async {
    await (db.update(
      db.setlists,
    )..where((s) => s.id.equals(deleted.setId))).write(
      const SetlistsCompanion(deleted: Value(false), deletedAt: Value(null)),
    );
    await restoreSetItems(db, deleted.items);
    await _touch(deleted.setId);
  });

  Stream<List<SetItemView>> watchItems(String setId) =>
      _itemsQuery(setId).watch().map((rows) => rows.map(_toView).toList());

  Future<List<SetItemView>> getItems(String setId) async =>
      (await _itemsQuery(setId).get()).map(_toView).toList();

  JoinedSelectStatement<HasResultSet, dynamic> _itemsQuery(String setId) =>
      db.select(db.setItems).join([
          leftOuterJoin(db.songs, db.songs.id.equalsExp(db.setItems.songId)),
        ])
        ..where(db.setItems.setId.equals(setId))
        ..orderBy([OrderingTerm.asc(db.setItems.position)]);

  SetItemView _toView(TypedResult r) {
    final song = r.readTableOrNull(db.songs);
    return SetItemView(
      r.readTable(db.setItems),
      song == null || song.deleted ? null : song,
    );
  }

  Future<int> _nextPosition(String setId) async {
    final max = db.setItems.position.max();
    final row =
        await (db.selectOnly(db.setItems)
              ..addColumns([max])
              ..where(db.setItems.setId.equals(setId)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<void> addSongs(String setId, List<String> songIds) =>
      db.transaction(() async {
        var position = await _nextPosition(setId);
        final ids = <String>[];
        for (final songId in songIds) {
          final id = _uuid.v4();
          ids.add(id);
          await db
              .into(db.setItems)
              .insert(
                SetItemsCompanion.insert(
                  id: id,
                  setId: setId,
                  songId: Value(songId),
                  position: position++,
                  type: SetItemType.song,
                ),
              );
        }
        // A song added to a set whose gig day has come was played as it
        // is now (ADR-0046).
        await PlayHistoryRepository(db).refreshItems(ids);
        await _touch(setId);
      });

  /// Adds a marker (break, announcement, encore, …, ADR-0047) with the
  /// catalogue [icon] and [label] (empty: the icon's name shows).
  Future<void> addMarker(String setId, String icon, String label) =>
      db.transaction(() async {
        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                id: _uuid.v4(),
                setId: setId,
                position: await _nextPosition(setId),
                type: SetItemType.marker,
                icon: Value(icon),
                note: Value(label.trim()),
              ),
            );
        await _touch(setId);
      });

  /// Changes the text of a marker and, if given, its [icon].
  Future<void> updateMarker(String itemId, String label, {String? icon}) =>
      db.transaction(() async {
        await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
          SetItemsCompanion(
            note: Value(label.trim()),
            icon: icon == null ? const Value.absent() : Value(icon),
          ),
        );
        await _touchItem(itemId);
      });

  /// Removes an item from a set and returns it for [restoreItem].
  Future<SetItemEntry?> removeItem(String setId, String itemId) =>
      db.transaction(() async {
        final removed = (await itemsToRemove(db, [
          setId,
        ], (i) => i.id == itemId)).firstOrNull;
        await (db.delete(db.setItems)..where((i) => i.id.equals(itemId))).go();
        final items = await getItems(setId);
        await _writePositions([for (final v in items) v.item.id]);
        await _touch(setId);
        return removed;
      });

  /// Puts a [removed] item back at its position (#267).
  Future<void> restoreItem(SetItemEntry removed) => db.transaction(() async {
    if ((await restoreSetItems(db, [removed])).isNotEmpty) {
      await _touch(removed.setId);
    }
  });

  /// Stores the order of [itemIds] as positions 0..n-1.
  Future<void> reorder(String setId, List<String> itemIds) =>
      db.transaction(() async {
        await _writePositions(itemIds);
        await _touch(setId);
      });

  Future<void> _writePositions(List<String> itemIds) async {
    for (var i = 0; i < itemIds.length; i++) {
      await (db.update(db.setItems)..where((it) => it.id.equals(itemIds[i])))
          .write(SetItemsCompanion(position: Value(i)));
    }
  }

  Future<void> setItemTranspose(String itemId, int transpose) =>
      db.transaction(() async {
        await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
          SetItemsCompanion(transpose: Value(transpose)),
        );
        await PlayHistoryRepository(db).refreshItems([itemId]);
        await _touchItem(itemId);
      });

  /// Puts another language version [songId] of its song into the set item
  /// [itemId] (ADR-0053): the transposition stays (relative to the band's
  /// key of the new version, ADR-0025), the set item's own sequence stays
  /// only with [keepSequence] (see [sequenceFits]).
  Future<void> switchItemSong(
    String itemId,
    String songId, {
    required bool keepSequence,
  }) => db.transaction(() async {
    await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
      SetItemsCompanion(
        songId: Value(songId),
        sequence: keepSequence ? const Value.absent() : const Value(null),
      ),
    );
    await PlayHistoryRepository(db).refreshItems([itemId]);
    await _touchItem(itemId);
  });

  /// Set-specific song sequence; null or empty restores the song's own.
  Future<void> setItemSequence(String itemId, String? sequence) =>
      db.transaction(() async {
        final value = sequence?.trim();
        await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
          SetItemsCompanion(
            sequence: Value(value == null || value.isEmpty ? null : value),
          ),
        );
        await PlayHistoryRepository(db).refreshItems([itemId]);
        await _touchItem(itemId);
      });

  /// A set is "offline ready" when all its songs and their attachment files
  /// are available locally (ADR-0001): the number of its song items that are
  /// not (song missing, or one of its files missing); 0 = offline ready.
  Future<int> offlineMissing(String setId) async =>
      (await _missing(await _offlineQuery(setId: setId).get()))[setId] ?? 0;

  /// Per set of the band, the number of song items that are not available
  /// offline (see [offlineMissing]), from one query for all sets; offline
  /// ready sets are missing. Updated when sets, items, songs or attachments
  /// change.
  Stream<Map<String, int>> watchOfflineMissing() =>
      _offlineQuery().watch().asyncMap(_missing);

  /// Number of songs with ChordPro problems per set of the band (#314);
  /// sets without such songs are missing.
  Stream<Map<String, int>> watchProblemSongCounts() => db
      .customSelect(
        'SELECT i.set_id AS set_id, COUNT(DISTINCT s.id) AS songs '
        'FROM set_items i '
        'JOIN setlists l ON l.id = i.set_id '
        'JOIN songs s ON s.id = i.song_id '
        "WHERE i.type = 'song' AND l.band_id = ? AND l.deleted = 0 "
        'AND s.deleted = 0 AND s.chordpro_problems > 0 GROUP BY i.set_id',
        variables: [Variable.withString(bandId)],
        readsFrom: {db.setItems, db.setlists, db.songs},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('set_id'): r.read<int>('songs'),
        },
      );

  /// Number of songs per set of the band that wait for a check or have
  /// open mistake reports (ADR-0060); sets without such songs are missing.
  Stream<Map<String, int>> watchReviewSongCounts() => db
      .customSelect(
        'SELECT i.set_id AS set_id, COUNT(DISTINCT s.id) AS songs '
        'FROM set_items i '
        'JOIN setlists l ON l.id = i.set_id '
        'JOIN songs s ON s.id = i.song_id '
        "WHERE i.type = 'song' AND l.band_id = ? AND l.deleted = 0 "
        'AND s.deleted = 0 AND (s.review_state IS NOT NULL OR EXISTS ('
        'SELECT 1 FROM song_reports r WHERE r.song_id = s.id '
        "AND r.deleted = 0 AND r.status = 'open')) GROUP BY i.set_id",
        variables: [Variable.withString(bandId)],
        readsFrom: {db.setItems, db.setlists, db.songs, db.songReports},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('set_id'): r.read<int>('songs'),
        },
      );

  /// One row per song item and attachment: the item's set, its song (null
  /// if missing) and an attachment file (null if none).
  Selectable<QueryRow> _offlineQuery({String? setId}) => db.customSelect(
    'SELECT i.set_id AS set_id, i.id AS item, s.id AS song, '
    's.deleted AS song_deleted, '
    'a.file_name AS file FROM set_items i '
    'JOIN setlists l ON l.id = i.set_id '
    'LEFT JOIN songs s ON s.id = i.song_id '
    'LEFT JOIN attachments a ON a.song_id = s.id AND a.deleted = 0 '
    "WHERE i.type = 'song' AND "
    '${setId == null ? 'l.deleted = 0 AND l.band_id' : 'l.id'} = ?',
    variables: [Variable.withString(setId ?? bandId)],
    readsFrom: {db.setItems, db.setlists, db.songs, db.attachments},
  );

  /// Song items per set with a missing song or file; each file is checked
  /// once.
  Future<Map<String, int>> _missing(List<QueryRow> rows) async {
    final missing = <String, Set<String>>{};
    final itemsByFile = <String, Set<(String, String)>>{};
    for (final row in rows) {
      final set = row.read<String>('set_id');
      final item = row.read<String>('item');
      if (row.readNullable<String>('song') == null ||
          row.read<bool>('song_deleted')) {
        (missing[set] ??= {}).add(item);
        continue;
      }
      final file = row.readNullable<String>('file');
      if (file != null) (itemsByFile[file] ??= {}).add((set, item));
    }
    final files = itemsByFile.keys.toList();
    final exists = await Future.wait(files.map(storage.exists));
    for (var i = 0; i < files.length; i++) {
      if (exists[i]) continue;
      for (final (set, item) in itemsByFile[files[i]]!) {
        (missing[set] ??= {}).add(item);
      }
    }
    return {for (final e in missing.entries) e.key: e.value.length};
  }

  /// Records a change of the set (or one of its items) for the sync. Runs in
  /// the transaction of the change.
  Future<void> _touch(String setId) async {
    final current = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(setId))).getSingleOrNull();
    if (current == null) return;
    await (db.update(db.setlists)..where((s) => s.id.equals(setId))).write(
      SetlistsCompanion(
        updatedAt: Value(DateTime.now()),
        updatedBy: Value(_editorIn(current.bandId)),
      ),
    );
    await markDirty(db, SyncCollection.setlists, setId, scope: current.bandId);
  }

  Future<void> _touchItem(String itemId) async {
    final item = await (db.select(
      db.setItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item != null) await _touch(item.setId);
  }
}

/// Whether a set item's own [sequence] fits [song], another language version
/// of its song (ADR-0053): every part it names (`V1`, `C`, `Bridge`, …)
/// exists in [song]. A free adaptation with other parts does not fit.
bool sequenceFits(String sequence, cp.Song song) {
  final parts = cp.songParts(song);
  bool has(cp.SequenceItem item) => parts.any(
    (p) => item.part == cp.SequencePart.other
        ? p.code.trim().toLowerCase() == item.code.trim().toLowerCase()
        : p.part == item.part &&
              (item.number == null || p.number == item.number),
  );
  return cp.parseSequence(sequence).every(has);
}
