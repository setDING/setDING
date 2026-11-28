import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/change_log.dart';
import '../../data/database.dart';
import '../sync_backend.dart';

/// What changed between the items of a set on this device ([before]) and
/// the items from the server ([after]) (ADR-0045): the songs added and
/// removed, counted per song (a reordering is no change), and the songs
/// whose set item got another sequence. Items of songs not on this device
/// ([songExists]) do not count, as the sync stores them without a song.
({int added, int removed, List<String> sequenceSongIds}) diffSetItems(
  List<RemoteSetItem> before,
  List<RemoteSetItem> after, {
  bool Function(String songId)? songExists,
}) {
  bool isSong(RemoteSetItem i) =>
      i.type == SetItemType.song && i.songId != null;
  final old = before.where(isSong).toList();
  final current = [
    for (final i in after)
      if (isSong(i) && (songExists?.call(i.songId!) ?? true)) i,
  ];

  final counts = <String, int>{};
  for (final i in old) {
    counts.update(i.songId!, (n) => n - 1, ifAbsent: () => -1);
  }
  for (final i in current) {
    counts.update(i.songId!, (n) => n + 1, ifAbsent: () => 1);
  }
  var added = 0;
  var removed = 0;
  for (final n in counts.values) {
    if (n > 0) added += n;
    if (n < 0) removed -= n;
  }

  // The same item: by its ID, otherwise the next item of the same song.
  final unmatched = [...old];
  final pairs = <(RemoteSetItem, RemoteSetItem)>[];
  final rest = <RemoteSetItem>[];
  for (final item in current) {
    final i = item.id.isEmpty
        ? -1
        : unmatched.indexWhere(
            (o) => o.id == item.id && o.songId == item.songId,
          );
    if (i < 0) {
      rest.add(item);
    } else {
      pairs.add((unmatched.removeAt(i), item));
    }
  }
  for (final item in rest) {
    final i = unmatched.indexWhere((o) => o.songId == item.songId);
    if (i >= 0) pairs.add((unmatched.removeAt(i), item));
  }
  final sequenceSongIds = <String>[];
  for (final (o, n) in pairs) {
    if ((o.sequence ?? '') != (n.sequence ?? '') &&
        !sequenceSongIds.contains(n.songId)) {
      sequenceSongIds.add(n.songId!);
    }
  }
  return (added: added, removed: removed, sequenceSongIds: sequenceSongIds);
}

/// What a sync run changed of someone else's on this device (#691): the
/// open song or set screen tells the person.
enum SyncChangeKind {
  songChanged,
  songDeleted,
  setChanged,
  setDeleted;

  bool get isSet => this == setChanged || this == setDeleted;
  bool get isDeletion => this == songDeleted || this == setDeleted;
}

/// One change of a song or set by someone else, applied by a sync run
/// (#691).
@immutable
class SyncChange {
  const SyncChange(this.kind, this.recordId, this.title, this.userId);

  final SyncChangeKind kind;
  final String recordId;

  /// The song's or set's title on this device.
  final String title;

  /// Who changed it (`updated_by`).
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is SyncChange &&
      other.kind == kind &&
      other.recordId == recordId &&
      other.title == title &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(kind, recordId, title, userId);

  @override
  String toString() => 'SyncChange(${kind.name}, $title)';
}

/// Records the changes of other people that the sync applies in the
/// change log (ADR-0045), by comparing each record from the server with the
/// local state it replaces. Nothing is recorded on the first sync of a
/// library or band, for changes of the signed-in user (also from their
/// other devices) and for changes without a known editor.
class ChangeRecorder {
  ChangeRecorder(this.db) : log = ChangeLogRepository(db);

  final AppDatabase db;
  final ChangeLogRepository log;

  final _run = <SyncChange>[];

  /// The changes for the open screens (#691) since the last call: unlike
  /// the change log, deletions and reorderings count, too.
  List<SyncChange> takeRun() {
    final run = List.of(_run);
    _run.clear();
    return run;
  }

