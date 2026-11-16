import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../data/database.dart';

/// What happened to an outbox entry in a push.
enum PushResult { done, skipped, conflict }

/// Shared state of the sync (ADR-0004): pull cursors, the outbox and
/// lookups for batches of pulled records.
class SyncStore {
  SyncStore(this.db);

  final AppDatabase db;

  /// Highest server revision pulled for [scope] (organization, band or
  /// user) and [collection]; 0 before the first pull.
  Future<int> cursor(String scope, String collection) async {
    final row =
        await (db.select(db.syncCursors)..where(
              (c) => c.scope.equals(scope) & c.collection.equals(collection),
            ))
            .getSingleOrNull();
    return row?.revision ?? 0;
  }

  Future<void> setCursor(String scope, String collection, int revision) => db
      .into(db.syncCursors)
      .insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
          scope: scope,
          collection: collection,
          revision: Value(revision),
        ),
      );

  /// Rows for [ids], loaded in chunks (SQLite limits the variables of a
  /// statement), by ID.
  static Future<Map<String, T>> byId<T>(
    List<String> ids,
    Future<List<T>> Function(List<String> chunk) load,
    String Function(T) id,
  ) async {
    const chunkSize = 500;
    final result = <String, T>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, math.min(i + chunkSize, ids.length));
      for (final row in await load(chunk)) {
        result[id(row)] = row;
      }
    }
    return result;
  }

  /// Which of [ids] have a pending local change in [collection].
  Future<Set<String>> dirty(String collection, List<String> ids) async =>
      (await byId(
        ids,
        (chunk) =>
            (db.select(db.syncOutbox)..where(
                  (o) =>
                      o.collection.equals(collection) & o.recordId.isIn(chunk),
                ))
                .get(),
        (o) => o.recordId,
      )).keys.toSet();

  /// Which of [ids] are songs on this device (also deleted ones).
  Future<Set<String>> existingSongs(List<String> ids) async => (await byId(
    ids.toSet().toList(),
    (chunk) =>
        (db.selectOnly(db.songs)
              ..addColumns([db.songs.id])
              ..where(db.songs.id.isIn(chunk)))
            .map((r) => r.read(db.songs.id)!)
            .get(),
    (id) => id,
  )).keys.toSet();

  /// Removes a pushed outbox entry, unless the record changed again while
  /// it was pushed (a newer version stays for the next push).
  Future<void> done(OutboxEntry entry) =>
      (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(entry.collection) &
                o.recordId.equals(entry.recordId) &
                o.version.equals(entry.version),
          ))
          .go();
}
