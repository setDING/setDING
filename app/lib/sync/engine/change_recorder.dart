import 'package:drift/drift.dart';

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

/// Records the changes of other people that the sync applies in the
/// change log (ADR-0045), by comparing each record from the server with the
/// local state it replaces. Nothing is recorded on the first sync of a
/// library or band, for changes of the signed-in user (also from their
/// other devices) and for changes without a known editor.
class ChangeRecorder {
  ChangeRecorder(this.db) : log = ChangeLogRepository(db);

  final AppDatabase db;
  final ChangeLogRepository log;

  /// Whether a change by [updatedBy] is recorded for the signed-in user
  /// [logChangesFor] (null: nothing is recorded). A change without a known
  /// editor is not recorded either.
  static bool records(String? updatedBy, String? logChangesFor) =>
      logChangesFor != null && updatedBy != null && updatedBy != logChangesFor;

  /// A song from the server replaces [local] (null: new on this device).
  Future<void> song(SongEntry? local, RemoteSong remote, String title) async {
    if (remote.deleted) return;
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
    await log.add(
      kind: ChangeKind.songChanged,
      scopeId: remote.organizationId,
      recordId: remote.id,
      title: title,
      userId: remote.updatedBy,
      details: const ChangeDetails(text: true),
    );
  }

  /// An attachment from the server replaces [local]: a PDF added, replaced
  /// or removed counts as a change of its song (a new name does not).
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
    if (remote.deleted || (local?.deleted ?? false)) return;
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