  /// Whether a change by [updatedBy] is recorded for the signed-in user
  /// [logChangesFor] (null: nothing is recorded). A change without a known
  /// editor is not recorded either.
  static bool records(String? updatedBy, String? logChangesFor) =>
      logChangesFor != null && updatedBy != null && updatedBy != logChangesFor;

  /// A song from the server replaces [local] (null: new on this device).
  Future<void> song(SongEntry? local, RemoteSong remote, String title) async {
    if (remote.deleted) {
      if (local != null && !local.deleted) await _songDeleted(local, remote);
      return;
    }
    if (local?.deleted ?? false) return; // restored from the trash
    if (local == null) {
      await log.add(
        kind: ChangeKind.songAdded,
        scopeId: remote.organizationId,
        recordId: remote.id,
        title: title,
        userId: remote.createdBy ?? remote.updatedBy,
      );
      return;
    }
    if (local.chordproSource == remote.chordpro) return;
    _run.add(
      SyncChange(
        SyncChangeKind.songChanged,
        remote.id,
        title,
        remote.updatedBy,
      ),
    );
    await log.add(
      kind: ChangeKind.songChanged,
      scopeId: remote.organizationId,
      recordId: remote.id,
      title: title,
      userId: remote.updatedBy,
      details: const ChangeDetails(text: true),
    );
  }

