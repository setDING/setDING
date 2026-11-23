import 'package:chordpro/chordpro.dart' show Subdivision;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'sync_store.dart';

const _log = Log('sync');
const _uuid = Uuid();

/// Sync of personal adjustments with the account (ADR-0020): delta pull per
/// user, last writer wins, one server record per user and song.
class OverlaySync {
  OverlaySync(this.db, this.backend, this.store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Server record ID of the adjustments of [userId] for [songId]: the same
  /// on every device, so two devices never create two records.
  static String overlayServerId(String userId, String songId) =>
      _uuid.v5(Namespace.url.value, 'setding:overlay:$userId:$songId');

  /// The fields of layer 3 as stored on the server.
  static Map<String, dynamic> overlayData(SongOverlay o) => {
    'transpose': o.transpose,
    'capo_fret': o.capoFret,
    'font_scale': o.fontScale,
    'notes': o.notes,
    'chord_view': o.chordView?.name,
    // For older app versions, which only know Nashville numbers.
    'nashville': o.chordView?.isDegrees,
    'live_view': o.liveView,
    'hide_annotations': o.hideAnnotations,
    'verse_chords': o.verseChords.name,
    'stacked_choruses': o.stackedChoruses,
    'click_grouping': o.clickGrouping,
    'click_subdivision': o.clickSubdivision?.name,
  };

  /// How verses show their chords in the server overlay's [data]:
  /// `verse_chords` (#521), before it `first_verse_chords_only` (#518);
  /// values of newer clients count as all chords.
  static VerseChords verseChordsOf(Map<String, dynamic> data) {
    final name = data['verse_chords'];
    if (name is String) {
      return VerseChords.values.asNameMap()[name] ?? VerseChords.all;
    }
    return data['first_verse_chords_only'] == true
        ? VerseChords.first
        : VerseChords.all;
  }

  Future<int> pull(String userId) async {
    final since = await store.cursor(userId, SyncCollection.overlays);
    final remote = await backend.pullOverlays(since);
    if (remote.isEmpty) return 0;
    await db.transaction(() async {
      final songIds = [for (final o in remote) o.songId];
      final locals = await SyncStore.byId(
        songIds,
        (chunk) => (db.select(
          db.personalOverlays,
        )..where((o) => o.ownerId.equals(userId) & o.songId.isIn(chunk))).get(),
        (o) => o.songId,
      );
      final dirty = await store.dirty(SyncCollection.overlays, [
        for (final id in songIds) overlayRecordId(userId, id),
      ]);
      final songs = await store.existingSongs(songIds);
      for (final o in remote) {
        final local = locals[o.songId];
        if (local != null && o.revision <= local.revision) continue;
        // Last writer wins: a pending local change is pushed afterwards.
        if (dirty.contains(overlayRecordId(userId, o.songId))) continue;
        if (o.deleted) {
          await (db.delete(db.personalOverlays)..where(
                (x) => x.ownerId.equals(userId) & x.songId.equals(o.songId),
              ))
              .go();
          continue;
        }
        if (!songs.contains(o.songId)) continue; // the song is not here
        final d = o.data;
        await db
            .into(db.personalOverlays)
            .insertOnConflictUpdate(
              PersonalOverlaysCompanion.insert(
                ownerId: Value(userId),
                songId: o.songId,
                transpose: Value((d['transpose'] as num?)?.toInt() ?? 0),
                capoFret: Value((d['capo_fret'] as num?)?.toInt()),
                fontScale: Value((d['font_scale'] as num?)?.toDouble() ?? 1.0),
                notes: Value(d['notes'] as String?),
                chordView: Value(chordViewOf(d['chord_view'], d['nashville'])),
                liveView: Value(d['live_view'] as String?),
                hideAnnotations: Value(d['hide_annotations'] == true),
                verseChords: Value(verseChordsOf(d)),
                stackedChoruses: Value(d['stacked_choruses'] == true),
                midi: Value(o.midi),
                midiPrograms: Value(o.midiPrograms),
                clickGrouping: Value(d['click_grouping'] as String?),
                // Values of newer clients count as the personal setting.
                clickSubdivision: Value(
                  Subdivision.values.asNameMap()[d['click_subdivision']],
                ),
                revision: Value(o.revision),
              ),
            );
      }
      await store.setCursor(
        userId,
        SyncCollection.overlays,
        remote.last.revision,
      );
    });
    return remote.length;
  }

  Future<PushResult> push(OutboxEntry entry, String userId) async {
    final (owner, songId) = parseOverlayRecordId(entry.recordId);
    // Another person's change on a shared device: pushed when they sync.
    if (owner != userId) return PushResult.skipped;
    final row =
        await (db.select(db.personalOverlays).join([
              innerJoin(
                db.songs,
                db.songs.id.equalsExp(db.personalOverlays.songId),
              ),
            ])..where(
              db.personalOverlays.ownerId.equals(owner) &
                  db.personalOverlays.songId.equals(songId),
            ))
            .getSingleOrNull();
    if (row == null || row.readTable(db.songs).libraryId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final overlay = row.readTable(db.personalOverlays);
    final song = row.readTable(db.songs);
    if (song.deleted) {
      await store.done(entry); // the server deletes it with the song
      return PushResult.skipped;
    }
    if (song.revision == 0) return PushResult.skipped; // the song comes first
    final remote = RemoteOverlay(
      id: overlayServerId(owner, songId),
      userId: owner,
      songId: songId,
      data: overlayData(overlay),
      midi: overlay.midi,
      midiPrograms: overlay.midiPrograms,
    );
    try {
      final create = overlay.revision == 0;
      RemoteOverlay stored;
      try {
        stored = await backend.pushOverlay(remote, create: create);
      } on BackendException catch (e) {
        // Created by another device of the same person (same record ID).
        if (!create || e.kind != BackendErrorKind.server) rethrow;
        stored = await backend.pushOverlay(remote, create: false);
      }
      await db.transaction(() async {
        await (db.update(db.personalOverlays)
              ..where((o) => o.ownerId.equals(owner) & o.songId.equals(songId)))
            .write(PersonalOverlaysCompanion(revision: Value(stored.revision)));
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.notAllowed) {
        _log.warning('Overlay ${entry.recordId} not pushed: not allowed');
        await store.done(entry);
        return PushResult.skipped;
      }
      rethrow;
    }
  }
}
