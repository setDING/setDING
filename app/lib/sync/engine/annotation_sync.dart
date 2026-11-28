import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/annotation.dart';
import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'refused_changes.dart';
import 'sync_store.dart';

const _log = Log('sync');
const _uuid = Uuid();

/// Sync of freehand annotations with the account (ADR-0032): delta pull per
/// user; one server record per user, song and target, merged per stroke ID
/// (on the server for a push, here for a pull: strokes changed on this
/// device and not pushed yet win).
class AnnotationSync {
  AnnotationSync(this.db, this.backend, this.store, {RefusedChanges? undone})
    : undone = undone ?? RefusedChanges(store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Annotations the server refused for good (#1264).
  final RefusedChanges undone;

  /// Server record ID of the annotations of [userId] on [songId] and
  /// [target]: the same on every device, so two devices never create two
  /// records.
  static String serverId(String userId, String songId, String target) => _uuid
      .v5(Namespace.url.value, 'setding:annotations:$userId:$songId:$target');

  Future<int> pull(String userId) async {
    final since = await store.cursor(userId, SyncCollection.annotations);
    final remote = await backend.pullAnnotations(since);
    if (remote.isEmpty) return 0;
    await db.transaction(() async {
      final songs = await store.existingSongs([
        for (final r in remote) r.songId,
      ]);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final r in remote) {
        if (!songs.contains(r.songId)) continue; // the song is not here
        final target = r.attachmentId ?? '';
        if (r.deleted) {
          // With its song or attachment; changes not pushed yet stay.
          await (db.delete(db.annotations)..where(
                (a) =>
                    a.ownerId.equals(userId) &
                    a.songId.equals(r.songId) &
                    a.target.equals(target) &
                    a.pending.equals(0),
              ))
              .go();
          continue;
        }
        final locals = await SyncStore.byId(
          r.data.keys.toList(),
          (chunk) =>
              (db.select(db.annotations)..where((a) => a.id.isIn(chunk))).get(),
          (a) => a.id,
        );
        for (final MapEntry(key: id, value: json) in r.data.entries) {
          final local = locals[id];
          // Last writer wins per stroke: a pending change is pushed after.
          if (local != null && local.pending > 0) continue;
          if (json is! Map || json['deleted'] == true) {
            if (local != null) {
              await (db.delete(
                db.annotations,
              )..where((a) => a.id.equals(id))).go();
            }
            continue;
          }
          await db
              .into(db.annotations)
              .insertOnConflictUpdate(
                AnnotationsCompanion.insert(
                  id: id,
                  ownerId: userId,
                  songId: r.songId,
                  target: Value(target),
                  stroke: Value(jsonEncode(json)),
                  updatedAt: (json['t'] as num?)?.toInt() ?? now,
                  pending: const Value(0),
                ),
              );
        }
      }
      await store.setCursor(
        userId,
        SyncCollection.annotations,
        remote.last.revision,
      );
    });
    return remote.length;
  }

  Future<PushResult> push(OutboxEntry entry, String userId) async {
    final (owner, songId, target) = parseAnnotationRecordId(entry.recordId);
    // Another person's change on a shared device: pushed when they sync.
    if (owner != userId) return PushResult.skipped;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null || song.libraryId == localBandId || song.deleted) {
      // The server deletes them with the song.
      await store.done(entry);
      return PushResult.skipped;
    }
    if (song.revision == 0) return PushResult.skipped; // the song comes first
    if (target.isNotEmpty) {
      final attachment = await (db.select(
        db.attachments,
      )..where((a) => a.id.equals(target))).getSingleOrNull();
      if (attachment == null || attachment.deleted) {
        await store.done(entry);
        return PushResult.skipped;
      }
      if (attachment.revision == 0) return PushResult.skipped;
    }
    final rows =
        await (db.select(db.annotations)..where(
              (a) =>
                  a.ownerId.equals(owner) &
                  a.songId.equals(songId) &
                  a.target.equals(target) &
                  a.pending.isBiggerThanValue(0),
            ))
            .get();
    if (rows.isEmpty) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final remote = RemoteAnnotations(
      id: serverId(owner, songId, target),
      userId: owner,
      songId: songId,
      attachmentId: target.isEmpty ? null : target,
      data: {
        for (final r in rows)
          r.id: r.stroke == null
              ? annotationTombstone(r.updatedAt)
              : {
                  ...(jsonDecode(r.stroke!) as Map<String, dynamic>),
                  't': r.updatedAt,
                },
      },
    );
    try {
      try {
        await backend.pushAnnotations(remote, create: false);
      } on BackendException catch (e) {
        if (e.kind != BackendErrorKind.notAllowed) rethrow;
        // Not on the server yet.
        try {
          await backend.pushAnnotations(remote, create: true);
        } on BackendException catch (e) {
          // Created by another device of the same person meanwhile; an
          // error that may go away is sent again as it is (#1264).
          if (e.kind != BackendErrorKind.server || !e.refused) rethrow;
          await backend.pushAnnotations(remote, create: false);
        }
      }
    } on BackendException catch (e) {
      if (!e.refused) rethrow; // sent again in the next sync
      // No (longer) permission, or a validation error (e.g. too large):
      // sending it again gets the same answer (#1264). The drawing is
      // personal and stays on this device as it is (ADR-0006, ADR-0032),
      // but is not sent again: its strokes count as synced.
      _log.warning('Annotations ${entry.recordId} refused, kept here', e);
      await _settle(rows);
      await undone.keepLocal(entry, (
        kind: RefusedRecord.keptAnnotations,
        id: entry.recordId,
        name: song.title,
        songTitle: song.title,
      ));
      return PushResult.skipped;
    }
    await db.transaction(() async {
      await _settle(rows);
      await store.done(entry);
    });
    return PushResult.done;
  }

  /// Marks the strokes [rows] as pushed: erased ones go, the others are no
  /// longer pending.
  Future<void> _settle(List<AnnotationRow> rows) => db.transaction(() async {
    for (final r in rows) {
      // Changed again while pushing: stays pending for the next push.
      final same =
          db.annotations.id.equals(r.id) &
          db.annotations.pending.equals(r.pending);
      if (r.stroke == null) {
        await (db.delete(db.annotations)..where((_) => same)).go();
      } else {
        await (db.update(db.annotations)..where((_) => same)).write(
          const AnnotationsCompanion(pending: Value(0)),
        );
      }
    }
  });
}
