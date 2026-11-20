import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'deletions.dart';
import 'outbox.dart';
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
  SetRepository(this.db, this.storage, {this.bandId = localBandId});

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Band whose sets are listed and to which new sets belong.
  final String bandId;

  /// For each song in a set of the band with a gig date on [today] or
  /// later: the first of these sets (by date).
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

  Future<String> createSet({
    required String name,
    DateTime? gigDate,
    String? venue,
  }) async {
    final id = _uuid.v4();
    await db.transaction(() async {
      await db
          .into(db.setlists)
          .insert(
            SetlistsCompanion.insert(
              id: id,
              bandId: bandId,
              name: name.trim(),
              gigDate: Value(gigDate),
              venue: Value(blankToNull(venue)),
              updatedAt: DateTime.now(),
            ),
          );
      await markDirty(db, SyncCollection.setlists, id, scope: bandId);
    });
    return id;
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
        for (final songId in songIds) {
          await db
              .into(db.setItems)
              .insert(
                SetItemsCompanion.insert(
                  id: _uuid.v4(),
                  setId: setId,
                  songId: Value(songId),
                  position: position++,
                  type: SetItemType.song,
                ),
              );
        }
        await _touch(setId);
      });

  /// Adds a pause or a text item (announcement, encore separator, …).
  Future<void> addMarker(String setId, SetItemType type, String label) =>
      db.transaction(() async {
        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                id: _uuid.v4(),
                setId: setId,
                position: await _nextPosition(setId),
                type: type,
                note: Value(label.trim()),
              ),
            );
        await _touch(setId);
      });

  Future<void> updateMarker(String itemId, String label) =>
      db.transaction(() async {
        await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
          SetItemsCompanion(note: Value(label.trim())),
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
        await _touchItem(itemId);
      });

  /// A set is "offline ready" when all its songs and their attachment files
  /// are available locally (ADR-0001).
  Future<bool> isOfflineReady(String setId) async =>
      !(await _notReady(await _offlineQuery(setId: setId).get()))
          .contains(setId);

  /// IDs of the band's sets that are not offline ready (see
  /// [isOfflineReady]), from one query for all sets; updated when sets,
  /// items, songs or attachments change.
  Stream<Set<String>> watchNotOfflineReady() =>
      _offlineQuery().watch().asyncMap(_notReady);

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

  /// One row per song item and attachment: the item's set, its song (null
  /// if missing) and an attachment file (null if none).
  Selectable<QueryRow> _offlineQuery({String? setId}) => db.customSelect(
    'SELECT i.set_id AS set_id, s.id AS song, s.deleted AS song_deleted, '
    'a.file_name AS file FROM set_items i '
    'JOIN setlists l ON l.id = i.set_id '
    'LEFT JOIN songs s ON s.id = i.song_id '
    'LEFT JOIN attachments a ON a.song_id = s.id AND a.deleted = 0 '
    "WHERE i.type = 'song' AND "
    '${setId == null ? 'l.deleted = 0 AND l.band_id' : 'l.id'} = ?',
    variables: [Variable.withString(setId ?? bandId)],
    readsFrom: {db.setItems, db.setlists, db.songs, db.attachments},
  );

  /// Sets with a missing song or file; each file is checked once.
  Future<Set<String>> _notReady(List<QueryRow> rows) async {
    final notReady = <String>{};
    final setsByFile = <String, Set<String>>{};
    for (final row in rows) {
      final set = row.read<String>('set_id');
      if (row.readNullable<String>('song') == null ||
          row.read<bool>('song_deleted')) {
        notReady.add(set);
        continue;
      }
      final file = row.readNullable<String>('file');
      if (file != null) (setsByFile[file] ??= {}).add(set);
    }
    final files = setsByFile.keys.toList();
    final exists = await Future.wait(files.map(storage.exists));
    for (var i = 0; i < files.length; i++) {
      if (!exists[i]) notReady.addAll(setsByFile[files[i]]!);
    }
    return notReady;
  }

  /// Records a change of the set (or one of its items) for the sync. Runs in
  /// the transaction of the change.
  Future<void> _touch(String setId) async {
    final current = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(setId))).getSingleOrNull();
    if (current == null) return;
    await (db.update(db.setlists)..where((s) => s.id.equals(setId))).write(
      SetlistsCompanion(updatedAt: Value(DateTime.now())),
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
