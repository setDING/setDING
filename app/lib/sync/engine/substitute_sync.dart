import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'set_sync.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of the sets the user plays as a substitute (ADR-0061): the lineup
/// route gives the complete state, which replaces what the device has.
/// Their bands are stored with [BandEntry.substitute]; a band the user is
/// a member of comes from the organizations and is never touched here.
/// Nothing is pushed: a substitute only reads these sets.
class SubstituteSync {
  SubstituteSync(this.db, this.backend, this.store, this.sets);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;
  final SetSync sets;

  /// Fetches the substitute sets and replaces the local ones; returns the
  /// number of sets received. A server without the route (older than
  /// ADR-0061) or another error keeps what the device has.
  Future<int> pull() async {
    final RemoteLineup lineup;
    try {
      lineup = await backend.fetchLineup();
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.network) rethrow;
      _log.info('Substitute sets not fetched: ${e.kind.name}');
      return 0;
    }
    await apply(lineup);
    return lineup.sets.length;
  }

  /// Stores [lineup] as the complete state of the substitute sets.
  Future<void> apply(RemoteLineup lineup) => db.transaction(() async {
    final orgs = {
      for (final o in await db.select(db.organizations).get())
        if (!o.deleted) o.id,
    };
    final existing = {for (final b in await db.select(db.bands).get()) b.id: b};
    // Bands of the result this device stores as substitute bands: not a
    // band the user sees as a member, and in an organization of theirs.
    final bands = <String>{};
    for (final b in lineup.bands) {
      final band = existing[b.id];
      if (band != null && !band.substitute && !band.deleted) continue;
      if (!orgs.contains(b.organizationId)) continue;
      bands.add(b.id);
      final row = BandEntry(
        id: b.id,
        name: b.name,
        organizationId: b.organizationId,
        revision: band?.revision ?? 0,
        deleted: false,
        staleAfterMonths: band?.staleAfterMonths ?? 0,
        substitute: true,
      );
      if (row != band) {
        await db.into(db.bands).insertOnConflictUpdate(row);
      }
    }

    // Substitute bands of this device: the new ones and those of before.
    final all = {
      ...bands,
      for (final b in existing.values)
        if (b.substitute) b.id,
    };
    final keepSets = {
      for (final s in lineup.sets)
        if (bands.contains(s.bandId)) s.id,
    };
    for (final set in await (db.select(
      db.setlists,
    )..where((s) => s.bandId.isIn(all) & s.id.isNotIn(keepSets))).get()) {
      await (db.delete(db.setItems)..where((i) => i.setId.equals(set.id))).go();
      await (db.delete(db.setlists)..where((s) => s.id.equals(set.id))).go();
    }

    final locals = {
      for (final s in await (db.select(
        db.setlists,
      )..where((s) => s.id.isIn(keepSets))).get())
        s.id: s,
    };
    final songs = await store.existingSongs([
      for (final s in lineup.sets)
        for (final item in s.items) ?item.songId,
    ]);
    for (final set in lineup.sets) {
      if (!keepSets.contains(set.id)) continue;
      await sets.apply(set, local: locals[set.id], songExists: songs.contains);
    }

    // Arrangements of the songs in those sets, nothing else of the band.
    final keepArrangements = {
      for (final a in lineup.arrangements)
        if (bands.contains(a.bandId) && !a.deleted) (a.bandId, a.songId),
    };
    for (final a in await (db.select(
      db.bandArrangements,
    )..where((a) => a.bandId.isIn(all))).get()) {
      if (keepArrangements.contains((a.bandId, a.songId))) continue;
      await (db.delete(db.bandArrangements)..where(
            (x) => x.bandId.equals(a.bandId) & x.songId.equals(a.songId),
          ))
          .go();
    }
    final arrangementSongs = await store.existingSongs([
      for (final a in lineup.arrangements) a.songId,
    ]);
    for (final a in lineup.arrangements) {
      if (!keepArrangements.contains((a.bandId, a.songId))) continue;
      if (!arrangementSongs.contains(a.songId)) continue;
      await db
          .into(db.bandArrangements)
          .insertOnConflictUpdate(
            BandArrangementsCompanion.insert(
              bandId: a.bandId,
              songId: a.songId,
              transpose: Value(a.transpose),
              sequence: Value(a.sequence),
              tempo: Value(a.tempo),
              revision: Value(a.revision),
              deleted: const Value(false),
              updatedBy: Value(a.updatedBy),
            ),
          );
    }

    // A substitute band without sets any more is gone from this device.
    final gone = all.difference(bands);
    if (gone.isNotEmpty) {
      await (db.update(db.bands)
            ..where((b) => b.id.isIn(gone) & b.deleted.equals(false)))
          .write(const BandsCompanion(deleted: Value(true)));
    }
  });
}
