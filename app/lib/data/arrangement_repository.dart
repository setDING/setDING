import 'package:drift/drift.dart';

import 'database.dart';
import 'outbox.dart';

/// Band arrangements (ADR-0025): per band and song the band's key (as a
/// transposition relative to the song), sequence and tempo, between the
/// shared song and the set item. Never changes the song.
class ArrangementRepository {
  ArrangementRepository(this.db, {this.userId});

  final AppDatabase db;

  /// The signed-in user, or null.
  final String? userId;

  /// Last editor of a change of an arrangement of [bandId] (ADR-0045): the
  /// signed-in user, as the server will record it; nobody for the local
  /// band.
  String? _editorIn(String bandId) => bandId == localBandId ? null : userId;

  SimpleSelectStatement<$BandArrangementsTable, BandArrangement> _active(
    String bandId,
  ) =>
      db.select(db.bandArrangements)
        ..where((a) => a.bandId.equals(bandId) & a.deleted.equals(false));

  /// The arrangement of [bandId] for [songId], or null (as in the song).
  Stream<BandArrangement?> watch(String bandId, String songId) => (_active(
    bandId,
  )..where((a) => a.songId.equals(songId))).watchSingleOrNull();

  Future<BandArrangement?> get(String bandId, String songId) => (_active(
    bandId,
  )..where((a) => a.songId.equals(songId))).getSingleOrNull();

  /// The arrangements of [bandId] by song.
  Stream<Map<String, BandArrangement>> watchBand(String bandId) =>
      _active(bandId)
          .watch()
          .map((rows) => {for (final a in rows) a.songId: a});

  Future<Map<String, BandArrangement>> forBand(String bandId) async => {
    for (final a in await _active(bandId).get()) a.songId: a,
  };

  /// Saves the arrangement; without any change against the song it is
  /// removed instead. [sequence] and [tempo] null mean "as in the song".
  Future<void> save(
    String bandId,
    String songId, {
    required int transpose,
    String? sequence,
    int? tempo,
  }) {
    final seq = sequence?.trim();
    final cleanSequence = seq == null || seq.isEmpty ? null : seq;
    final cleanTempo = tempo == null || tempo <= 0 ? null : tempo;
    if (transpose == 0 && cleanSequence == null && cleanTempo == null) {
      return reset(bandId, songId);
    }
    return db.transaction(() async {
      await db
          .into(db.bandArrangements)
          .insert(
            BandArrangementsCompanion.insert(
              bandId: bandId,
              songId: songId,
              transpose: Value(transpose),
              sequence: Value(cleanSequence),
              tempo: Value(cleanTempo),
              updatedBy: Value(_editorIn(bandId)),
            ),
            onConflict: DoUpdate(
              (_) => BandArrangementsCompanion(
                transpose: Value(transpose),
                sequence: Value(cleanSequence),
                tempo: Value(cleanTempo),
                deleted: const Value(false),
                updatedBy: Value(_editorIn(bandId)),
              ),
            ),
          );
      await _dirty(bandId, songId);
    });
  }

  /// Back to the song: the arrangement is removed (soft delete until the
  /// removal reached the server).
  Future<void> reset(String bandId, String songId) => db.transaction(() async {
    final updated =
        await (db.update(db.bandArrangements)
              ..where((a) => a.bandId.equals(bandId) & a.songId.equals(songId)))
            .write(
              BandArrangementsCompanion(
                deleted: const Value(true),
                updatedBy: Value(_editorIn(bandId)),
              ),
            );
    if (updated > 0) await _dirty(bandId, songId);
  });

  Future<void> _dirty(String bandId, String songId) => markDirty(
    db,
    SyncCollection.arrangements,
    arrangementRecordId(bandId, songId),
    scope: bandId,
  );
}
