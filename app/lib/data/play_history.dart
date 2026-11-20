import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart';

import 'database.dart';
import 'outbox.dart';

/// How long after the gig day the values of a set are still frozen
/// (ADR-0046): long enough for the band leader to sync after a weekend of
/// gigs, short enough that a later change of the arrangement is unlikely.
/// Older sets without frozen values are derived from today's arrangement and
/// shown as approximate.
const freezeWindow = Duration(days: 14);

/// The key, tempo and sequence a song item sounds with (ADR-0025, ADR-0046):
/// the song, the band arrangement on top and the set item on top of that.
/// Personal transposition and capo are not part of it.
PlayedValues resolvePlayed({
  required SongEntry song,
  required BandArrangement? arrangement,
  required SetItemEntry item,
}) {
  final base = song.songKey == null ? null : cp.Key.tryParse(song.songKey!);
  return PlayedValues(
    key: base
        ?.transpose((arrangement?.transpose ?? 0) + item.transpose)
        .format(cp.ChordNotation.international),
    tempo: arrangement?.tempo ?? song.tempo,
    sequence: item.sequence ?? arrangement?.sequence ?? song.sequence,
  );
}

/// One play of a song: a set of the band with a gig date before today
/// (ADR-0046).
class SongPlay {
  const SongPlay({
    required this.setId,
    required this.setName,
    required this.date,
    required this.values,
    required this.approximate,
  });

  final String setId;
  final String setName;
  final DateTime date;
  final PlayedValues values;

  /// Derived from today's song and arrangement, because the set has no
  /// frozen values.
  final bool approximate;
}

/// The plays of one song by one band, newest first.
class SongPlays {
  SongPlays(this.plays, {required DateTime today})
    : _yearAgo = DateTime(today.year - 1, today.month, today.day);

  static final empty = SongPlays(const [], today: DateTime(2000));

  final List<SongPlay> plays;
  final DateTime _yearAgo;

  int get total => plays.length;

  /// Plays in the last 12 months.
  int get lastYear => plays.where((p) => !p.date.isBefore(_yearAgo)).length;

  SongPlay? get last => plays.isEmpty ? null : plays.first;
  SongPlay? get first => plays.isEmpty ? null : plays.last;

  /// The key the band played most often, with how often; on a tie the more
  /// recent one. Null when no play has a key.
  ({cp.Key key, int count})? get mostPlayedKey {
    final counts = <cp.Key, int>{};
    for (final p in plays) {
      final key = p.values.parsedKey;
      if (key != null) counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    // Map order is the order of the first play, newest first: a tie keeps
    // the more recent key.
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return (key: best.key, count: best.value);
  }
}

/// The song play history of a band (ADR-0046): a song counts as played when
/// it is in a non-deleted set of the band whose gig date is before today.
/// Computed from the local database, so it works offline.
class PlayHistoryRepository {
  PlayHistoryRepository(this.db);

  final AppDatabase db;