  /// An attachment from the server replaces [local]: a PDF or image added,
  /// replaced or removed counts as a change of its song (a new name does
  /// not).
  Future<void> attachment(
    AttachmentEntry? local,
    RemoteAttachment remote,
  ) async {
    final wasThere = local != null && !local.deleted;
    final changed = switch ((wasThere, remote.deleted)) {
      (false, false) => true, // added
      (true, true) => true, // removed
      (true, false) => local!.remoteFile != remote.file, // replaced
      (false, true) => false,
    };
    if (!changed) return;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(remote.songId))).getSingleOrNull();
    if (song == null || song.deleted) return;
    _run.add(
      SyncChange(
        SyncChangeKind.songChanged,
        song.id,
        song.title,
        remote.updatedBy,
      ),
    );
    await log.add(
      kind: ChangeKind.songChanged,
      scopeId: remote.organizationId,
      recordId: remote.songId,
      title: song.title,
      userId: remote.updatedBy,
      details: const ChangeDetails(pdf: true),
    );
  }

  /// A set from the server replaces [local] with the items [before].
  Future<void> set(
    SetlistEntry? local,
    List<SetItemEntry> before,
    RemoteSet remote, {
    required bool Function(String songId) songExists,
  }) async {
    if (local?.deleted ?? false) return; // restored from the trash
    if (remote.deleted) {
      if (local != null) {
        _run.add(
          SyncChange(
            SyncChangeKind.setDeleted,
            remote.id,
            local.name,
            remote.updatedBy,
          ),
        );
      }
      return;
    }
    if (local == null) {
      // A new set is one entry, not its songs added (#674); sets have no
      // `created_by`, the first save's editor is the one who created it.
      await log.add(
        kind: ChangeKind.setAdded,
        scopeId: remote.bandId,
        recordId: remote.id,
        title: remote.name,
        userId: remote.updatedBy,
      );
      return;
    }
    if (_setDiffers(local, before, remote, songExists)) {
      _run.add(
        SyncChange(
          SyncChangeKind.setChanged,
          remote.id,
          remote.name,
          remote.updatedBy,
        ),
      );
    }
    final diff = diffSetItems(
      [for (final i in before) RemoteSetItem.fromEntry(i)],
      remote.items,
      songExists: songExists,
    );
    final details = ChangeDetails(
      added: diff.added,
      removed: diff.removed,
      sequences: await _titles(diff.sequenceSongIds),
    );
    if (details.isEmpty) return;
    await log.add(
      kind: ChangeKind.setChanged,
      scopeId: remote.bandId,
      recordId: remote.id,
      title: remote.name,
      userId: remote.updatedBy,
      details: details,
    );
  }

  /// The band's arrangement of a song from the server replaces [local]: a
  /// new sequence is a change of every set of the band with the song.
  Future<void> arrangement(
    BandArrangement? local,
    RemoteArrangement remote,
  ) async {
    final before = local == null || local.deleted ? null : local.sequence;
    final after = remote.deleted ? null : remote.sequence;
    if ((before ?? '') == (after ?? '')) return;
    final title = (await _titles([remote.songId])).firstOrNull;
    if (title == null) return;
    final sets =
        await (db.selectOnly(db.setlists, distinct: true)
              ..addColumns([db.setlists.id, db.setlists.name])
              ..join([
                innerJoin(
                  db.setItems,
                  db.setItems.setId.equalsExp(db.setlists.id),
                  useColumns: false,
                ),
              ])
              ..where(
                db.setlists.bandId.equals(remote.bandId) &
                    db.setlists.deleted.equals(false) &
                    db.setItems.songId.equals(remote.songId),
              ))
            .get();
    for (final row in sets) {
      _run.add(
        SyncChange(
          SyncChangeKind.setChanged,
          row.read(db.setlists.id)!,
          row.read(db.setlists.name)!,
          remote.updatedBy,
        ),
      );
      await log.add(
        kind: ChangeKind.setChanged,
        scopeId: remote.bandId,
        recordId: row.read(db.setlists.id)!,
        title: row.read(db.setlists.name)!,
        userId: remote.updatedBy,
        details: ChangeDetails(sequences: [title]),
      );
    }
  }

  /// [local] was deleted by someone else: not logged (ADR-0045), but the
  /// open song and the open sets that lose it are told (#691). Runs before
  /// the sync removes the song's set items.
  Future<void> _songDeleted(SongEntry local, RemoteSong remote) async {
    _run.add(
      SyncChange(
        SyncChangeKind.songDeleted,
        local.id,
        local.title,
        remote.updatedBy,
      ),
    );
    final sets =
        await (db.selectOnly(db.setlists, distinct: true)
              ..addColumns([db.setlists.id, db.setlists.name])
              ..join([
                innerJoin(
                  db.setItems,
                  db.setItems.setId.equalsExp(db.setlists.id),
                  useColumns: false,
                ),
              ])
              ..where(
                db.setlists.deleted.equals(false) &
                    db.setItems.songId.equals(local.id),
              ))
            .get();
    for (final row in sets) {
      _run.add(
        SyncChange(
          SyncChangeKind.setChanged,
          row.read(db.setlists.id)!,
          row.read(db.setlists.name)!,
          remote.updatedBy,
        ),
      );
    }
  }

  /// Whether [remote] looks different from [local] with the items
  /// [before]: name, date, venue, or the items and their order (the played
  /// marks of a gig do not count).
  static bool _setDiffers(
    SetlistEntry local,
    List<SetItemEntry> before,
    RemoteSet remote,
    bool Function(String songId) songExists,
  ) {
    if (local.name != remote.name ||
        local.gigDate != remote.gigDate ||
        (local.venue ?? '') != (remote.venue ?? '')) {
      return true;
    }
    Object key(
      SetItemType type,
      String? icon,
      String? song,
      String? note,
      String? sequence,
      int transpose,
    ) => (type, icon, song, note ?? '', sequence ?? '', transpose);
    final old = [
      for (final i in before)
        key(i.type, i.icon, i.songId, i.note, i.sequence, i.transpose),
    ];
    final current = [
      for (final i in remote.items)
        key(
          i.type,
          i.icon,
          i.songId != null && songExists(i.songId!) ? i.songId : null,
          i.note,
          i.sequence,
          i.transpose,
        ),
    ];
    return !listEquals(old, current);
  }

  /// Titles of the songs [ids] on this device, in this order.
  Future<List<String>> _titles(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (db.select(
      db.songs,
    )..where((s) => s.id.isIn(ids))).get();
    final byId = {for (final s in rows) s.id: s.title};
    return [for (final id in ids) ?byId[id]];
  }
}
