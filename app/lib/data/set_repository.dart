import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

const _uuid = Uuid();

/// A set item together with its song (if any).
class SetItemView {
  const SetItemView(this.item, this.song);

  final SetItemEntry item;
  final SongEntry? song;
}

/// Summary of a set for list views.
class SetSummary {
  const SetSummary(this.set, this.itemCount);

  final SetlistEntry set;
  final int itemCount;
}

/// Access to sets (setlists) and their items of one band (the current
/// band, or the local library by default).
class SetRepository {
  SetRepository(this.db, this.storage, {this.bandId = localBandId});

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Band whose sets are listed and to which new sets belong.
  final String bandId;

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
    await db
        .into(db.setlists)
        .insert(
          SetlistsCompanion.insert(
            id: id,
            bandId: bandId,
            name: name.trim(),
            gigDate: Value(gigDate),
            venue: Value(_blankToNull(venue)),
            updatedAt: DateTime.now(),
          ),
        );
    await markDirty(db, SyncCollection.setlists, id, scope: bandId);
    return id;
  }

  Future<void> updateSet(
    String id, {
    required String name,
    DateTime? gigDate,
    String? venue,
  }) async {
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        name: Value(name.trim()),
        gigDate: Value(gigDate),
        venue: Value(_blankToNull(venue)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _touch(id);
  }

  Future<void> deleteSet(String id) => db.transaction(() async {
    await (db.update(db.setlists)..where((s) => s.id.equals(id))).write(
      SetlistsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (db.delete(db.setItems)..where((i) => i.setId.equals(id))).go();
    await _touch(id);
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

  Future<void> addSongs(String setId, List<String> songIds) async {
    await db.transaction(() async {
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
    });
    await _touch(setId);
  }

  /// Adds a pause or a text item (announcement, encore separator, …).
  Future<void> addMarker(String setId, SetItemType type, String label) async {
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
  }

  Future<void> updateMarker(String itemId, String label) async {
    await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
      SetItemsCompanion(note: Value(label.trim())),
    );
    await _touchItem(itemId);
  }

  Future<void> removeItem(String setId, String itemId) async {
    await (db.delete(db.setItems)..where((i) => i.id.equals(itemId))).go();
    await _renumber(setId);
    await _touch(setId);
  }

  /// Stores the order of [itemIds] as positions 0..n-1.
  Future<void> reorder(String setId, List<String> itemIds) async {
    await db.transaction(() async {
      for (var i = 0; i < itemIds.length; i++) {
        await (db.update(db.setItems)..where((it) => it.id.equals(itemIds[i])))
            .write(SetItemsCompanion(position: Value(i)));
      }
    });
    await _touch(setId);
  }

  Future<void> setItemTranspose(String itemId, int transpose) async {
    await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
      SetItemsCompanion(transpose: Value(transpose)),
    );
    await _touchItem(itemId);
  }

  /// Set-specific song sequence; null or empty restores the song's own.
  Future<void> setItemSequence(String itemId, String? sequence) async {
    final value = sequence?.trim();
    await (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
      SetItemsCompanion(
        sequence: Value(value == null || value.isEmpty ? null : value),
      ),
    );
    await _touchItem(itemId);
  }

  /// A set is "offline ready" when all its songs and their attachment files
  /// are available locally (ADR-0001).
  Future<bool> isOfflineReady(String setId) async {
    final items = await getItems(setId);
    for (final view in items) {
      if (view.item.type != SetItemType.song) continue;
      if (view.song == null) return false;
      final files =
          await (db.select(db.attachments)..where(
                (a) => a.songId.equals(view.song!.id) & a.deleted.equals(false),
              ))
              .get();
      for (final f in files) {
        if (!await storage.exists(f.fileName)) return false;
      }
    }
    return true;
  }

  Future<void> _renumber(String setId) async {
    final items = await getItems(setId);
    await reorder(setId, [for (final v in items) v.item.id]);
  }

  /// Records a change of the set (or one of its items) for the sync.
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

String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
