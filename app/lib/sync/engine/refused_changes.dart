import '../../data/database.dart';
import 'sync_store.dart';

/// The kind of record whose change the server refused.
enum RefusedRecord { song, set, attachment, adjustment }

/// A change the server refused for good in a sync run (ADR-0004): an
/// attachment change on the server (#1229), or a change of a song, set or
/// personal adjustment (#1260). It is undone on this device, which gets the
/// server's version back, or loses the record when the server does not show
/// it to the person (#1248).
///
/// [id] is the record's ID (for an adjustment, its song's ID); [name] is
/// what the person knows it by (the song title of a song or adjustment);
/// [songTitle] is the song of an attachment.
typedef RefusedChange = ({
  RefusedRecord kind,
  String id,
  String name,
  String? songTitle,
});

/// Undoes the changes the server refused for good in a sync run (ADR-0004,
/// #1229, #1260), shared by the parts of the sync: the copy on this device
/// counts as one revision older than the server's, the pull cursor goes
/// below it and the outbox entry is removed, so the record is never sent
/// again and pulling its scope again brings the server's version back
/// ([pullAgain]); a record the server does not send back is removed.
class RefusedChanges {
  RefusedChanges(this.store);

  final SyncStore store;

  var _changes = <RefusedChange>[];

  /// Scopes (organization, band, user) to pull again, by cursor collection.
  final _scopes = <String, Set<String>>{};

  /// Undoes the refused [entry] of [change]: [revision] is the record's
  /// revision on this device (0 for a record the server never had), which
  /// [setRevision] lowers; [collection] and [scope] name the pull cursor.
  Future<void> undo(
    OutboxEntry entry,
    RefusedChange change, {
    required String collection,
    required String scope,
    required int revision,
    required Future<void> Function(int before) setRevision,
  }) async {
    await store.db.transaction(() async {
      if (revision > 0) {
        final before = revision - 1;
        await setRevision(before);
        if (await store.cursor(scope, collection) > before) {
          await store.setCursor(scope, collection, before);
        }
      }
      await store.done(entry);
    });
    _scopes.putIfAbsent(collection, () => {}).add(scope);
    if (!_changes.any((c) => c.kind == change.kind && c.id == change.id)) {
      _changes.add(change);
    }
  }

  /// IDs of the records of [kind] undone since the last [take].
  Set<String> ids(RefusedRecord kind) => {
    for (final c in _changes)
      if (c.kind == kind) c.id,
  };

  /// Pulls the scopes of [collection] with undone records again ([pull]
  /// returns the IDs the server sent, recording none of them as changes of
  /// others), then hands the undone records of [kind] the server did not
  /// send back to [remove]. Returns the number of records pulled.
  Future<int> pullAgain(
    String collection,
    RefusedRecord kind, {
    required Future<Set<String>> Function(String scope, Set<String> quiet) pull,
    required Future<void> Function(Set<String> ids) remove,
  }) async {
    final scopes = _scopes.remove(collection);
    if (scopes == null) return 0;
    final undone = ids(kind);
    final pulled = <String>{};
    for (final scope in scopes) {
      pulled.addAll(await pull(scope, undone));
    }
    final gone = undone.difference(pulled);
    if (gone.isNotEmpty) await remove(gone);
    return pulled.length;
  }

  /// The changes undone since the last call, for the report of a sync run.
  List<RefusedChange> take() {
    final changes = _changes;
    _changes = [];
    _scopes.clear();
    return changes;
  }
}
