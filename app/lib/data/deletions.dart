import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'database.dart';

// Undo of deletions (#267). Deleting only marks records as deleted (soft
// delete, ADR-0004) or removes set items, so a deletion can be undone with
// what it changed: restoring is a normal local change that is synced like
// any other. Attachment files are kept until the undo is no longer offered
// (`SongRepository.purgeFiles`, and `purgeDeletedFiles` at start).

/// What deleting a song changed.
@immutable
class DeletedSong {
  const DeletedSong(
    this.songId, {
    this.attachments = const [],
    this.setItems = const [],
  });

  final String songId;

  /// Attachments deleted with the song (not those deleted before).
  final List<AttachmentEntry> attachments;

  /// Items that referred to the song, removed from their sets.
  final List<SetItemEntry> setItems;
}

/// What deleting a set changed.
@immutable
class DeletedSet {
  const DeletedSet(this.setId, {this.items = const []});

  final String setId;
  final List<SetItemEntry> items;
}

/// What deleting an attachment changed.
@immutable
class DeletedAttachment {
  const DeletedAttachment(this.attachment, {this.liveViewOwners = const []});

  final AttachmentEntry attachment;

  /// Owners of personal adjustments that showed the attachment in live mode
  /// (reset by the deletion).
  final List<String> liveViewOwners;
}

/// The items of [setIds] that [removed] selects, each with its index in its
/// set as the position (positions may have gaps), for [restoreSetItems].
Future<List<SetItemEntry>> itemsToRemove(
  AppDatabase db,
  Iterable<String> setIds,
  bool Function(SetItemEntry) removed,
) async {
  final result = <SetItemEntry>[];
  for (final setId in setIds.toSet()) {
    final items =
        await (db.select(db.setItems)
              ..where((i) => i.setId.equals(setId))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    for (final (index, item) in items.indexed) {
      if (removed(item)) result.add(item.copyWith(position: index));
    }
  }
  return result;
}

/// Puts removed set [items] (from [itemsToRemove]) back at their index,
/// behind the items now before them; the set is numbered 0..n-1 again.
/// Items of sets that no longer exist (or are deleted) and items that are
/// back already are skipped. Returns the changed sets; the caller marks them
/// for the sync.
Future<List<SetlistEntry>> restoreSetItems(
  AppDatabase db,
  Iterable<SetItemEntry> items,
) async {
  final changed = <SetlistEntry>[];
  for (final setId in {for (final i in items) i.setId}) {
    final set = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(setId))).getSingleOrNull();
    if (set == null || set.deleted) continue;
    final current =
        await (db.select(db.setItems)
              ..where((i) => i.setId.equals(setId))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final ids = {for (final i in current) i.id};
    final back = [
      for (final i in items)
        if (i.setId == setId && !ids.contains(i.id)) i,
    ]..sort((a, b) => a.position.compareTo(b.position));
    if (back.isEmpty) continue;
    final order = [...current];
    for (final item in back) {
      order.insert(math.min(item.position, order.length), item);
    }
    for (final (index, item) in order.indexed) {
      await db
          .into(db.setItems)
          .insertOnConflictUpdate(item.copyWith(position: index));
    }
    changed.add(set);
  }
  return changed;
}
