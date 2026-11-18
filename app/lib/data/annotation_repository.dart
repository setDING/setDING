import 'dart:convert';

import 'package:drift/drift.dart';

import 'annotation.dart';
import 'database.dart';
import 'outbox.dart';
import 'song_repository.dart' show overlayOwnerFor;

export 'annotation.dart';

/// A stroke together with what it annotates, e.g. for an undo of "delete
/// all annotations".
typedef TargetedStroke = ({String target, AnnotationStroke stroke});

/// Personal freehand annotations of the signed-in person (ADR-0032), or of
/// the local owner for the local library and without an account (like
/// personal overlays, ADR-0020).
class AnnotationRepository {
  AnnotationRepository(this.db, {this.userId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;

  /// The signed-in user, or null.
  final String? userId;
  final DateTime Function() _clock;

  Future<(String owner, String library)> _ownerOf(String songId) async {
    final library =
        await (db.selectOnly(db.songs)
              ..addColumns([db.songs.libraryId])
              ..where(db.songs.id.equals(songId)))
            .map((r) => r.read(db.songs.libraryId)!)
            .getSingleOrNull() ??
        localBandId;
    return (overlayOwnerFor(library, userId), library);
  }

  /// The strokes on [songId]'s ChordPro text ([target] empty) or on one of
  /// its PDF attachments, in drawing order.
  Stream<List<AnnotationStroke>> watch(String songId, {String target = ''}) =>
      Stream.fromFuture(_ownerOf(songId)).asyncExpand(
        (o) =>
            (db.select(db.annotations)
                  ..where(
                    (a) =>
                        a.ownerId.equals(o.$1) &
                        a.songId.equals(songId) &
                        a.target.equals(target) &
                        a.stroke.isNotNull(),
                  )
                  ..orderBy([(a) => OrderingTerm.asc(a.updatedAt)]))
                .watch()
                .map(_decode),
      );

  /// Number of strokes on [songId] (text and attachments together).
  Stream<int> watchCount(String songId) =>
      Stream.fromFuture(_ownerOf(songId)).asyncExpand((o) {
        final count = db.annotations.id.count();
        return (db.selectOnly(db.annotations)
              ..addColumns([count])
              ..where(
                db.annotations.ownerId.equals(o.$1) &
                    db.annotations.songId.equals(songId) &
                    db.annotations.stroke.isNotNull(),
              ))
            .map((r) => r.read(count) ?? 0)
            .watchSingle();
      });

  /// Estimated size in bytes of the strokes of [songId] on [target] as the
  /// server stores them: each stroke and each tombstone with its ID.
  Stream<int> watchSize(String songId, {String target = ''}) =>
      Stream.fromFuture(_ownerOf(songId))
          .asyncExpand((o) => _sizeQuery(o.$1, songId, target).watchSingle());

  Selectable<int> _sizeQuery(String owner, String songId, String target) => db
      .customSelect(
        // A tombstone ({"deleted":true,"t":…}) is about 35 bytes; "id":
        // and separators about 6.
        'SELECT COALESCE(SUM(LENGTH(id) + 6 + '
        'COALESCE(LENGTH(stroke), 35)), 0) AS size FROM annotations '
        'WHERE owner_id = ? AND song_id = ? AND target = ?',
        variables: [
          Variable.withString(owner),
          Variable.withString(songId),
          Variable.withString(target),
        ],
        readsFrom: {db.annotations},
      )
      .map((r) => r.read<int>('size'));

  static List<AnnotationStroke> _decode(List<AnnotationRow> rows) => [
    for (final r in rows)
      ?AnnotationStroke.fromJson(r.id, jsonDecode(r.stroke!)),
  ];

  /// Adds or replaces the strokes [put] and erases the strokes [remove], in
  /// one change that is synced as one (ADR-0032). Throws
  /// [AnnotationsFullException] and stores nothing when the change would
  /// grow the strokes of [songId] on [target] beyond [annotationMaxBytes].
  Future<void> apply(
    String songId, {
    String target = '',
    Iterable<AnnotationStroke> put = const [],
    Iterable<String> remove = const [],
  }) => db.transaction(() async {
    final (owner, library) = await _ownerOf(songId);
    final sizeBefore = put.isEmpty
        ? 0
        : await _sizeQuery(owner, songId, target).getSingle();
    var now = _clock().millisecondsSinceEpoch;
    for (final s in put) {
      await db.customInsert(
        'INSERT INTO annotations '
        '(id, owner_id, song_id, target, stroke, updated_at, pending) '
        'VALUES (?, ?, ?, ?, ?, ?, 1) '
        'ON CONFLICT (id) DO UPDATE SET stroke = excluded.stroke, '
        'updated_at = excluded.updated_at, pending = pending + 1',
        variables: [
          Variable.withString(s.id),
          Variable.withString(owner),
          Variable.withString(songId),
          Variable.withString(target),
          Variable.withString(jsonEncode(s.toJson())),
          // Distinct times keep the drawing order of a batch.
          Variable.withInt(now++),
        ],
        updates: {db.annotations},
      );
    }
    final ids = remove.toList();
    if (ids.isNotEmpty) {
      final marks = List.filled(ids.length, '?').join(', ');
      if (owner == localOwnerId) {
        // Never synced: nothing to tell the server.
        await db.customUpdate(
          'DELETE FROM annotations WHERE id IN ($marks)',
          variables: [for (final id in ids) Variable.withString(id)],
          updates: {db.annotations},
          updateKind: UpdateKind.delete,
        );
      } else {
        await db.customUpdate(
          'UPDATE annotations SET stroke = NULL, updated_at = ?, '
          'pending = pending + 1 WHERE id IN ($marks)',
          variables: [
            Variable.withInt(now),
            for (final id in ids) Variable.withString(id),
          ],
          updates: {db.annotations},
          updateKind: UpdateKind.update,
        );
      }
    }
    if (put.isNotEmpty) {
      final size = await _sizeQuery(owner, songId, target).getSingle();
      // Rolls the transaction back; shrinking an oversized set is fine.
      if (size > annotationMaxBytes && size > sizeBefore) {
        throw const AnnotationsFullException();
      }
    }
    if (owner != localOwnerId && (ids.isNotEmpty || put.isNotEmpty)) {
      await markDirty(
        db,
        SyncCollection.annotations,
        annotationRecordId(owner, songId, target),
        scope: library,
      );
    }
  });

  /// Erases all strokes on [songId] (text and attachments) and returns them
  /// for [restoreAll].
  Future<List<TargetedStroke>> deleteAll(String songId) async {
    final (owner, _) = await _ownerOf(songId);
    final rows =
        await (db.select(db.annotations)
              ..where(
                (a) =>
                    a.ownerId.equals(owner) &
                    a.songId.equals(songId) &
                    a.stroke.isNotNull(),
              )
              ..orderBy([(a) => OrderingTerm.asc(a.updatedAt)]))
            .get();
    final removed = <TargetedStroke>[
      for (final r in rows)
        if (AnnotationStroke.fromJson(r.id, jsonDecode(r.stroke!))
            case final s?)
          (target: r.target, stroke: s),
    ];
    await db.transaction(() async {
      for (final target in {for (final r in rows) r.target}) {
        await apply(
          songId,
          target: target,
          remove: [
            for (final r in rows)
              if (r.target == target) r.id,
          ],
        );
      }
    });
    return removed;
  }

  /// Undoes [deleteAll].
  Future<void> restoreAll(String songId, List<TargetedStroke> strokes) =>
      db.transaction(() async {
        for (final target in {for (final s in strokes) s.target}) {
          await apply(
            songId,
            target: target,
            put: [
              for (final s in strokes)
                if (s.target == target) s.stroke,
            ],
          );
        }
      });
}