  static DateTime _startOf(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  /// Song items of [bandId] with their set, song and the band's arrangement.
  JoinedSelectStatement<HasResultSet, dynamic> _items(String bandId) {
    final i = db.setItems, l = db.setlists, s = db.songs;
    final a = db.bandArrangements;
    return db.select(i).join([
      innerJoin(l, l.id.equalsExp(i.setId)),
      innerJoin(s, s.id.equalsExp(i.songId)),
      leftOuterJoin(
        a,
        a.bandId.equalsExp(l.bandId) &
            a.songId.equalsExp(i.songId) &
            a.deleted.equals(false),
      ),
    ])..where(
      l.bandId.equals(bandId) &
          l.deleted.equals(false) &
          i.type.equalsValue(SetItemType.song),
    );
  }

  /// The plays of [songId] by [bandId], newest first; a set counts once,
  /// with its first item of the song.
  Stream<SongPlays> watchSongPlays(
    String bandId,
    String songId, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final i = db.setItems, l = db.setlists;
    final q = _items(bandId)
      ..where(
        i.songId.equals(songId) & l.gigDate.isSmallerThanValue(_startOf(now)),
      )
      ..orderBy([
        OrderingTerm.desc(l.gigDate),
        OrderingTerm.asc(l.name),
        OrderingTerm.asc(i.position),
      ]);
    return q.watch().map((rows) {
      final plays = <SongPlay>[];
      final seen = <String>{};
      for (final row in rows) {
        final set = row.readTable(l);
        if (!seen.add(set.id)) continue;
        final item = row.readTable(i);
        final frozen = item.played;
        plays.add(
          SongPlay(
            setId: set.id,
            setName: set.name,
            date: set.gigDate!,
            values:
                frozen ??
                resolvePlayed(
                  song: row.readTable(db.songs),
                  arrangement: row.readTableOrNull(db.bandArrangements),
                  item: item,
                ),
            approximate: frozen == null,
          ),
        );
      }
      return SongPlays(plays, today: now);
    });
  }

  /// For each song [bandId] has played: the date of the last play.
  Stream<Map<String, DateTime>> watchLastPlayed(
    String bandId, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final i = db.setItems, l = db.setlists;
    final last = l.gigDate.max();
    final q = db.selectOnly(i).join([innerJoin(l, l.id.equalsExp(i.setId))])
      ..addColumns([i.songId, last])
      ..where(
        l.bandId.equals(bandId) &
            l.deleted.equals(false) &
            i.type.equalsValue(SetItemType.song) &
            i.songId.isNotNull() &
            l.gigDate.isSmallerThanValue(_startOf(now)),
      )
      ..groupBy([i.songId]);
    return q.watch().map(
      (rows) => {for (final r in rows) r.read(i.songId)!: ?r.read(last)},
    );
  }

  /// Freezes the values of the songs in the sets of [bandId] whose gig day
  /// has come, within [freezeWindow] (ADR-0046). Runs on the devices of
  /// people who may edit the band's sets, after the sync pulled the band's
  /// sets and arrangements; the changed sets are pushed like any change.
  /// Returns the number of changed sets.
  Future<int> freeze(String bandId, {DateTime? today}) =>
      db.transaction(() async {
        final start = _startOf(today ?? DateTime.now());
        final i = db.setItems, l = db.setlists;
        final rows =
            await (_items(bandId)..where(
                  i.played.isNull() &
                      l.gigDate.isSmallerThanValue(
                        start.add(const Duration(days: 1)),
                      ) &
                      l.gigDate.isBiggerOrEqualValue(
                        start.subtract(freezeWindow),
                      ),
                ))
                .get();
        final sets = <String>{};
        for (final row in rows) {
          final item = row.readTable(i);
          await _write(
            item.id,
            resolvePlayed(
              song: row.readTable(db.songs),
              arrangement: row.readTableOrNull(db.bandArrangements),
              item: item,
            ),
          );
          sets.add(item.setId);
        }
        for (final setId in sets) {
          await (db.update(l)..where((s) => s.id.equals(setId))).write(
            SetlistsCompanion(updatedAt: Value(DateTime.now())),
          );
          await markDirty(db, SyncCollection.setlists, setId, scope: bandId);
        }
        return sets.length;
      });

  /// Writes the values of the song items [itemIds] again whose set's gig
  /// day has come, after someone changed them by hand (ADR-0046): fixing the
  /// key of a past set afterwards fixes its history. Items of upcoming or
  /// undated sets are left alone. Runs in the caller's transaction; the
  /// caller records the change for the sync.
  Future<void> refreshItems(Iterable<String> itemIds, {DateTime? today}) async {
    final ids = itemIds.toList();
    if (ids.isEmpty) return;
    final start = _startOf(today ?? DateTime.now());
    final i = db.setItems, l = db.setlists;
    final s = db.songs, a = db.bandArrangements;
    final rows =
        await (db.select(i).join([
              innerJoin(l, l.id.equalsExp(i.setId)),
              innerJoin(s, s.id.equalsExp(i.songId)),
              leftOuterJoin(
                a,
                a.bandId.equalsExp(l.bandId) &
                    a.songId.equalsExp(i.songId) &
                    a.deleted.equals(false),
              ),
            ])..where(
              i.id.isIn(ids) &
                  i.type.equalsValue(SetItemType.song) &
                  l.gigDate.isSmallerThanValue(
                    start.add(const Duration(days: 1)),
                  ),
            ))
            .get();
    for (final row in rows) {
      final item = row.readTable(i);
      await _write(
        item.id,
        resolvePlayed(
          song: row.readTable(s),
          arrangement: row.readTableOrNull(a),
          item: item,
        ),
      );
    }
  }

  Future<void> _write(String itemId, PlayedValues values) =>
      (db.update(db.setItems)..where((i) => i.id.equals(itemId))).write(
        SetItemsCompanion(played: Value(values)),
      );
}
